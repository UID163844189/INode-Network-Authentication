#!/bin/sh

CONFIG_FILE="${1:-/etc/config.ini}"
CHECK_SCRIPT="${2:-/etc/zzz/check_network.sh}"
LOG_TAG="zzz-watchdog"
SERVICE_NAME="zzz"

log_msg() {
	logger -t "$LOG_TAG" "$1"
}

get_cfg() {
	local key="$1"
	grep -E "^${key}[[:space:]]*=" "$CONFIG_FILE" 2>/dev/null | head -1 | sed "s/^${key}[[:space:]]*=[[:space:]]*//" | tr -d '\r'
}

main() {
	if [ ! -x "$CHECK_SCRIPT" ]; then
		log_msg "ERROR: check script not executable: $CHECK_SCRIPT"
		exit 1
	fi

	local interval max_retries retry_delay enabled
	interval="$(get_cfg 'interval')"
	max_retries="$(get_cfg 'max_retries')"
	retry_delay="$(get_cfg 'retry_delay')"
	enabled="$(get_cfg 'enabled')"

	[ -z "$interval" ] && interval=30
	[ -z "$max_retries" ] && max_retries=-1
	[ -z "$retry_delay" ] && retry_delay=10
	[ -z "$enabled" ] && enabled=0

	if [ "$enabled" != "1" ]; then
		log_msg "Watchdog disabled in config, exiting"
		exit 0
	fi

	local fail_count=0
	local retry_count=0

	log_msg "Watchdog started (interval=${interval}s, max_retries=${max_retries}, retry_delay=${retry_delay}s)"

	while true; do
		if "$CHECK_SCRIPT" >/dev/null 2>&1; then
			[ "$fail_count" -gt 0 ] && log_msg "Network recovered"
			fail_count=0
			retry_count=0
			sleep "$interval"
			continue
		fi

		fail_count=$((fail_count + 1))
		log_msg "Connectivity check failed (consecutive=${fail_count})"

		if [ "$fail_count" -lt 2 ]; then
			sleep "$interval"
			continue
		fi

		if [ "$max_retries" -ge 0 ] && [ "$retry_count" -ge "$max_retries" ]; then
			log_msg "Max retries reached (${max_retries}), skip restart and keep monitoring"
			sleep "$interval"
			continue
		fi

		log_msg "Restarting service ${SERVICE_NAME} (retry $((retry_count + 1)))"
		/etc/init.d/${SERVICE_NAME} restart >/dev/null 2>&1
		retry_count=$((retry_count + 1))
		fail_count=0
		sleep "$retry_delay"
	done
}

main "$@"

-- Copyright (C) 2026 zzz 802.1X Client LuCI Controller
-- Licensed under Apache 2.0

module("luci.controller.zzz", package.seeall)

function index()
	-- Only register the configuration page
	entry({"admin", "services", "zzz"}, cbi("zzz/config"), _("802.1X 客户端"), 60).dependent = true
end

-- Get current service status as JSON
-- (Removed status functions to simplify UI)

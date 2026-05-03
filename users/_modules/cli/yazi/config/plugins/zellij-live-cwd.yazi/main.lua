local M = {}

function M:setup()
	local live_cwd_helper = os.getenv("YAZI_ZELLIJ_LIVE_CWD")
	local origin_fish_pid = os.getenv("YAZI_ZELLIJ_ORIGIN_FISH_PID")

	if not live_cwd_helper or live_cwd_helper == "" or not origin_fish_pid or origin_fish_pid == "" then
		return
	end

	ps.sub("cd", function()
		local cwd = tostring(cx.active.current.cwd)

		ya.async(function()
			local _, err = Command(live_cwd_helper):arg({ origin_fish_pid, cwd }):status()

			if err then
				ya.err("yazi-zellij-live-cwd failed: " .. tostring(err))
			end
		end)
	end)
end

return M

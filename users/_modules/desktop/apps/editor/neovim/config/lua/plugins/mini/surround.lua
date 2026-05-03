-- [nfnl] fnl/plugins/mini/surround.fnl
return {
	"nvim-mini/mini.surround",
	version = "*",
	event = "BufEnter",
	opts = {
		highlight_duration = 1000,
		mappings = { add = "ra", delete = "rd", find = "rf", find_left = "rF", highlight = "rh", replace = "rr" },
	},
}

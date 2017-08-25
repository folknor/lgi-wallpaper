local sh = require("sh")
-- We depend on wmctrl because Gdk crashes lgi too much.
local wmctrl = sh.command("wmctrl")
local desktop = tostring(wmctrl("-m")):match("Name: (%S+)")

local impl = require("desktops." .. desktop)

return {
	set = impl
}


-- Stuff below just randomly crashes lgi in at least 2 different ways, depending on when you execute it.
-- It also might randomly not crash.
	-- local rootWindow = gdk.get_default_root_window()
	-- local rootDisplay = rootWindow:get_display()

	-- local prop = gdk.property_get(
	-- 	rootWindow,
	-- 	gdk.Atom.intern("NAUTILUS_DESKTOP_WINDOW_ID", false),
	-- 	gdk.Atom.intern("WINDOW", false),
	-- 	0,
	-- 	4,
	-- 	0 -- false
	-- )

	-- local screen = window:get_screen()
	-- local display = screen:get_display()
	-- local monitor = display:get_monitor_at_window(window)



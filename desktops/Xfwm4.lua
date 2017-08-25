#!/usr/bin/lua

local sh = require("sh")
local xfc = sh.command("xfconf-query")
local convert = sh.command("convert")
    -- XFCE_BACKDROP_IMAGE_NONE = 0,
    -- XFCE_BACKDROP_IMAGE_CENTERED = 1,
    -- XFCE_BACKDROP_IMAGE_TILED = 2,
    -- XFCE_BACKDROP_IMAGE_STRETCHED = 3,
    -- XFCE_BACKDROP_IMAGE_SCALED = 4,
    -- XFCE_BACKDROP_IMAGE_ZOOMED = 5,
    -- XFCE_BACKDROP_IMAGE_SPANNING_SCREENS = 6,
-- xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-1/workspace0/image-style -s 2

local _paths = {}
-- Get all the properties we need to set
local propOutput = tostring(xfc("-l", "-c xfce4-desktop"))
for prop in propOutput:gmatch("%S+") do
	local path = prop:match("^(/backdrop/screen%d+/monitor.-/workspace%d+/)")
	if path and not _paths[path] then _paths[path] = true end
end

local _setUri = {}
local _setStyle = {}
local _setRGBA = {}
for path in pairs(_paths) do
	_setUri[#_setUri + 1] = path .. "last-image"
	_setStyle[#_setStyle + 1] = path .. "image-style"
	_setRGBA[#_setRGBA + 1] = path .. "rgba1"
end

--xfconf-query -l -c xfce4-desktop
--xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-1/workspace0/last-image -s '/home/folk/Pictures/alx83eg.jpg'
-- xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-1/workspace0/rgba1 -s 0.49803921568627 -s 0 -s 1 -s 1
local function setAll(tbl, val)
	for i = 1, #tbl do
		xfc("-c", "xfce4-desktop", "-p", tbl[i], "-s", val)
	end
end

-- xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitorHDMI-1/workspace0/rgba1 -s 1 -t double -s 1 -t double -s 1 -t double -s 1 -t double --create
local function setColor(r, g, b)
	for i = 1, #_setRGBA do
		xfc("-c", "xfce4-desktop", "-p", _setRGBA[i],
			"-s", r,   "-t", "double",
			"-s", g,   "-t", "double",
			"-s", b,   "-t", "double",
			"-s", "1", "-t", "double",
			"--create")
	end
end

local function getDominantColor(uri)
	local ret = tostring(convert(uri, "-scale 1x1\\! -format '%[pixel:u]' info:-"))
	local r, g, b = ret:match("srgb%((%d+),(%d+),(%d+)%)")
	r, g, b = tonumber(r), tonumber(g), tonumber(b)
	if not r or not g or not b then return "0", "0", "0" end
	return tostring(r/255), tostring(g/255), tostring(b/255)
end

local function set(uri, imageType, width, height)
	if height > width then
		local r, g, b = getDominantColor(uri)
		setColor(r, g, b)
		setAll(_setStyle, 4)
	else
		setAll(_setStyle, 3)
	end
	-- go from file:///home/blah to /home/blah
	local xfceUri = uri:match("//(.*)")
	setAll(_setUri, xfceUri)
end

return set

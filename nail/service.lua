#!/usr/bin/lua
-- API VERSION: 1

local lgi = require("lgi")
local GDesktop = lgi.GnomeDesktop
local factory = GDesktop.DesktopThumbnailFactory.new(GDesktop.DesktopThumbnailSize.LARGE)
local uv = require("luv")
local sh = require("sh")
local logger = sh.command("logger -t")
local repeater = uv.new_timer()
local _CAT = "libnailservice"

local _running = false
local _outputFormat = "uuid:%s:thumb:%s"
local _queued = "'Queued: %q (%s) (%d) - %s'"
local _returning = "'Result: %q'"
local _m = "%$(%S+)%$(%S+)%$(%S+)%$(%S+)%$"

local _queue = {}

local _stdin = uv.new_tty(0, true)
local _stdout = uv.new_tty(1, false)

logger(_CAT, "'Running'")

local function run(uuid, uri, mime, modified)
	_running = true
	local pix = factory:generate_thumbnail(uri, mime)
	local out
	if pix then
		-- Save result
		factory:save_thumbnail(pix, uri, modified)
		local thumb = factory:lookup(uri, modified)
		out = _outputFormat:format(uuid, thumb)
	else
		-- Failed
		factory:create_failed_thumbnail(uri, modified)
		out = _outputFormat:format(uuid, "FAIL")
	end
	logger(_CAT, _returning:format(out))
	uv.write(_stdout, out .. "\n")
	_running = false
end

uv.timer_start(repeater, 5, 500, function()
	if _running then return end
	local pop = table.remove(_queue)
	if not pop then return end
	run(unpack(pop))
end)

local function parseAndQueue(data)
	local uuid, uri, mime, modified = data:match(_m)
	modified = tonumber(modified)
	if type(uuid) ~= "string" or #uuid ~= 36 then return end
	if type(uri) ~= "string" or uri:sub(1, 8) ~= "file:///" then return end
	if type(mime) ~= "string" or not mime:find("/") then return end
	if type(modified) ~= "number" then return end

	logger(_CAT, _queued:format(uri, mime, modified, uuid))
	table.insert(_queue, {uuid, uri, mime, modified})
end

_stdin:read_start(function(err, data)
	if err then
		logger(_CAT, "'Thumbnailing indata error: " .. tostring(err) .. "'")
		return
	end
	if data then
		if data:find("%s") then
			for d in data:gmatch("%S+") do
				parseAndQueue(d)
			end
		else
			parseAndQueue(data)
		end
	else
		_stdin:close()
		_stdout:close()
		os.exit()
	end
end)

uv.run()

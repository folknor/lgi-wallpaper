local lgi = require("lgi")
local glib = lgi.GLib
local gio = lgi.Gio
local gdesk = lgi.GnomeDesktop
local factory = gdesk.DesktopThumbnailFactory.new(gdesk.DesktopThumbnailSize.LARGE)

local _luaexec
local _cwd
local _cache = {}
local _callbacks = {}
local _queue = {}
local _incomingFormat = "uuid:(%S+):thumb:(%S+)"
local _outFormat = "$%s$%s$%s$%s$\n"

local _incoming, _outgoing, _bytesIn, _bytesOut, _pid

local parse
parse = function(obj, res)
	local result = obj:read_line_finish_utf8(res)
	if result and not _incoming:is_closed() then
		local uuid, uri = result:match(_incomingFormat)
		if uuid and uri then
			for cb in pairs(_callbacks) do cb(uuid, uri) end
		end
		_incoming:read_line_async(glib.PRIORITY_DEFAULT, nil, parse)
	else
		_incoming:close()
		_bytesIn:close()
		_outgoing:close()
		_bytesOut:close()
		_pid = nil
	end
end

local function spawn()
	local stdin, stdout
	_pid, stdin, stdout = glib.spawn_async_with_pipes(
		_cwd,
		{_luaexec, "service.lua"},
		nil, -- env
		0 -- search path, cant be nil, lgi errors
	)
	if not _pid then
		print("Failed to start thumbnail factory.")
		return
	end
	_bytesIn = gio.UnixInputStream.new(stdout)
	_incoming = gio.DataInputStream.new(_bytesIn)

	_bytesOut = gio.UnixOutputStream.new(stdin)
	_outgoing = gio.DataOutputStream.new(_bytesOut)

	_incoming:read_line_async(glib.PRIORITY_DEFAULT, nil, parse)
end

local function get(uri, mime, modified)
	if _cache[uri] then return _cache[uri] end

	local exists = factory:lookup(uri, modified)
	if exists then
		_cache[uri] = exists
		return exists
	end

	local failed = factory:has_valid_failed_thumbnail(uri, modified)
	if failed then return nil, "FAIL" end

	local can = factory:can_thumbnail(uri, mime, modified)
	if not can then return nil, "FAIL" end

	if _queue[uri] then return nil, _queue[uri].uuid end

	local uuid = glib.uuid_string_random()
	_queue[uri] = {
		uuid = uuid,
		modified = modified,
		mime = mime,
	}
	if not _pid then spawn() end
	if not _pid then return nil, "FAIL" end

	_outgoing:put_string(_outFormat:format(uuid, uri, mime, modified))

	return nil, uuid
end

local function register(cb) _callbacks[cb] = true end

return function(cwd)
	local sh = require("sh")
	local luav = tostring(sh.command("lua")("-v"))
	local v = luav:match("Lua %d.(%d+)")
	if tonumber(v) < 2 then return end

	local w = sh.command("which")
	_luaexec = tostring(w("lua"))

	_cwd = cwd .. "/nail/"

	local cat = sh.command("cat")
	local service = tostring(cat(_cwd .. "service.lua"))
	local sVersion = service:match("API VERSION: (%d+)")
	if tonumber(sVersion) ~= 1 then return end

	return {get=get,register=register,ok=true}
end

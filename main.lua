#!/usr/bin/lua

local sh = require("sh")
local identify = sh.command("identify -format '%m:%wx%h'")
local lgi = require("lgi")
local gtk = lgi.Gtk
local gio = lgi.Gio
local glib = lgi.GLib
local assert = lgi.assert
local _CWD = gio.File.new_for_commandline_arg(arg[0]):get_parent()

local nailSetup = require("nail.init")
local nail = nailSetup(_CWD:get_path())
if not nail.ok then
	print("Nail setup failed.")
	return
end

local builder = gtk.Builder()
builder:add_from_file(_CWD:get_child("wally.glade"):get_path())
local _ui = builder.objects

local grid = {
	{
		image = gtk.Image.new(),
		stack = _ui.stack1,
		button = _ui.button1,
		spinner = _ui.spinner1,
	},
	{
		image = gtk.Image.new(),
		stack = _ui.stack2,
		button = _ui.button2,
		spinner = _ui.spinner2,
	},
	{
		image = gtk.Image.new(),
		stack = _ui.stack3,
		button = _ui.button3,
		spinner = _ui.spinner3,
	},
	{
		image = gtk.Image.new(),
		stack = _ui.stack4,
		button = _ui.button4,
		spinner = _ui.spinner4,
	},
	{
		image = gtk.Image.new(),
		stack = _ui.stack5,
		button = _ui.button5,
		spinner = _ui.spinner5,
	},
	{
		image = gtk.Image.new(),
		stack = _ui.stack6,
		button = _ui.button6,
		spinner = _ui.spinner6,
	},
}
for i = 1, #grid do
	grid[i].button:set_image(grid[i].image)
	grid[i].button:set_relief(gtk.ReliefStyle.NONE)
	grid[i].button.name = i
end

local ATTRIBUTES = "standard::name,standard::content-type,access::can-read,standard::type,time::modified"
local SUPPORTED_MIME = {
	["image/jpeg"] = true,
	["image/png"] = true,
}

local _set
local _currentSet
local _waiting = {}

local function thumbnailDone(uuid, file)
	local waiting = _waiting[uuid]
	if not waiting then return end
	if _currentSet ~= waiting.set then return end
	if file ~= "FAIL" then
		local g = grid[waiting.index]
		g.spinner:stop()

		g.image:set_from_file(file)
		g.original = waiting.original

		g.stack:set_visible_child(g.button)
	end
	_waiting[uuid] = nil
end
nail.register(thumbnailDone)

local wally
local function buttonClicked(button)
	if not wally then wally = require("setwallpaper") end
	local uri = grid[(tonumber(button.name))].original
	local id = tostring(identify(uri))
	if not id or #id == 0 then return end
	local imageType, width, height = id:match("(%w+):(%d+)x(%d+)")
	width = tonumber(width)
	height = tonumber(height)
	if not imageType or not width or not height then return end
	wally.set(uri, imageType, width, height)
end

local function updateView()
	local set = _set[_currentSet]
	for i = 1, #grid do
		local s = set and set[i]
		local g = grid[i]
		if s then
			local img, uuid = nail.get(s.uri, s.mime, s.modified)
			if img then
				g.spinner:stop()
				g.image:set_from_file(img)
				g.original = s.uri
				g.stack:set_visible_child(g.button)
			elseif uuid then
				if uuid ~= "FAIL" then
					_waiting[uuid] = {
						set = _currentSet,
						index = i,
						original = s.uri
					}
					g.spinner:start()
				else
					g.spinner:stop()
				end
				g.stack:set_visible_child(g.spinner)
			end
		else
			g.spinner:stop()
			g.stack:set_visible_child(g.spinner)
		end
	end
end

local function doSelectFolder(folder)
	local enum = gio.File.new_for_path(folder):enumerate_children(ATTRIBUTES, "NONE")
	-- Dump previous data
	_set = {}

	local set, index = 1, 1
	while true do
		local info, err = enum:next_file()
		if not info then assert(not err, err) break end
		local mime = info:get_content_type()
		if info:get_file_type() == "REGULAR" and SUPPORTED_MIME[mime] then
			local uri = enum:get_child(info):get_uri()
			local mtime = info:get_modification_time()
			-- XXX set up metatables instead
			if index == (#grid + 1) then
				set = set + 1
				index = 1
			end
			if index == 1 then _set[set] = {} end
			_set[set][index] = {
				uri = uri,
				mime = mime,
				modified = mtime.tv_sec,
			}
			index = index + 1
		end
	end

	_currentSet = 1
	if #_set ~= 0 then updateView() end
	enum:close()
end

local function doPrevious()
	_currentSet = _currentSet - 1
	if not _set[_currentSet] then _currentSet = #_set end
	updateView()
end
local function doNext()
	_currentSet = _currentSet + 1
	if not _set[_currentSet] then _currentSet = 1 end
	updateView()
end

local app = gtk.Application.new("org.folk.wallpaper", gio.ApplicationFlags.FLAGS_NONE)

local handle = {
	on_folder_file_set = function(dialog) doSelectFolder(dialog:get_filename()) end,
	on_next_clicked = doNext,
	on_previous_clicked = doPrevious,
	on_image_clicked = buttonClicked,
}
builder:connect_signals(handle)

local window = _ui.window

local function tryFolder(folder)
	_ui.folder:set_current_folder(folder)
	doSelectFolder(folder)
	return #_set ~= 0
end

function app:on_activate()
	local pics = glib.get_user_special_dir(glib.UserDirectory.DIRECTORY_PICTURES)
	if not tryFolder(pics) then
		pics = glib.get_user_special_dir(glib.UserDirectory.DIRECTORY_DOWNLOAD)
		tryFolder(pics)
	end

	window.application = self
	window:show_all()
end

app:run({arg[0], ...})

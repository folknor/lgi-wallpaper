# lgi-wallpaper
Small, simple app built with Lua and GTK to set the desktop wallpaper.
Depends on several weird things:
 * [LGI](https://github.com/pavouk/lgi)
 * [luash](https://github.com/folknor/luash) (or the original)
 * [luv](https://github.com/luvit/luv) (libunique bindings for lua)
 * GTK3, Gio, GLib, and obviously gobject-introspection
 * [libgnome-desktop](https://git.gnome.org/browse/gnome-desktop/)
 * ImageMagicks `identify` and `convert` commands
 * [wmctrl](http://tripie.sweb.cz/utils/wmctrl/) (because Gdk over LGI crashes too much)

It uses libgnome-desktop and its thumbnailer service behind the scenes, and so far only shows JPEG and PNG images.

## Screenshot
![screenshot](https://github.com/folknor/lgi-wallpaper/raw/master/screenshot.jpg "Obligatory screenshot")

## XFCE4
So far, the app only works for XFCE4, using `xfconf-query` via luash.

## Awesomewm
Eventually, this will support awesomewm.

## Gnome Shell
Eventually, this will support gnome-shell, because it's just very easy to add. Not because anyone will ever use it.

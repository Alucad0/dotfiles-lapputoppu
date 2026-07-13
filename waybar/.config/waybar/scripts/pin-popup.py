#!/usr/bin/env python3
"""Pinned tooltip popups for waybar (toggle on each invocation).

Usage: pin-popup.py {calendar|memory}

Clicking the module runs this with its name: first click pins a popup with
the module's tooltip info under the bar (it stays put and live-updates),
clicking the module again — or the popup itself — dismisses it.
Same gtk-layer-shell overlay pattern as cpu-cores-dropdown.py.
"""

import datetime
import os
import signal
import subprocess
import sys

MODULES = ("calendar", "memory")
module = sys.argv[1] if len(sys.argv) > 1 else ""
if module not in MODULES:
    sys.exit(f"usage: pin-popup.py {{{'|'.join(MODULES)}}}")

PIDFILE = os.path.expanduser(f"~/.cache/waybar-pin-{module}.pid")

# --- toggle: if an instance is already running, kill it and exit ---
if os.path.exists(PIDFILE):
    try:
        with open(PIDFILE) as f:
            pid = int(f.read().strip())
        os.kill(pid, 0)  # raises if the process is gone
        os.kill(pid, signal.SIGTERM)
        os.remove(PIDFILE)
        sys.exit(0)
    except (ValueError, ProcessLookupError, PermissionError):
        os.remove(PIDFILE)  # stale pidfile — fall through and start fresh

os.makedirs(os.path.dirname(PIDFILE), exist_ok=True)
with open(PIDFILE, "w") as f:
    f.write(str(os.getpid()))

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell  # noqa: E402

# Bar sits with margin-top:6 and ~26px of content; anchor just below it
MARGIN_TOP = 40
MARGIN_RIGHT = 8

# Accents matching the waybar calendar config / Catppuccin Mocha
C_TITLE = "#ffead3"
C_HEAD = "#ffcc66"
C_BODY = "#ecc6d9"
C_WEEK = "#99ffdd"
C_TODAY = "#ff6699"
C_DIM = "#6c7086"
C_TEXT = "#cdd6f4"

REFRESH_S = {"calendar": 3600, "memory": 2}


def esc(s):
    return GLib.markup_escape_text(str(s))


def calendar_markup():
    import calendar as calmod

    today = datetime.date.today()
    cal = calmod.Calendar(firstweekday=0)  # Monday first, matches ISO weeks
    lines = [
        f"<span color='{C_TITLE}'><b>{today.strftime('%B %Y').center(20)}</b></span>",
        f"<span color='{C_HEAD}'><b>Mo Tu We Th Fr Sa Su</b></span>",
    ]
    for week in cal.monthdatescalendar(today.year, today.month):
        cells = []
        for d in week:
            s = f"{d.day:2d}" if d.month == today.month else "  "
            if d == today:
                s = f"<span color='{C_TODAY}'><b><u>{s}</u></b></span>"
            cells.append(s)
        wk = week[0].isocalendar()[1]
        lines.append(
            f"<span color='{C_BODY}'>{' '.join(cells)}</span>"
            f"  <span color='{C_WEEK}'><b>{wk:2d}</b></span>"
        )
    return "\n".join(lines)


def memory_markup():
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            k, v = line.split(":", 1)
            info[k] = int(v.split()[0])  # kB
    gib = 1024 * 1024
    used = (info["MemTotal"] - info["MemAvailable"]) / gib
    total = info["MemTotal"] / gib
    sused = (info["SwapTotal"] - info["SwapFree"]) / gib
    stotal = info["SwapTotal"] / gib
    lines = [
        f"<span color='{C_TITLE}'><b>Memory</b></span>",
        f"<span color='{C_TEXT}'>{used:0.1f} / {total:0.1f} GiB used</span>",
        f"<span color='{C_TEXT}'>Swap: {sused:0.1f} / {stotal:0.1f} GiB</span>",
        "",
        f"<span color='{C_HEAD}'><b>Top processes</b></span>",
    ]
    try:
        ps = subprocess.run(
            ["ps", "-eo", "rss=,comm=", "--sort=-rss"],
            capture_output=True, text=True, timeout=3,
        ).stdout.splitlines()[:5]
    except (OSError, subprocess.TimeoutExpired):
        ps = []
    for row in ps:
        parts = row.split(None, 1)
        if len(parts) == 2:
            mib = int(parts[0]) / 1024
            lines.append(
                f"<span color='{C_BODY}'>{mib:7.0f} MiB  {esc(parts[1][:24])}</span>"
            )
    return "\n".join(lines)


CONTENT = {
    "calendar": calendar_markup,
    "memory": memory_markup,
}


class PinPopup(Gtk.Window):
    def __init__(self):
        super().__init__()
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, MARGIN_TOP)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, MARGIN_RIGHT)

        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        css = Gtk.CssProvider()
        css.load_from_data(b"""
            window { background: rgba(30, 30, 46, 0.92);
                     border-radius: 14px; border: 1px solid #45475a; }
            label  { padding: 12px 16px; color: #cdd6f4;
                     font-family: "MesloLGS Nerd Font Mono";
                     font-size: 10pt; font-weight: bold; }
        """)
        Gtk.StyleContext.add_provider_for_screen(
            screen, css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.label = Gtk.Label()
        self.add(self.label)
        self.refresh()

        self.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        self.connect("button-press-event", lambda *_: Gtk.main_quit())
        self.connect("destroy", Gtk.main_quit)

        GLib.timeout_add_seconds(REFRESH_S[module], self.refresh)
        self.show_all()

    def refresh(self):
        try:
            self.label.set_markup(CONTENT[module]())
        except Exception as e:  # never let a parse hiccup kill the popup
            self.label.set_markup(f"<span color='{C_DIM}'>{esc(e)}</span>")
        return True


def cleanup(*_):
    try:
        os.remove(PIDFILE)
    except FileNotFoundError:
        pass
    Gtk.main_quit()


signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

PinPopup()
try:
    Gtk.main()
finally:
    try:
        os.remove(PIDFILE)
    except FileNotFoundError:
        pass

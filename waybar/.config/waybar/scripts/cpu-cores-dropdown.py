#!/usr/bin/env python3
"""Per-core CPU bar chart dropdown for waybar (toggle on each invocation).

Uses gtk-layer-shell on the overlay layer so it floats above all windows,
anchored under the right end of the bar. Click the window to dismiss it.
"""

import os
import signal
import sys

PIDFILE = os.path.expanduser("~/.cache/waybar-cpu-cores.pid")

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
from gi.repository import Gtk, GLib, GtkLayerShell  # noqa: E402

# Colours come from the active theme's palette — the same generated css waybar
# imports (~/.local/bin/theme writes it), so the dropdown shares the bar's
# undertone. Catppuccin Mocha is the fallback if the file is missing.
PALETTE = {
    "base": "1e1e2e", "surface1": "45475a", "surface0": "313244",
    "text": "cdd6f4", "overlay0": "6c7086",
    "green": "a6e3a1", "peach": "fab387", "red": "f38ba8",
}
try:
    with open(os.path.expanduser("~/.config/waybar/theme.css")) as f:
        for line in f:  # "@define-color name #rrggbb;" — later lines win
            parts = line.split()
            if len(parts) == 3 and parts[0] == "@define-color" and parts[2].startswith("#"):
                PALETTE[parts[1]] = parts[2][1:7]
except OSError:
    pass


def _rgb(name):
    h = PALETTE[name]
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


BASE, SURFACE1, SURFACE0 = _rgb("base"), _rgb("surface1"), _rgb("surface0")
TEXT, OVERLAY0 = _rgb("text"), _rgb("overlay0")
GREEN, PEACH, RED = _rgb("green"), _rgb("peach"), _rgb("red")

BAR_W = 16
BAR_GAP = 7
PAD = 16
CHART_H = 96
LABEL_H = 16
UPDATE_MS = 700

# Bar sits with margin-top:6 and ~26px of content; anchor just below it
MARGIN_TOP = 40
MARGIN_RIGHT = 8


def read_core_ticks():
    """Return {core_index: (busy, total)} from /proc/stat."""
    ticks = {}
    with open("/proc/stat") as f:
        for line in f:
            if line.startswith("cpu") and line[3].isdigit():
                parts = line.split()
                idx = int(parts[0][3:])
                vals = [int(v) for v in parts[1:]]
                idle = vals[3] + vals[4]  # idle + iowait
                total = sum(vals)
                ticks[idx] = (total - idle, total)
    return ticks


class CoreChart(Gtk.Window):
    def __init__(self):
        super().__init__()
        self.prev = read_core_ticks()
        self.usage = [0.0] * len(self.prev)
        n = len(self.prev)
        width = PAD * 2 + n * BAR_W + (n - 1) * BAR_GAP
        height = PAD * 2 + CHART_H + LABEL_H
        self.set_default_size(width, height)

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, MARGIN_TOP)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT, MARGIN_RIGHT)

        self.set_app_paintable(True)
        screen = self.get_screen()
        visual = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)

        self.area = Gtk.DrawingArea()
        self.area.connect("draw", self.on_draw)
        self.add(self.area)

        self.add_events(256)  # BUTTON_PRESS_MASK
        self.connect("button-press-event", lambda *_: Gtk.main_quit())
        self.connect("destroy", Gtk.main_quit)

        GLib.timeout_add(UPDATE_MS, self.tick)
        self.show_all()

    def tick(self):
        cur = read_core_ticks()
        for i in cur:
            pb, pt = self.prev.get(i, (0, 0))
            cb, ct = cur[i]
            dt = ct - pt
            self.usage[i] = (cb - pb) / dt if dt > 0 else 0.0
        self.prev = cur
        self.area.queue_draw()
        return True

    @staticmethod
    def load_color(u):
        """green -> peach -> red as load rises."""
        if u < 0.5:
            t = u / 0.5
            a, b = GREEN, PEACH
        else:
            t = (u - 0.5) / 0.5
            a, b = PEACH, RED
        return tuple(a[j] + (b[j] - a[j]) * t for j in range(3))

    def on_draw(self, _widget, cr):
        w = self.get_allocated_width()
        h = self.get_allocated_height()

        # frosted rounded-rect background matching the bar islands
        r = 14
        cr.set_operator(0)  # CLEAR
        cr.paint()
        cr.set_operator(2)  # OVER
        cr.new_path()
        cr.arc(w - r, r, r, -1.5708, 0)
        cr.arc(w - r, h - r, r, 0, 1.5708)
        cr.arc(r, h - r, r, 1.5708, 3.1416)
        cr.arc(r, r, r, 3.1416, 4.7124)
        cr.close_path()
        cr.set_source_rgba(*BASE, 0.92)
        cr.fill_preserve()
        cr.set_source_rgba(*SURFACE1, 1)
        cr.set_line_width(1)
        cr.stroke()

        top = PAD
        for i, u in enumerate(self.usage):
            x = PAD + i * (BAR_W + BAR_GAP)

            # track
            cr.rectangle(x, top, BAR_W, CHART_H)
            cr.set_source_rgba(*SURFACE0, 0.8)
            cr.fill()

            # fill
            bh = max(2, CHART_H * u)
            cr.rectangle(x, top + CHART_H - bh, BAR_W, bh)
            cr.set_source_rgba(*self.load_color(u), 1)
            cr.fill()

            # core label
            cr.set_source_rgba(*OVERLAY0, 1)
            cr.select_font_face("MesloLGS Nerd Font Mono")
            cr.set_font_size(9)
            label = str(i)
            ext = cr.text_extents(label)
            cr.move_to(x + BAR_W / 2 - ext.width / 2, top + CHART_H + 12)
            cr.show_text(label)

            # percentage on top of loaded cores
            if u >= 0.30:
                pct = f"{round(u * 100)}"
                cr.set_source_rgba(*TEXT, 0.9)
                ext = cr.text_extents(pct)
                ty = top + CHART_H - bh + 11
                if ty > top + CHART_H - 3:
                    ty = top + CHART_H - 4
                cr.move_to(x + BAR_W / 2 - ext.width / 2, ty)
                cr.show_text(pct)
        return True


def cleanup(*_):
    try:
        os.remove(PIDFILE)
    except FileNotFoundError:
        pass
    Gtk.main_quit()


signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

CoreChart()
try:
    Gtk.main()
finally:
    try:
        os.remove(PIDFILE)
    except FileNotFoundError:
        pass

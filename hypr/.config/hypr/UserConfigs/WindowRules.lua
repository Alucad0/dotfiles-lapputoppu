-- NOTE: This file is currently NOT loaded (the old WindowRules.conf was
-- likewise never sourced from hyprland.conf). To activate it, add
--     require("UserConfigs.WindowRules")
-- to hyprland.lua. Beware: its opacity rules overlap with (and would
-- override) the ones already set in hyprland.lua.

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/ for more
-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/ for workspace rules

-- Example windowrule
hl.window_rule({
    match = { class = "^(kitty)$", title = "^(kitty)$" },
    float = true,
})

-- Ignore maximize requests from apps. You'll probably like this.
-- hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- Fix some dragging issues with XWayland
hl.window_rule({
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- make window look transparent based on focus state
-- The first value  -> opacity when the window is active (focused)
-- The second value -> opacity when inactive (unfocused)
hl.window_rule({ match = { class = "^(code)$" },    opacity = "0.85 0.7" })
hl.window_rule({ match = { class = "^(firefox)$" }, opacity = "0.85 0.7" })
hl.window_rule({ match = { class = "^(spotify)$" }, opacity = "0.80 0.7" })

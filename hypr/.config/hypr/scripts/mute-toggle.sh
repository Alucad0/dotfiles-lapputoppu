#!/usr/bin/env bash
# Toggle speaker mute; play a feedback blip when sound comes back on.
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
if ! wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; then
    pw-play /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga &
fi

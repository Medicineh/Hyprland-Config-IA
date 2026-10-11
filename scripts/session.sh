#!/bin/bash
# Salir / reiniciar / apagar cerrando antes Firefox con limpieza.
#   session.sh logout|reboot|poweroff
# Si Firefox muere con la sesión (Hyprland cae y pierde Wayland, o systemd le manda
# SIGTERM), no guarda la sesión y al volver pregunta si restaurarla. Cerrar sus ventanas
# desde el compositor es como pulsar la X: sale bien y guarda sessionstore.jsonlz4.

action=$1
case $action in
    logout|reboot|poweroff) ;;
    *) echo "uso: session.sh logout|reboot|poweroff" >&2; exit 2 ;;
esac

if pgrep -x firefox >/dev/null; then
    for addr in $(hyprctl clients -j | jq -r '.[] | select(.class == "firefox") | .address'); do
        hyprctl dispatch "hl.dsp.window.close({ window = 'address:$addr' })" >/dev/null
    done
    for _ in $(seq 1 40); do
        pgrep -x firefox >/dev/null || break
        sleep 0.25
    done
    if pgrep -x firefox >/dev/null; then
        notify-send -u critical "Firefox sigue abierto" "Ciérralo (o responde a su aviso) y vuelve a intentarlo."
        exit 1
    fi
fi

# Animacion CRT power-off
hyprctl eval "hl.config({decoration={screen_shader='$HOME/.config/hypr/shaders/poweroff.frag'}})"
sleep 2.8

case $action in
    logout)   hyprctl dispatch 'hl.dsp.exit()' ;;
    reboot)   systemctl reboot ;;
    poweroff) systemctl poweroff ;;
esac

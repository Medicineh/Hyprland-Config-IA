#!/usr/bin/env bash
# Wallpapers por escritorio: cada workspace tiene su fondo y lo conserva (también tras
# reiniciar) hasta que lo cambies. Imágenes con awww, vídeos con mpvpaper.
#   wallpaper.sh init                 -> nuevo sorteo para todos los escritorios (a mano)
#   wallpaper.sh ws <id> <mon> [WxH]  -> mostrar el fondo del escritorio <id> en <mon> (hook de Hyprland)
#   wallpaper.sh current|restore      -> volver a pintar los escritorios visibles (autostart, monitor conectado)
#   wallpaper.sh random|image|video   -> otro fondo al azar para el escritorio actual
#   wallpaper.sh pick                 -> elegir con rofi el fondo del escritorio actual (󰕧 = vídeo)
#   wallpaper.sh pause|resume         -> pausar/reanudar el vídeo (lo usa el modo juego)
#   wallpaper.sh prescale             -> crear las copias a resolución de pantalla que falten
#
# Optimización:
# - El sorteo automático usa solo imágenes (awww: cambiar cuesta ~0 CPU). Los vídeos solo si
#   los eliges a mano, y mpvpaper solo corre mientras se ve un escritorio con vídeo.
# - Las imágenes se pintan desde una copia JPG a la resolución del monitor (~/.cache/wallpaper-scaled):
#   un 5K tarda ~400 ms en cargar y su copia a 1440p ~25 ms. Los originales no se tocan.
# - Si ya se muestra el fondo correcto, no hace nada (4 ms).
DIR="$HOME/Imágenes/wallpapers"
LIVE="$DIR/live"
LIVE180="$DIR/live-180"                  # mismos vídeos interpolados a 180 fps (to180.sh)
THUMBS="$HOME/.cache/wallpaper-thumbs"
SCALED="$HOME/.cache/wallpaper-scaled"
RUN="$XDG_RUNTIME_DIR/ws-walls"          # shown-<mon> = el que se ve, candados
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ws-walls"   # <id> = fondo asignado (persiste entre sesiones)
WORKSPACES=5
RANDOM_VIDEOS=0                          # 1 = el sorteo automático también usa vídeos
MPV_OPTS="no-audio loop hwdec=vaapi vo=gpu-next profile=fast panscan=1.0 video-sync=display-resample"
TRANSITION=(--transition-type fade --transition-duration 0.4 --transition-fps 180)

mkdir -p "$RUN" "$STATE"
is_video() { [[ "${1,,}" =~ \.(mp4|webm|mkv|mov)$ ]]; }
images() { find "$DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort; }
videos() {   # la versión a 180 fps si ya existe; si no, la original
    local f; find "$LIVE" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \) ! -name '*.tmp.*' 2>/dev/null | sort |
        while read -r f; do if [[ -s "$LIVE180/${f##*/}" ]]; then echo "$LIVE180/${f##*/}"; else echo "$f"; fi; done
}
sock() { echo "$XDG_RUNTIME_DIR/mpvpaper-$1.sock"; }
mpv_ipc() { [[ -S "$1" ]] && echo "$2" | socat - "$1" >/dev/null 2>&1; }
monitors() { hyprctl monitors -j | jq -r '.[] | "\(.activeWorkspace.id) \(.name) \(.width)x\(.height)"'; }
active() { hyprctl activeworkspace -j | jq -r '"\(.id) \(.monitor)"'; }
res() { hyprctl monitors -j | jq -r --arg m "$1" '.[] | select(.name == $m) | "\(.width)x\(.height)"'; }

# Miniatura en caché para rofi (primer fotograma a los 2 s en los vídeos)
thumb() {
    local w="$1" t="$THUMBS/$(basename "$1").jpg"
    mkdir -p "$THUMBS"
    if [[ ! -s "$t" || "$w" -nt "$t" ]]; then
        if is_video "$w"; then
            ffmpeg -v error -y -ss 2 -i "$w" -frames:v 1 -vf "scale=480:270:force_original_aspect_ratio=increase,crop=480:270" "$t"
        else
            magick "$w[0]" -thumbnail 480x270^ -gravity center -extent 480x270 "$t"
        fi
    fi
    echo "$t"
}

# Copia de la imagen $1 a la resolución $2 (WxH)
scaled_path() { echo "$SCALED/$2/$(basename "${1%.*}").jpg"; }
scale() {
    local w="$1" r="$2" t; t=$(scaled_path "$1" "$2")
    [[ -s "$t" && ! "$w" -nt "$t" ]] && return
    mkdir -p "$SCALED/$r"
    nice -n 19 magick "$w[0]" -resize "$r^" -gravity center -extent "$r" -quality 95 "$t.tmp.jpg" &&
        mv "$t.tmp.jpg" "$t"
}
# Lo que se pasa a awww: la copia escalada si ya existe; si no, el original
fast() {
    local t; t=$(scaled_path "$1" "$2")
    if [[ -n "$2" && -s "$t" && ! "$1" -nt "$t" ]]; then echo "$t"; else echo "$1"; fi
}

# Pinta $1 en el monitor $2 de resolución $3 (sin hacer nada si ya está puesto)
show() {
    local w="$1" mon="$2" r="${3:-$(res "$2")}" s; s=$(sock "$mon")
    [[ "$(cat "$RUN/shown-$mon" 2>/dev/null)" == "$w" ]] && return
    for _ in $(seq 1 50); do awww query &>/dev/null && break; sleep 0.1; done
    if is_video "$w"; then
        # imagen fija del vídeo debajo, para la transición y como respaldo
        awww img -o "$mon" "$(thumb "$w")" --resize crop "${TRANSITION[@]}" >/dev/null 2>&1
        if [[ -S "$s" ]] && pgrep -f "mpvpaper.*$mon" >/dev/null; then
            mpv_ipc "$s" "{\"command\":[\"loadfile\",\"$w\"]}"      # reutiliza el proceso: sin arranque
        else
            mpvpaper -f -p -o "$MPV_OPTS input-ipc-server=$s" "$mon" "$w" >/dev/null 2>&1 9>&-   # sin heredar el candado
        fi
    else
        awww img -o "$mon" "$(fast "$w" "$r")" --resize crop "${TRANSITION[@]}"
        pkill -f "mpvpaper.*-ipc-server=$s" 2>/dev/null   # nada de vídeo en segundo plano
    fi
    echo "$w" > "$RUN/shown-$mon"
}

# Fondo asignado al escritorio $1; si no tiene, sortea uno que no use otro escritorio
assigned() {
    local id="$1" w; w=$(cat "$STATE/$id" 2>/dev/null)
    if [[ ! -f "$w" ]]; then
        w=$(pick_free "$id" image); echo "$w" > "$STATE/$id"
    fi
    echo "$w"
}

# Al azar entre $2 (image|video|random), evitando los que ya usan los escritorios
pick_free() {
    local kind="$2" pool=() w f
    case "$kind" in
        video)  mapfile -t pool < <(videos) ;;
        random) mapfile -t pool < <(images; videos) ;;
        *)      mapfile -t pool < <(images; [[ $RANDOM_VIDEOS == 1 ]] && videos) ;;
    esac
    local -A used=(); for f in "$STATE"/[0-9]*; do [[ -f $f ]] && used["$(<"$f")"]=1; done
    local free=(); for w in "${pool[@]}"; do [[ -n ${used["$w"]} ]] || free+=("$w"); done
    [[ ${#free[@]} -eq 0 ]] && free=("${pool[@]}")
    echo "${free[RANDOM % ${#free[@]}]}"
}

set_current() {   # $1 = fondo nuevo para el escritorio enfocado
    [[ -n "$1" ]] || return
    read -r id mon < <(active)
    echo "$1" > "$STATE/$id"
    show "$1" "$mon"
}

# Copias escaladas que falten, en segundo plano y sin bloquear los cambios de escritorio
prescale_bg() {
    ( exec 9>&- 8>"$RUN/.prescale"; flock -n 8 || exit 0
      mapfile -t imgs < <(images)
      for r in $(monitors | cut -d' ' -f3 | sort -u); do
          for w in "${imgs[@]}"; do scale "$w" "$r"; done
      done ) >/dev/null 2>&1 &
}

# Serializa: cambiar de escritorio rápido no lanza transiciones/mpvpaper en paralelo
exec 9>"$RUN/.lock"; flock -w 15 9 || { echo "wallpaper.sh: candado ocupado" >&2; exit 1; }

case "$1" in
    init)
        rm -f "$STATE"/[0-9]* "$RUN"/shown-*; pkill -x mpvpaper
        for id in $(seq 1 $WORKSPACES); do assigned "$id" >/dev/null; done
        while read -r id mon r; do show "$(assigned "$id")" "$mon" "$r"; done < <(monitors)
        prescale_bg ;;
    ws)      [[ "$2" -ge 1 ]] && show "$(assigned "$2")" "$3" "$4" ;;   # ignora especiales (id < 0)
    current|restore|"")
        rm -f "$RUN"/shown-*
        while read -r id mon r; do [[ $id -ge 1 ]] && show "$(assigned "$id")" "$mon" "$r"; done < <(monitors)
        prescale_bg ;;   # p. ej. un monitor nuevo con otra resolución
    random|image|video) read -r id _ < <(active); set_current "$(pick_free "$id" "$1")" ;;
    pause)  for s in "$XDG_RUNTIME_DIR"/mpvpaper-*.sock; do mpv_ipc "$s" '{"command":["set_property","pause",true]}'; done ;;
    resume) for s in "$XDG_RUNTIME_DIR"/mpvpaper-*.sock; do mpv_ipc "$s" '{"command":["set_property","pause",false]}'; done ;;
    prescale) prescale_bg ;;
    pick)
        flock -u 9   # rofi espera al usuario: no bloquear los cambios de escritorio
        mapfile -t all < <(videos; images)
        choice=$(for w in "${all[@]}"; do
                    label=$(basename "$w"); is_video "$w" && label="󰕧 $label"
                    printf '%s\0icon\x1f%s\n' "$label" "$(thumb "$w")"
                 done | rofi -dmenu -i -p "󰸉 wallpaper" -show-icons -format i \
                    -theme-str 'window { width: 1100px; } element { orientation: vertical; } element-icon { size: 10em; } element-text { horizontal-align: 0.5; } listview { columns: 4; lines: 3; }')
        flock -w 15 9 || exit 1
        [[ -n "$choice" ]] && set_current "${all[$choice]}" ;;
    *) echo "uso: $0 init|ws <id> <mon> [WxH]|current|random|image|video|pick|pause|resume|prescale" >&2; exit 1 ;;
esac

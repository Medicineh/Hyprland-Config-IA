-- ╭──────────────────────────────────────────────────────────╮
-- │              MEDICINE • HYPRLAND • CYBERPUNK             │
-- │   Ryzen 7 9800X3D · RX 9070 XT · 2× 2560x1440            │
-- ╰──────────────────────────────────────────────────────────╯

local c = {
    pink   = "rgba(ff0055ff)",
    cyan   = "rgba(00ffc8ff)",
    yellow = "rgba(fffc58ff)",
    purple = "rgba(9d4eddff)",
    dim    = "rgba(56346688)",
    shadow = "rgba(ff005544)",
}

local home        = os.getenv("HOME")
local scripts     = home .. "/.config/hypr/scripts"
local terminal    = "kitty"
local fileManager = "dolphin"
local browser     = "firefox"
local menu        = "pkill -x rofi || rofi -show drun"   -- toggle


------------------
---- MONITORS ----
------------------

-- vrr = 2: VRR solo en pantalla completa (vrr = 1 aquí anulaba misc.vrr y lo dejaba siempre puesto)
-- bitdepth = 10: el G50SF es de 10 bits (EDID); menos banding en blur/glow. Capturas siguen a 8 bits (misc.screencopy_force_8b)
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "0x0",       scale = 1, vrr = 2 })
hl.monitor({ output = "DP-2",     mode = "2560x1440@180", position = "auto-left", scale = 1, vrr = 2, bitdepth = 10 })
hl.monitor({ output = "",         mode = "preferred",     position = "auto",      scale = "auto" })


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GTK_THEME", "Cyberpunk-Neon")      -- ~/.local/share/themes; solo en Hyprland, KDE sigue con Breeze
hl.env("XDG_MENU_PREFIX", "plasma-")   -- menú "Abrir con" de Dolphin


-------------------
---- AUTOSTART ----
-------------------

-- Escritorio 2: Claude Code a la izquierda y una terminal a la derecha.
-- La terminal se lanza cuando ya existe la ventana de Claude, con el split forzado a la
-- derecha (dwindle seguiría al ratón); fish -C deja la shell abierta al salir de claude.
function claude_workspace()
    hl.config({ dwindle = { force_split = 2 } })
    local sub
    sub = hl.on("window.open", function()
        for _, w in ipairs(hl.get_windows()) do
            if w.class == "kitty-claude" then
                sub:remove()
                hl.exec_cmd(terminal, { workspace = "2 silent" })
                hl.timer(function() hl.config({ dwindle = { force_split = 0 } }) end, { timeout = 4000, type = "oneshot" })
                return
            end
        end
    end)
    hl.exec_cmd(terminal .. " --class kitty-claude fish -C claude", { workspace = "2 silent" })
end

-- Apps sociales al arrancar: Discord + Signal en el escritorio 4 (sin cambiar de
-- escritorio); Steam minimizado en la bandeja (-silent). Son reglas por clase y no
-- `exec_cmd(..., {workspace})` porque Discord se relanza al autoactualizarse.
-- Solo duran el arranque: luego, abrirlas desde la bandeja las trae al escritorio actual.
local startup_rules = {
    hl.window_rule({ name = "startup-ws4", match = { class = "^(discord|signal)$" }, workspace = "4 silent", enabled = false }),
}
function startup_apps()
    -- apagadas por defecto: recargar el config (al guardar) no las activa; solo el arranque
    for _, r in ipairs(startup_rules) do r:set_enabled(true) end
    hl.exec_cmd("sleep 5 && steam -silent")   -- solo icono en la bandeja
    hl.exec_cmd("sleep 6 && discord")
    hl.exec_cmd("sleep 7 && signal-desktop")
    hl.timer(function()
        for _, r in ipairs(startup_rules) do r:set_enabled(false) end
    end, { timeout = 180000, type = "oneshot" })   -- 3 min: margen para actualizaciones de Steam/Discord
end

-- Mientras arranca todo, la pantalla se queda en el escritorio 1 (Firefox): si una app que
-- se abre (Steam, Discord, kitty…) te lleva a su escritorio, se vuelve al 1. Lo suelta
-- SUPER+número (también SUPER+F-número, SUPER+rueda o clic en waybar), o solo a los 3 min.
startup_hold = false
local function hold_release()
    if not startup_hold then return end
    startup_hold = false
    hl.config({ misc = { focus_on_activate = true } })
end
function goto_ws(i)   -- waybar: hyprctl eval 'goto_ws(N)'
    hold_release()
    hl.dispatch(hl.dsp.focus({ workspace = i }))
end
function move_to_ws(i)
    hold_release()
    hl.dispatch(hl.dsp.window.move({ workspace = i }))
end
function startup_hold_start()
    startup_hold = true
    hl.config({ misc = { focus_on_activate = false } })   -- que las apps no pidan foco
    hl.timer(hold_release, { timeout = 180000, type = "oneshot" })
end
hl.on("workspace.active", function()
    if not startup_hold then return end
    local ws = hl.get_active_workspace()
    if ws and not ws.special and ws.id ~= 1 then
        -- diferido: despachar dentro del propio evento se ignora
        hl.timer(function()
            if startup_hold then hl.dispatch(hl.dsp.focus({ workspace = 1 })) end
        end, { timeout = 50, type = "oneshot" })
    end
end)

hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd(scripts .. "/wallpaper.sh restore")   -- cada escritorio con el fondo que le dejaste
    hl.exec_cmd(home .. "/.config/waybar/scripts/workspaces.py")
    hl.exec_cmd(home .. "/.config/waybar/scripts/launch.sh")   -- supervisor: relanza si crashea
    hl.exec_cmd("swaync")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("/usr/lib/pam_kwallet_init")   -- desbloquea KWallet (contraseñas de Chromium, etc.)
    hl.exec_cmd("kdeconnectd")
    hl.exec_cmd("sleep 3 && arch-update --tray")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd(home .. "/.local/bin/protonvpn-autostart")   -- espera a la bandeja de waybar
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hyprctl setcursor capitaine-cursors 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'capitaine-cursors'")

    -- Apps de inicio en su escritorio (la pantalla se queda en el 1)
    startup_hold_start()
    hl.exec_cmd(browser,  { workspace = "1 silent" })
    claude_workspace()
    hl.exec_cmd(fileManager, { workspace = "3 silent" })

    -- Discord + Signal -> 4, Steam a la bandeja; esperan a que el resto arranque
    startup_apps()
end)

-- Monitor conectado en caliente (p. ej. encender el DP-2): wallpaper + asegurar waybar
hl.on("monitor.added", function()
    hl.exec_cmd("sleep 1 && " .. scripts .. "/wallpaper.sh current")
    hl.exec_cmd(home .. "/.config/waybar/scripts/launch.sh")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 14,
        border_size = 2,

        col = {
            active_border   = { colors = { c.pink, c.purple, c.cyan }, angle = 45 },
            inactive_border = c.dim,
        },

        resize_on_border = true,
        allow_tearing    = true,   -- para juegos en pantalla completa
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2.5,

        active_opacity   = 0.97,
        inactive_opacity = 0.88,

        shadow = {
            enabled        = true,
            range          = 22,
            render_power   = 3,
            color          = c.shadow,
            color_inactive = "rgba(00000066)",
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 3,
            noise             = 0.02,
            contrast          = 1.1,
            brightness        = 0.9,
            vibrancy          = 0.25,
            vibrancy_darkness = 0.3,
            new_optimizations = true,
            popups            = true,
            special           = true,
        },

        dim_special = 0.4,
    },

    animations = {
        enabled              = true,
        workspace_wraparound = true,
    },
})

hl.curve("wind",   { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("winIn",  { type = "bezier", points = { {0.1, 1.1},  {0.1, 1.1}  } })
hl.curve("winOut", { type = "bezier", points = { {0.3, -0.3}, {0, 1}      } })
hl.curve("liner",  { type = "bezier", points = { {1, 1},      {1, 1}      } })
hl.curve("snappy", { type = "bezier", points = { {0.23, 1},   {0.32, 1}   } })
hl.curve("bouncy", { type = "spring", mass = 1, stiffness = 220, dampening = 20 })

hl.animation({ leaf = "windows",     enabled = true, speed = 5,  spring = "bouncy", style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 5,  spring = "bouncy", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 4,  bezier = "winOut", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5,  bezier = "wind",   style = "slide" })
hl.animation({ leaf = "border",      enabled = true, speed = 1,  bezier = "liner" })
-- borderangle en "loop" obliga a redibujar cada frame (180 Hz) aunque no se mueva nada: borde fijo
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "fade",        enabled = true, speed = 6,  bezier = "snappy" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 4,  bezier = "snappy", style = "slide" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 3,  bezier = "snappy", style = "fade" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5,  bezier = "wind",   style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "wind", style = "slidevert" })

hl.config({
    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        vrr                     = 2,      -- VRR solo en pantalla completa
        focus_on_activate       = true,
        enable_swallow          = true,
        swallow_regex           = "^(kitty|kitty-claude)$",
        animate_manual_resizes  = true,
        background_color        = "rgba(0d0a10ff)",
    },
    -- Juegos a pantalla completa directos al monitor (sin pasar por el compositor): menos latencia
    render = { direct_scanout = 2 },
    cursor = {
        no_hardware_cursors = false,
        hide_on_key_press   = true,
    },
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout    = "es",
        kb_variant   = "deadtilde",
        kb_model     = "pc105",
        numlock_by_default = true,
        follow_mouse = 1,
        sensitivity  = 0,
        accel_profile = "flat",
    },
})


---------------------
---- KEYBINDINGS ----
---------------------

local mod = "SUPER"

-- Apps
hl.bind(mod .. " + Return",      hl.dsp.exec_cmd(terminal), { desc = "Terminal" })
hl.bind(mod .. " + E",           hl.dsp.exec_cmd(fileManager), { desc = "Gestor de archivos" })
hl.bind(mod .. " + B",           hl.dsp.exec_cmd(browser), { desc = "Navegador" })
hl.bind(mod .. " + D",           hl.dsp.exec_cmd(menu), { desc = "Lanzador de apps" })
hl.bind(mod .. " + SPACE",       hl.dsp.exec_cmd(menu), { desc = "Lanzador de apps" })
hl.bind(mod .. " + TAB",         hl.dsp.exec_cmd("rofi -show window"), { desc = "Cambiar de ventana" })
-- ALT+TAB clásico: salta a la siguiente/anterior ventana del escritorio y la trae al frente
local function cycle_window(next)
    hl.dispatch(hl.dsp.window.cycle_next({ next = next }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end
hl.bind("ALT + TAB",             function() cycle_window(true) end, { desc = "Siguiente ventana" })
hl.bind("ALT + SHIFT + TAB",     function() cycle_window(false) end, { desc = "Ventana anterior" })
hl.bind(mod .. " + SHIFT + V",   hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p '󰅌 clip' | cliphist decode | wl-copy"), { desc = "Historial del portapapeles" })
hl.bind(mod .. " + N",           hl.dsp.exec_cmd("swaync-client -t -sw"), { desc = "Centro de notificaciones" })
hl.bind(mod .. " + ESCAPE",      hl.dsp.exec_cmd("wlogout -b 5 -T 400 -B 400"), { desc = "Menú de apagado" })
hl.bind(mod .. " + L",           hl.dsp.exec_cmd("loginctl lock-session"), { desc = "Bloquear pantalla" })
hl.bind(mod .. " + SHIFT + B",   hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"), { desc = "Mostrar/ocultar barra" })   -- mostrar/ocultar barra
hl.bind(mod .. " + W",           hl.dsp.exec_cmd(scripts .. "/wallpaper.sh random"), { desc = "Wallpaper aleatorio" })
hl.bind(mod .. " + SHIFT + W",   hl.dsp.exec_cmd(scripts .. "/wallpaper.sh pick"), { desc = "Elegir wallpaper" })
hl.bind(mod .. " + SHIFT + C",   hl.dsp.exec_cmd("hyprpicker -a"), { desc = "Selector de color" })
hl.bind(mod .. " + H",           hl.dsp.exec_cmd(scripts .. "/keybinds.py"), { desc = "Esta chuleta" })   -- chuleta de atajos

-- (modo juego, terminal desplegable, zoom y CRT: ver sección LUA POWER al final)

-- Capturas
hl.bind("Print",                 hl.dsp.exec_cmd("hyprshot -m output -o ~/Imágenes/Capturas\\ de\\ pantalla"), { desc = "Captura de pantalla completa" })
hl.bind(mod .. " + SHIFT + S",   hl.dsp.exec_cmd("hyprshot -m region -z -o ~/Imágenes/Capturas\\ de\\ pantalla"), { desc = "Captura de región" })
hl.bind(mod .. " + Print",       hl.dsp.exec_cmd("hyprshot -m window -o ~/Imágenes/Capturas\\ de\\ pantalla"), { desc = "Captura de ventana" })

-- Ventanas
hl.bind(mod .. " + Q",           hl.dsp.window.close(), { desc = "Cerrar ventana" })
hl.bind(mod .. " + SHIFT + Q",   hl.dsp.window.kill(), { desc = "Matar ventana" })
hl.bind(mod .. " + F",           hl.dsp.window.fullscreen(), { desc = "Pantalla completa" })
hl.bind(mod .. " + V",           hl.dsp.window.float({ action = "toggle" }), { desc = "Flotante on/off" })
hl.bind(mod .. " + C",           hl.dsp.window.center(), { desc = "Centrar ventana" })
hl.bind(mod .. " + P",           hl.dsp.window.pseudo(), { desc = "Pseudo-tiling" })
hl.bind(mod .. " + J",           hl.dsp.layout("togglesplit"), { desc = "Cambiar orientación del split" })
hl.bind(mod .. " + SHIFT + M",   hl.dsp.exec_cmd(scripts .. "/session.sh logout"), { desc = "Salir de Hyprland" })   -- cierra Firefox antes

for dir, arrow in pairs({ left = "←", right = "→", up = "↑", down = "↓" }) do
    hl.bind(mod .. " + " .. dir,              hl.dsp.focus({ direction = dir }),        { desc = "Foco " .. arrow })
    hl.bind(mod .. " + SHIFT + " .. dir,      hl.dsp.window.move({ direction = dir }),  { desc = "Mover ventana " .. arrow })
end
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 40,  y = 0,   relative = true }), { repeating = true, desc = "Redimensionar →" })
hl.bind(mod .. " + CTRL + left",  hl.dsp.window.resize({ x = -40, y = 0,   relative = true }), { repeating = true, desc = "Redimensionar ←" })
hl.bind(mod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true, desc = "Redimensionar ↓" })
hl.bind(mod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true, desc = "Redimensionar ↑" })

-- Colocar la ventana en una mitad o un cuarto del monitor (flotante, respetando waybar y gaps).
-- SUPER+ALT+flechas = mitades; SUPER+ALT+U/I/N/M = cuartos (su posición en el teclado).
-- SUPER+V la devuelve al mosaico. Coordenadas globales: el monitor no empieza en 0,0.
local snap_zones = {   -- { x, y, ancho, alto } en fracciones del área útil
    left = { 0, 0, 0.5, 1 },   right = { 0.5, 0, 0.5, 1 },
    up   = { 0, 0, 1, 0.5 },   down  = { 0, 0.5, 1, 0.5 },
    tl   = { 0, 0, 0.5, 0.5 }, tr    = { 0.5, 0, 0.5, 0.5 },
    bl   = { 0, 0.5, 0.5, 0.5 }, br  = { 0.5, 0.5, 0.5, 0.5 },
}
function snap_window(zone, w)
    w = w or hl.get_active_window()
    local m, z = w and w.monitor, snap_zones[zone]
    if not (m and z) then return end
    -- gaps_out/gaps_in pueden venir como número o como tabla por lado (modo juego los pone a 0)
    local function side(v, k) return type(v) == "table" and v[k] or v or 0 end
    local out, gin = hl.get_config("general.gaps_out"), hl.get_config("general.gaps_in")
    local b, r = hl.get_config("general.border_size") or 0, m.reserved
    -- área útil: monitor menos waybar (reserved) y gaps exteriores
    local ax = m.x + r.left + side(out, "left")
    local ay = m.y + r.top + side(out, "top")
    local aw = m.width / m.scale - r.left - r.right - side(out, "left") - side(out, "right")
    local ah = m.height / m.scale - r.top - r.bottom - side(out, "top") - side(out, "bottom")
    local x, y = ax + z[1] * aw, ay + z[2] * ah
    local cw, ch = z[3] * aw, z[4] * ah
    -- gaps interiores solo en los bordes que tocan otra zona, como en el mosaico
    if z[1] > 0 then x = x + side(gin, "left"); cw = cw - side(gin, "left") end
    if z[1] + z[3] < 1 then cw = cw - side(gin, "right") end
    if z[2] > 0 then y = y + side(gin, "top"); ch = ch - side(gin, "top") end
    if z[2] + z[4] < 1 then ch = ch - side(gin, "bottom") end
    local sel = "address:" .. w.address
    hl.dispatch(hl.dsp.window.float({ action = "enable", window = sel }))
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(cw - 2 * b), y = math.floor(ch - 2 * b), window = sel }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(x + b), y = math.floor(y + b), window = sel }))
end
for key, zone in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
    hl.bind(mod .. " + ALT + " .. key, function() snap_window(zone) end, { desc = "Ventana a la mitad " .. ({ left = "izquierda", right = "derecha", up = "de arriba", down = "de abajo" })[zone] })
end
for key, zone in pairs({ U = "tl", I = "tr", N = "bl", M = "br" }) do
    hl.bind(mod .. " + ALT + " .. key, function() snap_window(zone) end, { desc = "Ventana al cuarto " .. ({ tl = "↖", tr = "↗", bl = "↙", br = "↘" })[zone] })
end

-- Workspaces
for i = 1, 5 do   -- solo 5 escritorios: SUPER+1..5
    local key = i
    hl.bind(mod .. " + " .. key,         function() goto_ws(i) end,    { desc = "Ir al workspace " .. i })
    hl.bind(mod .. " + SHIFT + " .. key, function() move_to_ws(i) end, { desc = "Mover ventana al workspace " .. i })
end
-- Estilo KDE: SUPER+F1..F5 -> escritorio 1..5 (Ctrl+F1..F4 no: Ctrl+F4 cierra pestañas en las apps)
for i = 1, 5 do
    hl.bind(mod .. " + F" .. i, function() goto_ws(i) end, { desc = "Ir al workspace " .. i .. " (estilo KDE)" })
end
hl.bind(mod .. " + S",           hl.dsp.workspace.toggle_special("magic"), { desc = "Mostrar escritorio especial (magic)" })
hl.bind(mod .. " + ALT + S",     hl.dsp.window.move({ workspace = "special:magic" }), { desc = "Mover ventana a magic" })
hl.bind(mod .. " + mouse_down",  function() goto_ws("e+1") end, { desc = "Workspace siguiente" })
hl.bind(mod .. " + mouse_up",    function() goto_ws("e-1") end, { desc = "Workspace anterior" })

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, desc = "Arrastrar ventana" })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, desc = "Redimensionar con ratón" })

-- Rofi en Wayland no recibe los clics de fuera: cerrarlo si se clica fuera de su ventana
hl.bind("mouse:272", function()
    local layers = hl.get_layers({ namespace = "rofi" })
    if #layers == 0 then return end
    local p = hl.get_cursor_pos()
    for _, l in ipairs(hl.get_layers({ namespace = "waybar" })) do   -- la barra se encarga ella (launcher = toggle)
        table.insert(layers, l)
    end
    for _, l in ipairs(layers) do
        if p.x >= l.x and p.x <= l.x + l.w and p.y >= l.y and p.y <= l.y + l.h then return end
    end
    hl.exec_cmd("pkill -x rofi")
end, { non_consuming = true, desc = "Cerrar el launcher al clicar fuera" })

-- Multimedia
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, desc = "Subir volumen" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, desc = "Bajar volumen" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, desc = "Silenciar" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, desc = "Silenciar micro" })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, desc = "Siguiente pista" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Play/pausa" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, desc = "Play/pausa" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, desc = "Pista anterior" })


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({
    name  = "float-utilities",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|org.kde.kcalc|org.kde.ark|com.saivert.pwvucontrol|xdg-desktop-portal-gtk|hyprland-share-picker)$" },
    float  = true,
    center = true,
    size   = "900 600",
})

-- Signal se abre flotante en el cuarto inferior derecho (snap_window calcula waybar y gaps;
-- se retrasa porque los cambios dentro del propio window.open se pierden)
hl.window_rule({ name = "signal-quarter", match = { class = "^signal$" }, float = true })
hl.on("window.open", function(w)
    if w.class == "signal" then
        hl.timer(function() snap_window("br", w) end, { timeout = 150, type = "oneshot" })
    end
end)

hl.window_rule({
    name  = "float-dialogs",
    match = { title = "^(Abrir archivo|Guardar como|Open File|Save As|Picture-in-Picture|Imagen en imagen)$" },
    float = true,
})

hl.window_rule({
    name  = "games-no-blur",
    match = { class = "^(steam_app_.*|gamescope|cs2|.*\\.exe)$" },
    immediate = true,
    opaque    = true,
    no_blur   = true,
})

hl.window_rule({
    name  = "media-opaque",
    match = { class = "^(mpv|haruna|org.kde.haruna|vlc|obs|com.obsproject.Studio|gimp|Gimp)$" },
    opaque = true,
})

-- Blur detrás de las capas (barra, launcher, notificaciones, logout)
hl.layer_rule({ name = "blur-waybar",  match = { namespace = "^waybar$" },           blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "blur-rofi",    match = { namespace = "^rofi$" },             blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "blur-swaync",  match = { namespace = "^swaync-.*$" },        blur = true, ignore_alpha = 0.2 })
hl.layer_rule({ name = "blur-logout",  match = { namespace = "^logout_dialog$" },    blur = true })

-- Animaciones de capas
hl.layer_rule({ name = "anim-rofi",   match = { namespace = "^rofi$" },          animation = "popin 90%" })
hl.layer_rule({ name = "anim-swaync", match = { namespace = "^swaync-control-center$" }, animation = "slide right" })
hl.layer_rule({ name = "anim-logout", match = { namespace = "^logout_dialog$" }, animation = "fade" })
hl.layer_rule({ name = "no-anim-selection", match = { namespace = "^(selection|hyprpicker)$" }, no_anim = true })


--------------------------------------------------------------------
---- LUA POWER ------------------------------------------------------
--------------------------------------------------------------------

-- ── Efectos de GPU: glow de neón real + motion blur ──
hl.config({
    decoration = {
        glow = {
            enabled        = true,
            range          = 14,
            render_power   = 3,
            color          = "rgba(ff005599)",
            color_inactive = "rgba(00000000)",
        },
        motion_blur = { enabled = true, samples = 8 },
        blur        = { passes = 4, size = 7 },
    },
})

-- ── Neón por workspace: cada escritorio cambia el color del borde y del glow ──
local NEON = {
    { "ff0055", "9d4edd", "00ffc8" },   -- 1 rosa → morado → cian
    { "00ffc8", "0088ff", "9d4edd" },   -- 2 cian → azul
    { "fffc58", "ff8800", "ff0055" },   -- 3 amarillo → naranja
    { "9d4edd", "ff0055", "fffc58" },   -- 4 morado → rosa
    { "00ff88", "00ffc8", "0088ff" },   -- 5 verde tóxico
}
local function apply_neon()
    local ws = hl.get_active_workspace()
    local id = ws and tonumber(ws.id) or 1
    if id < 1 then id = 1 end
    local n = NEON[((id - 1) % #NEON) + 1]
    hl.config({
        general    = { col = { active_border = { colors = { "rgba(" .. n[1] .. "ff)", "rgba(" .. n[2] .. "ff)", "rgba(" .. n[3] .. "ff)" }, angle = 45 } } },
        decoration = { glow = { color = "rgba(" .. n[1] .. "99)" }, shadow = { color = "rgba(" .. n[1] .. "44)" } },
    })
end
hl.on("workspace.active", apply_neon)
hl.on("monitor.focused", apply_neon)

-- ── Fondo por escritorio (wallpaper.sh ws); solo lanza el script si cambia el escritorio ──
local wall_ws = {}
local function apply_wall()
    local ws = hl.get_active_workspace()
    if not ws or ws.special or ws.id < 1 then return end
    local mon = ws.monitor and ws.monitor.name
    if not mon or wall_ws[mon] == ws.id then return end
    wall_ws[mon] = ws.id
    local m = ws.monitor
    hl.exec_cmd(scripts .. "/wallpaper.sh ws " .. ws.id .. " " .. mon .. " " .. m.width .. "x" .. m.height)
end
hl.on("workspace.active", apply_wall)
hl.on("monitor.focused", apply_wall)

-- ── Modo juego (SUPER+G manual, o automático al abrir un juego) ──
-- Quita blur/glow/sombras/animaciones/huecos y pausa el wallpaper de vídeo.
local gamemode, gamemode_auto = false, false
function gamemode_set(on, auto)
    if on == gamemode then return end
    gamemode, gamemode_auto = on, on and auto or false
    local fx = not on
    hl.config({
        animations = { enabled = fx },
        decoration = {
            blur = { enabled = fx }, shadow = { enabled = fx }, glow = { enabled = fx },
            motion_blur = { enabled = fx }, rounding = fx and 12 or 0,
        },
        general = { gaps_in = fx and 6 or 0, gaps_out = fx and 14 or 0, border_size = fx and 2 or 1 },
    })
    hl.exec_cmd(scripts .. "/wallpaper.sh " .. (on and "pause" or "resume"))
    hl.exec_cmd("sh -c 'echo " .. (on and "on" or "off") .. " > $XDG_RUNTIME_DIR/gamemode; pkill -RTMIN+9 -x waybar'")
    hl.exec_cmd("notify-send -a Hyprland -i input-gaming '󰊴  Modo juego " .. (on and "ON" or "OFF") ..
        (auto and " (auto)" or "") .. "'")
end
function gamemode_toggle() gamemode_set(not gamemode, false) end
hl.bind(mod .. " + G", gamemode_toggle, { desc = "Modo juego on/off" })

local function is_game(w)
    local c = (w.class or ""):lower()
    return c:find("^steam_app_") or c == "gamescope" or c == "cs2" or c:find("%.exe$")
end
local function check_games()
    local games = 0
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and is_game(w) then games = games + 1 end
    end
    if games > 0 and not gamemode then
        gamemode_set(true, true)
    elseif games == 0 and gamemode and gamemode_auto then
        gamemode_set(false, true)
    end
end
local function check_games_later() hl.timer(check_games, { timeout = 800, type = "oneshot" }) end
hl.on("window.open", check_games_later)
hl.on("window.close", check_games_later)
hl.on("window.class", check_games_later)

-- ── Terminal desplegable (SUPER+T): se crea la primera vez, luego aparece/desaparece ──
hl.window_rule({ name = "dropterm", match = { class = "^dropterm$" }, float = true, size = "1500 820", center = true })
function dropterm()
    for _, w in ipairs(hl.get_windows()) do
        if w.class == "dropterm" then
            hl.dispatch(hl.dsp.workspace.toggle_special("term"))
            return
        end
    end
    hl.exec_cmd("kitty --class dropterm", { workspace = "special:term" })
end
hl.bind(mod .. " + T", dropterm, { desc = "Terminal desplegable" })

-- ── Lupa (SUPER+CTRL+rueda, SUPER+Z restablece) ──
local function zoom(delta)
    local z = (tonumber(hl.get_config("cursor.zoom_factor")) or 1) + delta
    z = math.max(1, math.min(z, 5))
    hl.config({ cursor = { zoom_factor = z } })
end
hl.bind(mod .. " + CTRL + mouse_down", function() zoom(0.25) end,  { desc = "Lupa: acercar" })
hl.bind(mod .. " + CTRL + mouse_up",   function() zoom(-0.25) end, { desc = "Lupa: alejar" })
hl.bind(mod .. " + Z", function() hl.config({ cursor = { zoom_factor = 1 } }) end, { desc = "Lupa: restablecer" })

-- ── Modo CRT (SUPER+X): shader de pantalla con scanlines ──
local crt = false
hl.bind(mod .. " + X", function()
    crt = not crt
    hl.config({
        debug = { damage_tracking = crt and 0 or 2 },
        decoration = { screen_shader = crt and (home .. "/.config/hypr/shaders/crt.frag") or "" },
    })
end, { desc = "Modo CRT on/off" })

-- ── Picture-in-Picture: flotante, fijado en todos los escritorios, abajo a la derecha ──
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Imagen en imagen)$" },
    float = true,
    pin   = true,
    size  = "640 360",
    move  = "monitor_w-window_w-24 monitor_h-window_h-24",
    keep_aspect_ratio = true,
})

-- ── Privacidad al compartir pantalla: las notificaciones no salen en el stream ──
hl.layer_rule({ name = "no-share-swaync", match = { namespace = "^swaync-.*$" }, no_screen_share = true })
hl.on("screenshare.state", function(...)
    hl.exec_cmd("notify-send -a Hyprland -u low '󰹑  Compartiendo pantalla' 'Las notificaciones no se ven en la captura'")
end)


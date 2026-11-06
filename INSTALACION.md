# ALBA · Instalación limpia en Debian 13

Guía para reconstruir ALBA + Umbriel en el mismo equipo, partiendo de un
Debian limpio. Está pensada para no depender de esta sesión ni de la memoria:
incluye repositorios, paquetes, compilación del fork, archivos de usuario,
servicios y comprobaciones.

> **Estado:** el sistema actual funciona para uso diario en este equipo, pero
> B3 (captura/uso compartido desde apps) sigue sin probar. La instalación ya
> está automatizada con `./install.sh`, aunque todavía no se ha ejecutado de
> principio a fin en un Debian recién instalado. Antes de borrar, hacer copia de
> seguridad y leer la sección «Antes de formatear».

---

## 0. Instalador automático

La vía rápida es clonar el repositorio y ejecutar el instalador **como usuario
normal**, nunca con `sudo`:

```sh
git clone git@github.com:Gitnameb/Shell.git ~/Shell
cd ~/Shell
./install.sh --dry-run   # revisar qué hará
./install.sh             # instalar
```

El instalador:

1. Añade `trixie-backports` y el repositorio de Noctalia.
2. Instala Quickshell, Umbriel, el portal, KDE/Qt, audio, red y las
   dependencias de compilación.
3. Enlaza el shell en `~/.config/quickshell/alba` y copia los scripts a
   `~/.local/bin`.
4. Copia la configuración de ALBA y Umbriel **sin sobrescribir** la que ya
   exista. Con `--force-config` la reemplaza y guarda una copia `.bak`.
5. Crea la regla de sudoers de `ddcutil` y activa la unidad de alarmas.
6. Compila e instala el fork de Umbriel con `scripts/install-umbriel-fork.sh`.

Opciones: `--dry-run`, `--skip-packages`, `--skip-fork`, `--skip-config`,
`--force-config`, `--with-firmware` y `--help`.

> Probado con `--dry-run` y con una compilación completa desde un clon limpio
> de Umbriel. **Falta la prueba definitiva en un Debian recién instalado.**
> El resto de esta guía documenta el proceso manual y sirve para revisar o
> reparar lo que haga el script.

---

## 1. Equipo y sistema actual

| Elemento | Valor actual |
| --- | --- |
| Debian | 13.7 «trixie», amd64 |
| Kernel | 6.12.115+deb13.1-amd64 |
| CPU | Intel Core i3-10105F (4 núcleos / 8 hilos) |
| GPU | AMD Radeon RX 570 (amdgpu, 4 GB) |
| RAM | 23 GiB |
| Wi-Fi | Intel Wi-Fi 6E AX210 (iwlwifi) |
| Bluetooth | Intel AX210 (bluez) |
| Ethernet | Realtek RTL8111 |
| Monitor | LG FULL HD por HDMI-A-1, 1920×1080 |
| Batería | No hay; el icono de ALBA muestra corriente y no porcentaje |
| Sesión | Umbriel (Wayland), SDDM |
| Escritorios | 9 fijos, configurados en Umbriel |
| Repos extra | `trixie-backports` y Noctalia (`pkg.noctalia.dev`) |

Discos actuales, solo como referencia: raíz en `/dev/sdb6`, EFI en
`/dev/sdb5`, Windows en `/dev/sdb3` y `/dev/sdb4`, y discos de datos NTFS en
`/dev/sda1` y `/dev/sdc1`. **Comprobar con `lsblk` antes de particionar**: no
dar por hecho que los nombres serán los mismos tras una instalación limpia.

### Versiones de referencia (2026-11-05)

| Paquete | Versión instalada |
| --- | --- |
| Debian | 13.7 |
| kernel | 6.12.115+deb13.1 |
| Qt | 6.8.2 |
| KDE Plasma | 6.3.6 |
| Quickshell | 0.3.0-1~bpo13+1 |
| Umbriel (paquete) | 0.1.0~1505-g63327b58-1~bpo13+1 |
| xdg-desktop-portal-umbriel | 0.1.0~64-ge69d6f72-1+deb13u1 |
| PipeWire | 1.4.2 |
| WirePlumber | 0.5.8 |
| NetworkManager | 1.52.1 |
| ddcutil | 2.2.0 |
| power-profiles-daemon | 0.30 |
| BlueZ | 5.82 |
| hyprlock | 0.9.6-1~bpo13+1 |
| swayidle | 1.8.0 |
| wvkbd | 0.15 |
| fonts-inter | 4.1 |

El binario del fork instalado en `/usr/bin/umbriel` es
`d3f5effaad771b37`; `umbriel --version` puede imprimir una cadena de versión
anterior por cómo se compila. El binario original del paquete está en
`/usr/bin/umbriel.stock-0.1.0`.

---

## 2. Repositorios

### 2.1 Backports de Debian

`quickshell`, `hyprlock`, `libwlroots-0.20-dev` y varias dependencias de
compilación vienen de `trixie-backports`.

```sh
echo 'deb http://deb.debian.org/debian trixie-backports main' \
  | sudo tee /etc/apt/sources.list.d/trixie-backports.list
sudo apt update
```

### 2.2 Repositorio de Noctalia (Umbriel)

Instrucciones oficiales:

```sh
wget https://pkg.noctalia.dev/deb/nickh-archive-keyring.deb
sudo dpkg -i nickh-archive-keyring.deb
sudo wget -O /etc/apt/sources.list.d/noctalia-trixie.sources \
  https://pkg.noctalia.dev/deb/noctalia-trixie.sources
sudo apt update
```

Los archivos de referencia están copiados en `install/apt/`.

---

## 3. Paquetes

La vía más fiel a esta instalación es instalar Debian 13 con el entorno
**KDE Plasma** (`task-kde-desktop`). Aunque ALBA sustituye a Plasma como shell,
KDE aporta SDDM, Qt 6, Breeze, `kdialog`, `plasma-integration`, PipeWire,
NetworkManager, BlueZ, UPower, Polkit y el portal de KDE.

El instalador también funciona sobre un Debian mínimo: instala solo las
librerías y herramientas de KDE que necesita ALBA, **sin `plasma-workspace` ni
`kde-cli-tools`**. Eso evita arrastrar KWin y el escritorio Plasma completo.
La contrapartida es que las apps KDE usarán Breeze claro/oscuro, pero no
heredarán el acento personalizado de ALBA; eso queda pendiente de una
alternativa ligera.

> **Si quieres el modo ligero de verdad**, instala Debian **sin** el task de KDE
> (sistema estándar, sin escritorio) y deja que `install.sh` ponga SDDM, Breeze
> y las librerías. Si ya instalaste KDE, el script no añadirá
> `plasma-workspace`, pero tampoco lo quitará: vendrá con el escritorio.

Después, instalar lo específico:

```sh
sudo apt install -t trixie-backports quickshell hyprlock
sudo apt install -t trixie-backports umbriel xdg-desktop-portal-umbriel

sudo apt install \
  ddcutil qrencode libnotify-bin fonts-inter wvkbd swayidle kitty \
  network-manager-openvpn power-profiles-daemon pulseaudio-utils \
  iputils-ping wl-clipboard \
  qml6-module-qtquick-effects \
  qml6-module-qt5compat-graphicaleffects \
  qml6-module-qt-labs-folderlistmodel \
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-kde \
  xwayland
```

La lista completa, separada por capas y con notas sobre lo que no hace falta,
está en `install/packages.txt`.

### Dependencias que usa ALBA

- **Qt/Quickshell:** `quickshell`, `qml6-module-qtquick-effects`,
  `qml6-module-qt5compat-graphicaleffects` (portada redondeada y tintado de
  iconos), `qml6-module-qt-labs-folderlistmodel` (iconos del escritorio).
- **KDE/Qt:** `plasma-integration`, `libkf6config-bin`, `kdialog`, `breeze`,
  `breeze-icon-theme`, `breeze-gtk-theme`, `breeze-cursor-theme`,
  `qt6-wayland`, `qt6-qpa-plugins`, `qt6-svg-plugins`.
  `plasma-workspace` y `kde-cli-tools` **no** son necesarios; solo aportan
  `plasma-apply-colorscheme` (acento en apps KDE) y herramientas que ALBA no usa.
- **Audio:** `pipewire`, `pipewire-pulse`, `wireplumber`; `wpctl` para los
  atajos y `paplay` (`pulseaudio-utils`) para las alarmas.
- **Red:** `network-manager`, `network-manager-openvpn`, `nmcli`, `qrencode`
  (QR del hotspot).
- **Energía:** `upower`, `power-profiles-daemon`, `powerprofilesctl`.
- **Brillo:** `ddcutil` y una regla de sudoers (ver abajo).
- **Bloqueo:** `swayidle` y `hyprlock`; el script `alba-idle` los usa.
- **Teclado en pantalla:** `wvkbd` (`wvkbd-mobintl`).
- **Notificaciones/diálogos:** `libnotify-bin`, `kdialog`; `zenity` es un
  respaldo opcional que no está instalado.
- **Clima:** `curl` (consulta `wttr.in`).
- **Portales:** `xdg-desktop-portal`, `-gtk` y `-umbriel`; `-kde` está
  instalado por Plasma. **No instalar `-hyprland`** en la instalación limpia.
- **X11:** `xwayland`.

### Lo que no hace falta

- `hyprland`, `hypridle`, `hyprland-guiutils`: restos de la etapa anterior.
- `xdg-desktop-portal-hyprland`: ya no se usa.
- `wl-clipboard`: aporta `wl-copy` y `wl-paste` para el historial del
  portapapeles. Los binarios de `scripts/bin/` solo son un respaldo local y no
  se publican en el repositorio.
- `grim`, `slurp`, `obs-studio`, `btop`, `wlrctl`, `wtype`, `ydotool`, `wev`,
  `weston`: herramientas de prueba/diagnóstico, no dependencias de uso diario.

---

## 4. Compilar e instalar el fork de Umbriel

El paquete `umbriel` instala el binario original, la sesión de SDDM,
`start-umbriel`, la configuración de ejemplo y el portal. El fork de ALBA
sustituye solo `/usr/bin/umbriel` para añadir la barra nativa con seis botones,
icono, subtítulo y otras mejoras.

### 4.1 Dependencias de compilación

```sh
sudo apt install -t trixie-backports \
  build-essential git meson ninja-build pkg-config \
  libwlroots-0.20-dev libwayland-dev wayland-protocols \
  libdrm-dev libinput-dev libxkbcommon-dev libpixman-1-dev \
  libcairo2-dev libpango1.0-dev libgdk-pixbuf-2.0-dev \
  libtomlplusplus-dev libjemalloc-dev libliftoff-dev \
  libdisplay-info-dev liblcms2-dev libsystemd-dev libudev-dev \
  libxcb1-dev libxcb-icccm4-dev libxcb-ewmh-dev \
  libxcb-randr0-dev libxcb-shape0-dev \
  libeis-dev libseat-dev nlohmann-json3-dev
```

El fork está basado en Umbriel `b6c4b7d` y tiene 24 commits propios. El parche
reproducible es `umbriel-fork.patch` (50 archivos).

### 4.2 Obtener el código

Opción A, restaurar la copia del fork (recomendada si se conserva):

```sh
# Copiar ~/umbriel-fork desde la copia de seguridad a ~/umbriel-fork
cd ~/umbriel-fork
git status
```

Opción B, partir de Umbriel upstream y aplicar el parche:

```sh
git clone https://github.com/noctalia-dev/umbriel.git ~/umbriel-fork
cd ~/umbriel-fork
git checkout b6c4b7d
git apply ~/Documents/Alba/umbriel-fork.patch
```

### 4.3 Compilar e instalar

La forma recomendada es el script del repositorio, que clona la base si hace
falta, aplica el parche, compila, guarda el binario original e instala con `mv`
atómico:

```sh
./scripts/install-umbriel-fork.sh
```

Opciones: `--build-only` (compila sin instalar), `--dry-run`, `--source DIR`,
`--build-dir DIR`, `--no-backup` y `--yes`. Si el árbol `~/umbriel-fork` no
existe, lo clona desde upstream y aplica `umbriel-fork.patch`.

También se puede hacer a mano:

```sh
cd ~/umbriel-fork
meson setup build --prefix=/usr --buildtype=release
ninja -C build

# Guardar el binario del paquete solo la primera vez
sudo cp /usr/bin/umbriel /usr/bin/umbriel.stock-0.1.0

# Instalación atómica: no se puede sobrescribir el binario en uso
sudo cp build/umbriel /usr/bin/umbriel.new
sudo mv -f /usr/bin/umbriel.new /usr/bin/umbriel

# Regenerar el parche si se tocó el fork
git diff b6c4b7d > ~/Documents/Alba/umbriel-fork.patch
```

Después hay que **cerrar sesión y volver a entrar** para que el compositor use
el binario nuevo. `umbriel --version` puede seguir mostrando una cadena de
versión antigua por cómo se compila; lo importante es que el proceso haya
arrancado después de instalar el binario.

> Es normal ver un aviso del enlazador sobre `libdisplay-info.so.2` y
> `libdisplay-info.so.3` si conviven ambas versiones. Comprueba con
> `ldd build/umbriel | grep display-info` que no falta ninguna; si Umbriel
> arranca, el aviso es benigno.

> Si un `apt upgrade` reemplaza `/usr/bin/umbriel`, hay que recompilar el fork o
> restaurar la copia. El parche habrá que rebasarlo si upstream cambia.

### 4.4 Revertir al Umbriel original

```sh
sudo cp /usr/bin/umbriel.stock-0.1.0 /usr/bin/umbriel.restore
sudo mv -f /usr/bin/umbriel.restore /usr/bin/umbriel
```

Cerrar sesión y volver a entrar. Esto elimina la barra nativa del fork, pero
ALBA sigue funcionando con el binario estándar.

---

## 5. Instalar ALBA

### 5.1 Enlazar el shell

```sh
ln -sfn ~/Documents/Alba ~/.config/quickshell/alba
```

Quickshell recarga los QML al guardar. El pragma `UseQApplication` de
`shell.qml` exige reiniciar el proceso cuando se cambia.

### 5.2 Scripts auxiliares

Copiar desde `install/bin/` a `~/.local/bin/` y dar permisos:

```sh
mkdir -p ~/.local/bin
install -m755 install/bin/alba-start ~/.local/bin/alba-start
install -m755 install/bin/alba-idle ~/.local/bin/alba-idle
install -m755 install/bin/alba-keyboard-layout ~/.local/bin/alba-keyboard-layout
install -m755 install/bin/alba-umbriel-theme ~/.local/bin/alba-umbriel-theme
```

- `alba-start`: exporta `QT_QPA_PLATFORMTHEME=kde` y
  `QS_ICON_THEME=breeze-dark`, y ejecuta `qs -c alba -d`.
- `alba-idle`: bloqueo con `swayidle` + `hyprlock`.
- `alba-keyboard-layout`: escribe `[input.keyboard] layout` en Umbriel.
- `alba-umbriel-theme`: sincroniza colores y acento con la barra nativa.

### 5.3 Arranque automático

En `~/.config/umbriel/config.toml`:

```toml
[general]
autostart = ["/home/TU_USUARIO/.local/bin/alba-start"]
```

Sustituye `TU_USUARIO` por tu usuario. El instalador lo hace solo.

### 5.4 Preferencias de ALBA

Si se quieren conservar la disposición actual de la barra, el fondo, el clima y
los modos por escritorio:

```sh
mkdir -p ~/.config/alba
cp install/config/alba-settings.conf ~/.config/alba/settings.conf
cp install/config/alba-display.conf ~/.config/alba/display.conf
```

Revisar `wallpaperPath` (la plantilla lo deja vacío y usa un color de fondo) y
`weatherPlace` (vacío significa que se deduce por IP). No copiar `credenciales`
salvo que se sepa que hace falta: es un secreto local y el código actual no lo
usa.

Los antiguos `alternar-autoocultar.sh`, `alternar-no-molestar.sh` y
`alternar-posicion.sh` están en `install/config/` por si se quieren conservar;
los atajos actuales de Umbriel no los usan.

---

## 6. Configuración de Umbriel

Copiar `install/config/umbriel-config.toml` a
`~/.config/umbriel/config.toml` y revisar:

- `[general] autostart` con la ruta correcta.
- `[appearance.title_bar] buttons = ["float", "pin", "move", "minimize",
  "maximize", "close"]`.
- `[input.keyboard] layout = "es"`.
- `[output."HDMI-A-1"] workspaces = 9`.
- `[layout] mode = "stacking"` y `[layout.stacking]` con el tamaño/cascada
  elegidos.
- `[display]` con brillo, atenuación y luz nocturna.
- Los atajos `Mod+1..9`, `Mod+Shift+1..9`, `Mod+Tab`, etc.

Validar siempre:

```sh
umbriel config validate -c ~/.config/umbriel/config.toml
```

Si el monitor no es `HDMI-A-1`, cambiar el conector. En un portátil será
`eDP-1` o el que corresponda. **Pendiente de automatizar**: hoy hay que repetir
esa sección por conector; más adelante conviene un `alba-workspaces` que lea
`umbriel outputs --json` y escriba el inventario correcto.

---

## 7. Integración del sistema

### 7.1 Portales (captura y uso compartido)

```sh
mkdir -p ~/.config/xdg-desktop-portal
cp install/config/portals.conf ~/.config/xdg-desktop-portal/portals.conf
```

Contenido:

```ini
[preferred]
org.freedesktop.impl.portal.Access=gtk
```

`xdg-desktop-portal-umbriel` implementa ScreenCast y Screenshot; GTK aporta el
diálogo de permiso `Access`, que Umbriel no implementa. Sin esta línea,
`xdg-desktop-portal` puede quedarse esperando y terminar en
«Failed to show access dialog: Timeout was reached».

Paquetes: `xdg-desktop-portal`, `xdg-desktop-portal-gtk`,
`xdg-desktop-portal-umbriel` y, si se usa el selector de archivos de KDE,
`xdg-desktop-portal-kde`. **No** instalar `xdg-desktop-portal-hyprland`.

### 7.2 Alarmas con el shell cerrado

```sh
mkdir -p ~/.config/systemd/user
cp install/systemd/alba-alarms.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now alba-alarms.service
```

La unidad ejecuta `%h/Documents/Alba/scripts/alba-alarms`. Comprueba
`alarms.conf` y `timer.conf` en `~/.config/alba/`.

### 7.3 Brillo por DDC/CI

`ddcutil` instala la regla udev `60-ddcutil-i2c.rules`, que da acceso al
usuario al bus I2C del monitor. Aun así, ALBA llama a `sudo -n ddcutil`, así que
hace falta la regla de sudoers:

```sh
sudo install -m440 -o root -g root \
  install/sudoers/alba-ddcutil /etc/sudoers.d/alba-ddcutil
sudo visudo -cf /etc/sudoers.d/alba-ddcutil
sudo -n ddcutil detect
```

Sustituir `username` por el usuario real si hace falta. En un portátil, el panel
eDP no responde a DDC/CI; la adaptación a `/sys/class/backlight` sigue pendiente.

### 7.4 SDDM

El paquete `umbriel` crea `/usr/share/wayland-sessions/umbriel.desktop` y
`start-umbriel`. SDDM recuerda la última sesión (`RememberLastSession=true`):
en el primer arranque hay que elegir **Umbriel** una vez.

Si se quiere autoinicio (opcional):

```ini
# /etc/sddm.conf.d/20-alba.conf
[Autologin]
User=username
Session=umbriel
Relogin=false
```

No es necesario para el funcionamiento normal.

### 7.5 Red, VPN, Bluetooth y energía

- `NetworkManager` gestiona Ethernet, Wi-Fi y VPN.
- `network-manager-openvpn` es obligatorio para importar `.ovpn`.
- `bluez` y `bluez-obexd` para Bluetooth.
- `upower` y `power-profiles-daemon` para batería y perfiles.
- El hotspot usa `nmcli` y `qrencode`.

Los perfiles de red y VPN viven en `/etc/NetworkManager/system-connections/`
(contienen secretos; copiar con permisos restringidos o reimportar).

### 7.6 Tema de apps

`alba-system-theme` necesita:

- `gsettings` (`libglib2.0-bin`)
- `kwriteconfig6` (`libkf6config-bin`)
- Breeze (`breeze`, `breeze-icon-theme`, `breeze-gtk-theme`)

`plasma-apply-colorscheme` (`plasma-workspace`) es **opcional**: si está, aplica
el acento personalizado a las apps KDE; si no, el script deja `ColorScheme` e
`Icons` en `kdeglobals` y las apps usan Breeze normal. ALBA y GTK no dependen de
él.

### 7.7 Puente X11

El autostart `org.kde.xwaylandvideobridge.desktop` está oculto:

```sh
mkdir -p ~/.config/autostart
cp install/config/xwaylandvideobridge.desktop ~/.config/autostart/
```

Si se necesita compartir ventanas X11, se puede reactivar más adelante. B3
sigue pendiente de probar.

---

## 8. Datos que hay que conservar

### 8.1 Proyecto y fork

- `~/Documents/Alba/` completo (no es un repositorio git).
- `~/umbriel-fork/` completo, incluido `.git` si se quiere conservar la historia.
- `~/Documents/Alba/umbriel-fork.patch`.
- `/usr/bin/umbriel.stock-0.1.0` (binario original del paquete).

### 8.2 Configuración de usuario

- `~/.config/alba/`: `settings.conf`, `display.conf`, `alarms.conf`,
  `notificaciones.json`, `autoocultar`, scripts `alternar-*.sh`.
- `~/.config/alba/credenciales`: contraseña local de sudo, modo 600. No la usa
  el código actual; no incluirla en copias compartidas.
- `~/.config/umbriel/config.toml`.
- `~/.config/xdg-desktop-portal/portals.conf`.
- `~/.config/systemd/user/alba-alarms.service`.
- `~/.local/bin/alba-*`.
- `~/.config/autostart/org.kde.xwaylandvideobridge.desktop`.
- `~/.config/kdeglobals` y `~/.config/gtk-*/` si se quieren conservar; el script
  de tema los recrea.
- Tu fondo de pantalla (cópialo aparte y ajusta `wallpaperPath`).
- `~/.local/state/alba/` (historial de portapapeles y progreso; opcional).

### 8.3 Red y secretos

- `/etc/NetworkManager/system-connections/` (Wi-Fi, VPN; permisos root).
- `/etc/sudoers.d/alba-ddcutil`.
- Claves SSH/GPG y demás datos personales, fuera del alcance de ALBA.

### 8.4 Copia rápida

```sh
mkdir -p ~/backup-alba
tar -C "$HOME" -czf ~/backup-alba/alba-config.tar.gz \
  Documents/Alba .config/alba .config/umbriel \
  .config/xdg-desktop-portal .config/systemd/user \
  .config/autostart .local/bin
sudo tar -C / -czf ~/backup-alba/alba-system.tar.gz \
  etc/sudoers.d/alba-ddcutil \
  etc/NetworkManager/system-connections \
  usr/bin/umbriel.stock-0.1.0
```

Revisar que el archivo de red no se comparte sin protección.

---

## 9. Antes de formatear

1. **Probar B3** si se va a usar compartir pantalla o captura desde Firefox.
   Es lo único funcional que sigue sin verificar.
2. **Probar B5** si se va a usar Wi-Fi/Bluetooth: este equipo tiene AX210 y ahora
   mismo está conectado por Wi-Fi. Los flujos de escaneo, olvido, hotspot y
   emparejamiento se pueden validar antes de borrar.
3. **Decidir A4**: el volumen por ventana sigue en primera versión.
4. **Guardar la copia** de la sección 8 y comprobar que se puede leer.
5. **Probar el instalador en una VM o en un disco aparte.** Ejecuta primero
   `./install.sh --dry-run`, revisa la lista y después `./install.sh`. Confirma
   que ALBA arranca antes de tocar el disco principal.
6. **Anotar la contraseña de sudo** o tenerla a mano; el instalador la pedirá
   para apt, el fork y la regla de `ddcutil`.
7. **Comprobar el disco**: no confundir la raíz Debian con las particiones
   Windows/NTFS.
8. **No ejecutar `umbriel config-replace`** sin querer: borra los layouts por
   escritorio. Si se usa, reaplicar con
   `qs ipc -c alba call windows mode <n> <modo>`.

---

## 10. Verificación después de instalar

```sh
# Shell y compositor
qs -c alba
qs ipc -c alba call windows status
umbriel config validate -c ~/.config/umbriel/config.toml
umbriel workspaces --json

# Debe haber 9 escritorios y el 9 debe poder seleccionarse
umbriel msg workspace-switch 9

# Servicios
systemctl --user status alba-alarms --no-pager
systemctl status bluetooth NetworkManager power-profiles-daemon --no-pager

# Brillo
sudo -n ddcutil detect
```

Comprobar a mano:

- Barra abajo, 9 números de escritorio; los ocupados se iluminan.
- Icono de batería visible sin batería, con rayo amarillo.
- Música: portada redondeada, título/artista, controles al pasar el ratón.
- Tráfico de red con ancho fijo.
- VPN: importar `.ovpn`, engranaje, nombre y arranque automático.
- Clima manual, alarmas y temporizador con ALBA cerrada.
- Portapapeles, teclado en pantalla, bandeja del sistema.
- Brillo, atenuación extra y luz nocturna.
- Bloqueo con `Mod+Shift+L` y `alba-idle`.
- Reinicio de sesión y vuelta a entrar sin perder ventanas minimizadas.

---

## 11. Pendientes que no bloquean el uso diario

- **B3:** portal de captura/uso compartido desde Firefox y X11.
- **B5:** Wi-Fi/Bluetooth/hotspot en hardware real; el AX210 está disponible.
- **A4:** decidir si se mantiene el volumen por ventana.
- **VPN:** opciones extra pendientes de que el usuario las concrete.
- **Reloj:** rediseño de pestañas pendiente de diseño del usuario.
- **Escritorio:** D1 fase 2 (recolocar iconos y persistir posiciones).
- **Energía personalizada:** límites de CPU/GPU/TDP con ayudante polkit.
- **Portátiles:** brillo por `/sys/class/backlight`, umbral de carga y
  `platform_profile`.
- **Escritorios automáticos:** sustituir la sección manual por un script que
  detecte los conectores y ajuste `workspaces` por salida.
- **E1:** hecho. `install.sh` y `scripts/install-umbriel-fork.sh` automatizan
  paquetes, configuración, sudoers, alarmas y compilación del fork. Probados con
  `--dry-run` y con una compilación completa desde un clon limpio; falta la
  prueba definitiva en un Debian recién instalado.
- **E4:** la reversión está documentada en la sección 4.4, pero todavía no se ha
  probado en una instalación limpia.
- **Fork:** cada actualización de Umbriel puede requerir rebase y recompilación.

# Shell · Instalación limpia en Debian 13

Guía para reconstruir el shell + Umbriel en el mismo equipo, partiendo de un
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
3. Enlaza el shell en `~/.config/quickshell/shell` y copia los scripts a
   `~/.local/bin`.
4. Configura NetworkManager para que gestione Ethernet y Wi-Fi (instala
   `wpasupplicant` y `rfkill`, y retira las interfaces de ifupdown).
5. Copia la configuración del shell y Umbriel **sin sobrescribir** la que ya
   exista. Con `--force-config` la reemplaza y guarda una copia `.bak`.
6. Crea la regla de sudoers de `ddcutil` y activa la unidad de alarmas.
7. Compila e instala el fork de Umbriel con `scripts/install-umbriel-fork.sh`.

`install.sh` solo orquesta; cada paso vive en su módulo y se puede revisar o
ejecutar por separado: `scripts/install-packages.sh`, `scripts/network.sh` y
`scripts/install-user-config.sh`.

Opciones: `--dry-run`, `--skip-packages`, `--skip-fork`, `--skip-config`,
`--skip-network`, `--force-config`, `--with-firmware` y `--help`.

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
| Batería | No hay; el icono del shell muestra corriente y no porcentaje |
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
| PipeWire | 1.6.9-2~bpo13+1 |
| WirePlumber | 0.5.12-1~bpo13+1 |
| Mesa | 26.1.6-1~bpo13+1 |
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
**KDE Plasma** (`task-kde-desktop`). Aunque el shell sustituye a Plasma,
KDE aporta SDDM, Qt 6, Breeze, `kdialog`, `plasma-integration`, PipeWire,
NetworkManager, BlueZ, UPower, Polkit y el portal de KDE.

El instalador también funciona sobre un Debian mínimo: instala solo las
librerías y herramientas de KDE que necesita el shell, **sin `plasma-workspace` ni
`kde-cli-tools`**. Eso evita arrastrar KWin y el escritorio Plasma completo.
La contrapartida es que las apps KDE usarán Breeze claro/oscuro, pero no
heredarán el acento personalizado del shell; eso queda pendiente de una
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

### Dependencias que usa el shell

- **Qt/Quickshell:** `quickshell`, `qml6-module-qtquick-effects`,
  `qml6-module-qt5compat-graphicaleffects` (portada redondeada y tintado de
  iconos), `qml6-module-qt-labs-folderlistmodel` (iconos del escritorio).
- **KDE/Qt:** `plasma-integration`, `libkf6config-bin`, `kdialog`, `breeze`,
  `breeze-icon-theme`, `breeze-gtk-theme`, `breeze-cursor-theme`,
  `qt6-wayland`, `qt6-qpa-plugins`, `qt6-svg-plugins`.
  `plasma-workspace` y `kde-cli-tools` **no** son necesarios; solo aportan
  `plasma-apply-colorscheme` (acento en apps KDE) y herramientas que el shell no usa.
- **Audio:** `pipewire`, `pipewire-bin`, `pipewire-pulse`, `wireplumber`,
  `libpipewire-0.3-0t64`, `libpipewire-0.3-modules` y `libspa-0.2-modules`,
  **todos de `trixie-backports` y en el mismo bloque**; `wpctl` para los atajos
  y `paplay` (`pulseaudio-utils`) para las alarmas. Para audio Bluetooth hace
  falta `libspa-0.2-bluetooth`, también de backports; sin él los auriculares se
  emparejan pero no aparecen como salida ni micrófono, y la conexión puede
  fallar con `br-connection-profile-unavailable`.
- **Gráficos:** `libgbm1`, `mesa-libgallium`, `libgl1-mesa-dri`,
  `libglx-mesa0`, `libegl-mesa0`, `mesa-va-drivers` y `mesa-vulkan-drivers`,
  todos de `trixie-backports` y en el mismo bloque. `libgbm-dev` (dependencia de
  `libwlroots-0.20-dev`) arrastra `libgbm1` y `mesa-libgallium` de backports;
  si los drivers VA/Vulkan se quedan en la versión de trixie, apt no puede
  resolver la transacción.
- **Red:** `network-manager`, `network-manager-openvpn`, `nmcli`, `qrencode`
  (QR del hotspot).
- **Energía:** `upower`, `power-profiles-daemon`, `powerprofilesctl`.
- **Brillo:** `ddcutil` y una regla de sudoers (ver abajo).
- **Bloqueo:** `swayidle` y `hyprlock`; el script `shell-idle` los usa.
- **Teclado en pantalla:** `wvkbd` (`wvkbd-mobintl`).
- **Notificaciones/diálogos:** `libnotify-bin`, `kdialog`; `zenity` es un
  respaldo opcional que no está instalado.
- **Clima:** `curl` (consulta `wttr.in`).
- **Portales:** `xdg-desktop-portal`, `-gtk` y `-umbriel`; `-kde` está
  instalado por Plasma. **No instalar `-hyprland`** en la instalación limpia.
- **X11:** `xwayland`.

### Grupos que deben instalarse juntos

Estos paquetes tienen dependencias de versión exacta entre sí. Instalar solo
una parte desde `trixie-backports` deja el sistema en un estado que apt no
puede resolver. El instalador los trata como bloques; si haces la instalación a
mano, usa estos comandos:

```sh
sudo apt install -t trixie-backports \
  pipewire pipewire-bin pipewire-pulse wireplumber \
  libpipewire-0.3-0t64 libpipewire-0.3-modules libspa-0.2-modules

sudo apt install -t trixie-backports \
  libgbm1 mesa-libgallium libgl1-mesa-dri libglx-mesa0 libegl-mesa0 \
  mesa-va-drivers mesa-vulkan-drivers

sudo apt install -t trixie-backports \
  libpixman-1-dev libpixman-1-0 \
  libwayland-dev wayland-protocols

sudo apt install -t trixie-backports libspa-0.2-bluetooth
```

Si una instalación anterior falló a mitad, estos son los comandos de rescate
que dejan el sistema coherente:

```sh
sudo apt install -t trixie-backports \
  pipewire pipewire-bin pipewire-pulse wireplumber \
  libpipewire-0.3-modules libpipewire-0.3-0t64 libspa-0.2-modules
sudo apt install -t trixie-backports libpixman-1-dev libpixman-1-0
sudo apt install -t trixie-backports \
  mesa-va-drivers mesa-libgallium mesa-vulkan-drivers
sudo apt install cmake
sudo apt install -t trixie-backports wayland-protocols libwayland-dev
```

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
`start-umbriel`, la configuración de ejemplo y el portal. El fork del shell
sustituye solo `/usr/bin/umbriel` para añadir la barra nativa con seis botones,
icono, subtítulo y otras mejoras.

### 4.1 Dependencias de compilación

```sh
sudo apt install -t trixie-backports \
  build-essential cmake git meson ninja-build pkg-config \
  libwlroots-0.20-dev libwayland-dev wayland-protocols \
  libdrm-dev libinput-dev libxkbcommon-dev \
  libpixman-1-dev libpixman-1-0 \
  libcairo2-dev libpango1.0-dev libgdk-pixbuf-2.0-dev \
  libtomlplusplus-dev libjemalloc-dev libliftoff-dev \
  libdisplay-info-dev liblcms2-dev libsystemd-dev libudev-dev \
  libxcb1-dev libxcb-icccm4-dev libxcb-ewmh-dev \
  libxcb-randr0-dev libxcb-shape0-dev \
  libeis-dev libseat-dev nlohmann-json3-dev
```

El fork está basado en Umbriel `b6c4b7d` y tiene 24 commits propios. El parche
reproducible es `umbriel-fork.patch` (50 archivos).

`libpixman-1-dev` y `libpixman-1-0` deben instalarse juntos, igual que
`libwayland-dev` y `wayland-protocols`: las versiones de desarrollo exigen la
versión exacta de la librería de runtime.

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
git apply ~/Shell/umbriel-fork.patch
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
git diff b6c4b7d > ~/Shell/umbriel-fork.patch
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
El shell sigue funcionando con el binario estándar.

---

## 5. Instalar el shell

### 5.1 Enlazar el shell

```sh
ln -sfn ~/Shell ~/.config/quickshell/shell
```

Quickshell recarga los QML al guardar. El pragma `UseQApplication` de
`shell.qml` exige reiniciar el proceso cuando se cambia.

### 5.2 Scripts auxiliares

Copiar desde `install/bin/` a `~/.local/bin/` y dar permisos:

```sh
mkdir -p ~/.local/bin
install -m755 install/bin/shell-start ~/.local/bin/shell-start
install -m755 install/bin/shell-idle ~/.local/bin/shell-idle
install -m755 install/bin/shell-keyboard-layout ~/.local/bin/shell-keyboard-layout
install -m755 install/bin/shell-umbriel-theme ~/.local/bin/shell-umbriel-theme
install -m755 install/bin/shell-config-set ~/.local/bin/shell-config-set
install -m755 install/bin/umbriel-config-guard ~/.local/bin/umbriel-config-guard
```

- `shell-start`: exporta `QT_QPA_PLATFORMTHEME=kde` y
  `QS_ICON_THEME=breeze-dark`, y ejecuta `qs -c shell -d`. También llama al
  guardián antes de arrancar el shell.
- `shell-idle`: bloqueo con `swayidle` + `hyprlock`.
- `shell-keyboard-layout`: escribe `[input.keyboard] layout` en Umbriel.
- `shell-umbriel-theme`: sincroniza colores y acento con la barra nativa.
- `shell-config-set`: único programa que sustituye `config.toml`; aplica el
  parche, valida y hace la sustitución atómica.
- `umbriel-config-guard`: repara `config.toml` antes de Umbriel y guarda copias
  buenas y rotas.

`scripts/shell-glass` no se copia a `~/.local/bin`: el instalador lo ejecuta
para añadir las reglas de capa del cristal y el shell lo llama para cambiar el
radio de desenfoque. El escritor único sigue siendo `shell-config-set`.

### 5.3 Arranque automático

En `~/.config/umbriel/config.toml`:

```toml
[general]
autostart = ["/home/TU_USUARIO/.local/bin/shell-start"]
```

Sustituye `TU_USUARIO` por tu usuario. El instalador lo hace solo.

### 5.4 Preferencias del shell

Si se quieren conservar la disposición actual de la barra, el fondo, el clima y
los modos por escritorio:

```sh
mkdir -p ~/.config/shell
cp install/config/shell-settings.conf ~/.config/shell/settings.conf
cp install/config/shell-display.conf ~/.config/shell/display.conf
```

Revisar `wallpaperPath` (la plantilla lo deja vacío y usa un color de fondo) y
`weatherPlace` (vacío significa que se deduce por IP). No copiar `credenciales`
salvo que se sepa que hace falta: es un secreto local y el código actual no lo
usa.

`glassTransparency` (0–90, por defecto 22) y `glassBlur` (0–40, por defecto 12)
controlan el cristal. El segundo es el radio global de Umbriel y también
desenfoca las ventanas; `0` lo apaga. `glassBlurBehind` (0/1, por defecto 0)
elige entre desenfocar solo el fondo de pantalla (como el mockup) o el
contenido real que hay detrás; también está en Ajustes → Cristal.

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

### 6.1 Red de seguridad de la configuración

Todos los ajustes que escriben `config.toml` pasan por `shell-config-set`, que
serializa, valida y sustituye el archivo de forma atómica. Para que una
escritura incompleta no deje el escritorio negro, el instalador añade:

- `~/.local/bin/shell-config-set`: único programa que sustituye
  `config.toml`. Aplica parches por sección y conserva comentarios y el resto
  del archivo.
- `~/.config/umbriel/config.toml.template`: plantilla completa ya renderizada
  para el usuario.
- `~/.config/umbriel/config.toml.good`: última configuración válida con
  `autostart` activo.
- `~/.local/bin/umbriel-config-guard`: repara el archivo antes de arrancar
  Umbriel y guarda copias de las versiones rotas.
- `~/.config/systemd/user/umbriel.service.d/50-config-guard.conf`: ejecuta el
  guardián como `ExecStartPre` de `umbriel.service`.

Si instalas a mano, copia también el drop-in:

```sh
mkdir -p ~/.config/systemd/user/umbriel.service.d
cp install/systemd/umbriel-config-guard.conf \
    ~/.config/systemd/user/umbriel.service.d/50-config-guard.conf
systemctl --user daemon-reload
```

Comprobar que está activo:

```sh
~/.local/bin/shell-config-set --help
~/.local/bin/umbriel-config-guard status
systemctl --user show umbriel.service -p ExecStartPre
```

Pruebas del escritor y de los seis scripts que lo usan:

```sh
./scripts/test-config-set.sh
./scripts/test-config-writers.sh
./scripts/test-config-guard.sh
```

Si el escritorio vuelve a quedar negro, la recuperación paso a paso está en
`CONFIGURACION-UMBRIEL.md`. El resumen es: `Ctrl+Alt+F3`,
`~/.local/bin/umbriel-config-guard ensure`, validar y volver a lanzar el shell.

Si el monitor no es `HDMI-A-1`, cambiar el conector. En un portátil será
`eDP-1` o el que corresponda. **Pendiente de automatizar**: hoy hay que repetir
esa sección por conector; más adelante conviene un `shell-workspaces` que lea
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
cp install/systemd/shell-alarms.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now shell-alarms.service
```

La unidad ejecuta `%h/Shell/scripts/shell-alarms`. Comprueba
`alarms.conf` y `timer.conf` en `~/.config/shell/`.

### 7.3 Brillo por DDC/CI

`ddcutil` instala la regla udev `60-ddcutil-i2c.rules`, que da acceso al
usuario al bus I2C del monitor. Aun así, el shell llama a `sudo -n ddcutil`, así que
hace falta la regla de sudoers:

```sh
sudo install -m440 -o root -g root \
  install/sudoers/shell-ddcutil /etc/sudoers.d/shell-ddcutil
sudo visudo -cf /etc/sudoers.d/shell-ddcutil
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
# /etc/sddm.conf.d/20-autologin.conf
[Autologin]
User=username
Session=umbriel
Relogin=false
```

No es necesario para el funcionamiento normal.

### 7.5 Red, VPN, Bluetooth y energía

- `NetworkManager` gestiona Ethernet, Wi-Fi y VPN.
- `wpasupplicant` es obligatorio para el Wi-Fi: `network-manager` solo lo
  recomienda, y sin él el adaptador aparece como `unavailable` y el shell no
  puede listar ni conectar redes. `rfkill` permite comprobar si la radio está
  bloqueada.
- `dnsmasq-base` es el servidor DHCP/DNS que NetworkManager usa para el punto
  de acceso en modo compartido. Sin él, los clientes se conectan pero no
  reciben dirección IP.
- `bluez` y `bluez-obexd` aportan Bluetooth y la transferencia de archivos.
- `network-manager-openvpn` es obligatorio para importar `.ovpn`.
- `qrencode` genera el QR del punto de acceso.
- **Todos los paquetes de red, punto de acceso, VPN y Bluetooth los instala
  `scripts/network.sh`.** `install-packages.sh` ya no los duplica; la
  instalación limpia los pide una sola vez desde el módulo de red.
- Si Debian instaló la Ethernet con ifupdown (`/etc/network/interfaces`),
  NetworkManager la marca como `unmanaged`. Ejecuta una vez:
  `sudo ./scripts/network.sh`. El instalador ya lo hace salvo que uses
  `--skip-network`.
- El script también detiene los servicios `ifup@<interfaz>` y su `dhcpcd`
  heredados de la instalación. Si no se detienen, siguen configurando la
  interfaz y la Ethernet vuelve a activarse sola después de desconectarla
  desde NetworkManager.
- La vista Red solo muestra quién controla la Ethernet («NetworkManager»,
  «ifupdown», etc.). Si aparece un control heredado, vuelve a ejecutar
  `sudo ./scripts/network.sh`; no se instala ningún asistente con sudoers.
- El script reinicia Quickshell al terminar si estaba abierto, porque al
  reiniciar NetworkManager el shell puede quedarse sin ver las interfaces.
  Usa `--no-restart-shell` para evitarlo y reinícialo tú después. `install.sh`
  lo ejecuta con esa opción, ya que en una instalación limpia no hay shell
  abierto y el instalador no depende de él.
- `network-manager-openvpn` es obligatorio para importar `.ovpn`.
- `upower` y `power-profiles-daemon` para batería y perfiles.
- El hotspot usa `nmcli`, `dnsmasq-base` para el DHCP y `qrencode` para el QR.
- **Conexión por USB del móvil:** al activar «Compartir conexión por USB» en
  Android, el kernel expone una interfaz `usb0`/`enx…` que NetworkManager trata
  como Ethernet y configura por DHCP. No hace falta instalar nada más; si
  aparece como `unmanaged`, ejecuta `sudo ./scripts/network.sh`. La vista Red
  muestra todas las interfaces cableadas, cada una con su estado y su botón.
- **Redes Wi-Fi ocultas:** el engranaje general de la vista Red tiene el
  interruptor «Mostrar redes ocultas». Al activarlo, las redes que no emiten su
  SSID se mezclan con las visibles, ordenadas por conexión y señal, y se
  identifican por su BSSID/MAC. Si ya están conectadas, se muestran con su SSID
  real, que el perfil guardado ya conoce. Al pulsarlas, el formulario de SSID y
  contraseña se abre dentro de la fila. El botón **+** de la cabecera se usa
  solo para añadir una red oculta manualmente. El engranaje avanzado de cada
  red solo se muestra en la red conectada.
- **DNS global:** el centro de control tiene una ficha **DNS** propia. La vista
  permite usar el DNS automático del router o servidores IPv4/IPv6 propios y lo
  aplica a todas las conexiones Wi-Fi y Ethernet guardadas, porque
  NetworkManager no tiene un DNS único para todo el sistema. Los cambios se
  aplican con `nmcli device reapply` sin cortar la conexión.
- **Proxy por red:** el engranaje general de la vista Red permite elegir por
  conexión entre sin proxy, automático (PAC) o manual. NetworkManager solo
  admite `none`/`auto`, así que el modo manual se guarda como un PAC generado.
  Los datos editables viven en `~/.config/shell/proxy.json`. Si la red está
  activa, el proxy manual también se escribe en
  `~/.config/environment.d/90-shell-proxy.conf` para la próxima sesión.
- **Aviso de dependencias:** el icono de comprobación situado junto a
  «No molestar» ejecuta `scripts/check-deps.sh` solo al pulsarlo. Si falta algo,
  muestra una tarjeta con los paquetes y el comando para instalarlos, con un
  botón para copiar la solución. No se comprueba al arrancar ni al abrir los
  paneles.

Los perfiles de red y VPN viven en `/etc/NetworkManager/system-connections/`
(contienen secretos; copiar con permisos restringidos o reimportar).

### 7.6 Tema de apps

`shell-system-theme` necesita:

- `gsettings` (`libglib2.0-bin`)
- `kwriteconfig6` (`libkf6config-bin`)
- Breeze (`breeze`, `breeze-icon-theme`, `breeze-gtk-theme`)

`plasma-apply-colorscheme` (`plasma-workspace`) es **opcional**: si está, aplica
el acento personalizado a las apps KDE; si no, el script deja `ColorScheme` e
`Icons` en `kdeglobals` y las apps usan Breeze normal. El shell y GTK no dependen de
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

- `~/Shell/` completo, incluido `.git` si se quiere conservar la historia.
- `~/umbriel-fork/` completo, incluido `.git` si se quiere conservar la historia.
- `~/Shell/umbriel-fork.patch`.
- `/usr/bin/umbriel.stock-0.1.0` (binario original del paquete).

### 8.2 Configuración de usuario

- `~/.config/shell/`: `settings.conf`, `display.conf`, `alarms.conf`,
  `notificaciones.json`, `autoocultar`, scripts `alternar-*.sh`.
- `~/.config/shell/credenciales`: contraseña local de sudo, modo 600. No la usa
  el código actual; no incluirla en copias compartidas.
- `~/.config/umbriel/config.toml`.
- `~/.config/xdg-desktop-portal/portals.conf`.
- `~/.config/systemd/user/shell-alarms.service`.
- `~/.local/bin/shell-*`.
- `~/.config/autostart/org.kde.xwaylandvideobridge.desktop`.
- `~/.config/kdeglobals` y `~/.config/gtk-*/` si se quieren conservar; el script
  de tema los recrea.
- Tu fondo de pantalla (cópialo aparte y ajusta `wallpaperPath`).
- `~/.local/state/shell/` (historial de portapapeles y progreso; opcional).

### 8.3 Red y secretos

- `/etc/NetworkManager/system-connections/` (Wi-Fi, VPN; permisos root).
- `/etc/sudoers.d/shell-ddcutil`.
- Claves SSH/GPG y demás datos personales, fuera del alcance del shell.

### 8.4 Copia rápida

```sh
mkdir -p ~/backup-shell
tar -C "$HOME" -czf ~/backup-shell/shell-config.tar.gz \
  Shell .config/shell .config/umbriel \
  .config/xdg-desktop-portal .config/systemd/user \
  .config/autostart .local/bin
sudo tar -C / -czf ~/backup-shell/shell-system.tar.gz \
  etc/sudoers.d/shell-ddcutil \
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
   que el shell arranca antes de tocar el disco principal.
6. **Anotar la contraseña de sudo** o tenerla a mano; el instalador la pedirá
   para apt, el fork y la regla de `ddcutil`.
7. **Comprobar el disco**: no confundir la raíz Debian con las particiones
   Windows/NTFS.
8. **No ejecutar `umbriel config-replace`** sin querer: borra los layouts por
   escritorio. Si se usa, reaplicar con
   `qs ipc -c shell call windows mode <n> <modo>`.

---

## 10. Verificación después de instalar

```sh
# Shell y compositor
qs -c shell
qs ipc -c shell call windows status
umbriel config validate -c ~/.config/umbriel/config.toml
umbriel workspaces --json

# Red de seguridad de config.toml (debe mostrar la ruta expandida y ignore_errors=yes)
~/.local/bin/shell-config-set --help >/dev/null
~/.local/bin/umbriel-config-guard status
systemctl --user show umbriel.service -p ExecStartPre

# Debe haber 9 escritorios y el 9 debe poder seleccionarse
umbriel msg workspace-switch 9

# Servicios
systemctl --user status shell-alarms --no-pager
systemctl status bluetooth NetworkManager power-profiles-daemon --no-pager

# Red: la Ethernet debe estar «connected» y el Wi-Fi no «unmanaged»/«unavailable»
nmcli -t -f DEVICE,TYPE,STATE device status

# Brillo
sudo -n ddcutil detect
```

Comprobar a mano:

- Barra abajo, 9 números de escritorio; los ocupados se iluminan.
- Icono de batería visible sin batería, con rayo amarillo.
- Música: portada redondeada, título/artista, controles al pasar el ratón.
- Tráfico de red con ancho fijo.
- VPN: importar `.ovpn`, engranaje, nombre y arranque automático.
- Clima manual, alarmas y temporizador con el shell cerrado.
- Portapapeles, teclado en pantalla, bandeja del sistema.
- Brillo, atenuación extra y luz nocturna.
- Bloqueo con `Mod+Shift+L` y `shell-idle`.
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

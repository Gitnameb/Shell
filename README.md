# Shell

Shell de escritorio personal para [Umbriel](https://noctalia.dev/umbriel/)
(Wayland), escrito en QML con [Quickshell](https://quickshell.org/).

> **Proyecto personal, en desarrollo.** No es un producto ni un escritorio
> «listo para todos». Está probado en un equipo concreto (Debian 13, AMD RX 570,
> monitor HDMI-A-1) y varias funciones siguen en pruebas o pendientes. Si lo
> pruebas, hazlo en una máquina virtual o en una sesión aparte, y lee antes
> `INSTALACION.md`.
>
> El compositor es `umbriel-edit`, un **edit personal** de Umbriel para este
> equipo. No es una versión oficial ni una versión mejorada del proyecto
> original. Si alguien lo usa, que sea consciente de que está hecho para mis
> necesidades. Los detalles están en [`EDIT-PERSONAL.md`](EDIT-PERSONAL.md) y
> [`UMBRIEL-EDIT.md`](UMBRIEL-EDIT.md).

## Qué incluye

- Barra inferior con escritorios, lanzador, música, red, batería y bandeja.
- Centro de control: Wi-Fi, Bluetooth, volumen, micrófono, VPN, hotspot, modo
  avión, brillo, atenuación, luz nocturna y perfiles de energía.
- Notificaciones, historial del portapapeles, calendario, alarmas y temporizador.
- Clima, estadísticas del sistema y menú de apagado.
- Escritorios con modo por escritorio (flotante, mosaico, pila) y vista general.
- Barra de ventanas nativa de Umbriel ampliada mediante un edit personal: icono de la
  app, subtítulo y seis botones (flotar, fijar, mover, minimizar, maximizar,
  cerrar).
- Integración con portales (captura y uso compartido), tema de apps GTK/KDE y
  bloqueo de sesión con Hyprlock.
- Iniciador de sesión Noctalia Greeter (greetd). SDDM queda como respaldo.

## Estado

Es un proyecto que uso a diario en mi equipo, pero no está terminado. Lo que
falta o está en pruebas está en `PENDIENTES.md`. Lo más relevante:

- La captura y el uso compartido desde aplicaciones X11/Firefox no están
  verificados de principio a fin.
- Wi-Fi y Bluetooth funcionan, pero algunos flujos (hotspot, olvidar redes,
  emparejamiento) no se han probado en todo tipo de hardware.
- La instalación está automatizada con `./install.sh`, pero todavía no se ha
  probado de principio a fin en un Debian recién instalado.
- El número de escritorios está fijado por conector (`HDMI-A-1` en este equipo).

## Requisitos

- Debian 13 «trixie» (probablemente funciona en otras distribuciones con
  Wayland, pero no está probado).
- Umbriel y su portal, desde el repositorio de Noctalia.
- Noctalia Greeter y `greetd` como iniciador de sesión.
- Quickshell, PipeWire, Mesa y Hyprlock desde `trixie-backports`.
- Qt 6, KDE/Breeze, NetworkManager (con `wpasupplicant`), BlueZ,
  UPower y Polkit.
- Para el brillo: `ddcutil` y una regla de sudoers.
- Para el edit de Umbriel: las dependencias de compilación de `meson`.

La lista completa, por capas, está en `install/packages.txt`.

## Instalación

La vía recomendada es el instalador incluido:

```sh
git clone git@github.com:Gitnameb/Shell.git ~/Shell
cd ~/Shell
./install.sh --dry-run   # muestra lo que hará, sin tocar nada
./install.sh             # instala y compila
```

El instalador añade los repositorios, instala los paquetes, copia la
configuración de usuario, crea la regla de sudoers, activa las alarmas y compila
el edit de Umbriel. **No sobrescribe configuraciones existentes** salvo que se
use `--force-config`; en ese caso guarda una copia `.bak`.

`install.sh` es el punto de entrada y delega en módulos que también puedes
ejecutar por separado:

```sh
./scripts/install-packages.sh --dry-run    # repositorios y paquetes (instala el Umbriel oficial; después hay que reinstalar el edit)
./scripts/install-steam-libs.sh --dry-run  # librerías de 32 bits para Steam
./scripts/network.sh --dry-run             # red, Wi-Fi, hotspot, VPN y Bluetooth
./scripts/install-user-config.sh --dry-run # enlaces y configuración del HOME
./scripts/install-greeter.sh --dry-run     # Noctalia Greeter y greetd
./scripts/install-umbriel-edit.sh --dry-run # Umbriel propio (edit personal)
```

`scripts/network.sh` instala y configura NetworkManager, Wi-Fi, hotspot, VPN y
Bluetooth. `install.sh` lo ejecuta sin reiniciar el shell; si lo lanzas a mano,
puedes usar `--no-restart-shell` para controlar tú el reinicio.

Opciones útiles:

- `--dry-run`: enseña los comandos sin ejecutarlos.
- `--skip-packages`: solo configura y compila.
- `--skip-steam`: no instala las librerías de 32 bits de Steam.
- `--skip-edit`: no toca el compositor.
- `--skip-disks`: no añade los discos internos NTFS a `/etc/fstab`.
- `--skip-network`: no configura la red ni instala NetworkManager, Wi-Fi,
  hotspot, VPN ni Bluetooth.
- `--skip-greeter`: no cambia el iniciador de sesión; deja SDDM.
- `--with-firmware`: instala también firmware y drivers de este equipo.
- `--help`: lista todas las opciones.

La guía manual, con el detalle de cada paso, sigue estando en
**[`INSTALACION.md`](INSTALACION.md)**.

> En los archivos de `install/` la ruta `/home/USUARIO` es un marcador: el
> instalador la sustituye por tu HOME real.

### Configuración inicial y fondo de pantalla

Una instalación nueva parte de la configuración de este equipo: barra, orden
de iconos, tamaños, acento, cristal, ventanas, escritorios y fondo. Las
plantillas están en `install/config/`.

El fondo elegido se copia a:

```text
~/.local/share/shell/wallpapers/
```

La copia es la que usa el shell. Si borras la imagen original de Descargas, el
fondo sigue funcionando. Al elegir otra imagen desde Ajustes, el shell la copia
al mismo directorio como `current.<ext>` y actualiza la configuración. El
instalador también migra un `wallpaperPath` antiguo que apunte fuera de ese
directorio.

Noctalia Greeter recibe una copia aparte en
`/var/lib/noctalia-greeter/wallpaper.<ext>`, porque `_greetd` no puede leer
dentro de un HOME privado.

## Estructura

| Ruta | Contenido |
| --- | --- |
| `shell.qml` | Entrada del shell e IPC. |
| `Bar*.qml` | Barra y sus widgets. |
| `*State.qml` | Estado y procesos de cada integración. |
| `*Panel.qml`, `*View.qml` | Paneles y vistas. |
| `scripts/` | Ayudantes de portapapeles, alarmas, tema, VPN, etc. |
| `icons/` | Iconos SVG propios. |
| `install/` | Plantillas para una instalación limpia. |
| `install.sh` | Instalador principal para Debian 13 + Umbriel. |
| `scripts/install-packages.sh` | Módulo de repositorios, paquetes y servicios. |
| `scripts/install-steam-libs.sh` | Habilita i386 e instala las librerías de 32 bits de Steam. |
| `scripts/network.sh` | Módulo de NetworkManager, Ethernet y Wi-Fi. |
| `scripts/install-user-config.sh` | Módulo de enlaces, configuración del HOME y terminal de Thunar. |
| `scripts/install-greeter.sh` | Configura Noctalia Greeter y cambia de SDDM a greetd. |
| `scripts/install-umbriel-edit.sh` | Compila e instala el edit personal de Umbriel. |
| `install/wallpapers/default.png` | Fondo de pantalla por defecto. |
| `umbriel-edit.patch` | Parche del edit de Umbriel sobre `b6c4b7d`. |
| `EDIT-PERSONAL.md` | Qué es este proyecto personal y cuáles son sus límites. |
| `UMBRIEL-EDIT.md` | Qué es el edit de Umbriel, cómo publicarlo y protegerlo de `apt`. |
| `INSTALACION.md` | Guía de instalación. |
| `PLAN.md`, `PENDIENTES.md`, `CONTEXTO.md` | Plan, tareas e historial. |

## Edit personal de Umbriel

El compositor propio vive en un repositorio independiente:

```text
https://github.com/Gitnameb/umbriel-edit
```

No es un fork de GitHub ni una versión oficial. Es una copia modificada para
este escritorio, con historia propia y sin relación de pull request con
`noctalia-dev/umbriel`.

`umbriel-edit.patch` se conserva como respaldo reproducible: se aplica sobre
Umbriel `b6c4b7d` y añade la barra de ventanas ampliada y el resto de cambios.
Si el clon del edit falla, el instalador usa ese parche.

El binario oficial se aparta con `dpkg-divert`, así que `apt upgrade` no
debería sustituir el edit. Los detalles están en `UMBRIEL-EDIT.md`.

## Licencia

El shell se distribuye bajo **GNU GPL v3.0** (ver [`LICENSE`](LICENSE)). Si
distribuyes una versión modificada, tiene que seguir siendo GPL-3.0 y con el
código disponible.

Umbriel es MIT; el parche de `umbriel-edit.patch` conserva esa licencia y su
aviso de copyright. El shell no incluye binarios de `wl-clipboard`: el
instalador usa el paquete del sistema.

## Créditos

- [Umbriel](https://noctalia.dev/umbriel/), el compositor.
- [Quickshell](https://quickshell.org/), el framework QML.
- [Noctalia](https://noctalia.dev/), el proyecto del que sale Umbriel.
- [Noctalia Greeter](https://github.com/noctalia-dev/noctalia-greeter), el iniciador de sesión.
- Breeze y el resto de KDE por los iconos y el tema base.
- Varios iconos SVG están inspirados en [Lucide](https://lucide.dev/) (ISC).

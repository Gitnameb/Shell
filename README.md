# Shell

Shell de escritorio personal para [Umbriel](https://noctalia.dev/umbriel/)
(Wayland), escrito en QML con [Quickshell](https://quickshell.org/).

> **Proyecto personal, en desarrollo.** No es un producto ni un escritorio
> «listo para todos». Está probado en un equipo concreto (Debian 13, AMD RX 570,
> monitor HDMI-A-1) y varias funciones siguen en pruebas o pendientes. Si lo
> pruebas, hazlo en una máquina virtual o en una sesión aparte, y lee antes
> `INSTALACION.md`.

## Qué incluye

- Barra inferior con escritorios, lanzador, música, red, batería y bandeja.
- Centro de control: Wi-Fi, Bluetooth, volumen, micrófono, VPN, hotspot, modo
  avión, brillo, atenuación, luz nocturna y perfiles de energía.
- Notificaciones, historial del portapapeles, calendario, alarmas y temporizador.
- Clima, estadísticas del sistema y menú de apagado.
- Escritorios con modo por escritorio (flotante, mosaico, pila) y vista general.
- Barra de ventanas nativa de Umbriel ampliada mediante un fork: icono de la
  app, subtítulo y seis botones (flotar, fijar, mover, minimizar, maximizar,
  cerrar).
- Integración con portales (captura y uso compartido), tema de apps GTK/KDE y
  bloqueo de sesión.

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
- Quickshell, PipeWire y Mesa desde `trixie-backports`.
- Qt 6, KDE/Breeze, NetworkManager (con `wpasupplicant`), BlueZ,
  UPower y Polkit.
- Para el brillo: `ddcutil` y una regla de sudoers.
- Para el fork de Umbriel: las dependencias de compilación de `meson`.

La lista completa, por capas, está en `install/packages.txt`.

### Modo ligero

El instalador **no instala `plasma-workspace` ni el escritorio Plasma**. Solo
instala las librerías y herramientas de KDE que el shell necesita (`plasma-integration`,
Breeze, `kdialog`, `kwriteconfig6` y SDDM). Las apps KDE seguirán usando Breeze
claro/oscuro, pero no heredarán el acento personalizado del shell; eso queda como
mejora pendiente. El shell, Umbriel y las apps GTK no dependen de Plasma.

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
el fork de Umbriel. **No sobrescribe configuraciones existentes** salvo que se
use `--force-config`; en ese caso guarda una copia `.bak`.

`install.sh` es el punto de entrada y delega en módulos que también puedes
ejecutar por separado:

```sh
./scripts/install-packages.sh --dry-run   # repositorios y paquetes (instala el Umbriel oficial; después hay que reinstalar el fork)
./scripts/network.sh --dry-run            # red, Wi-Fi, hotspot, VPN y Bluetooth
./scripts/install-user-config.sh --dry-run # enlaces y configuración del HOME
./scripts/install-umbriel-fork.sh --dry-run # compositor parcheado
```

`scripts/network.sh` reinicia Quickshell al terminar si estaba abierto, para
que vuelva a enumerar las interfaces después de reiniciar NetworkManager. Usa
`--no-restart-shell` si prefieres reiniciarlo tú. El instalador `install.sh`
lo ejecuta con esa opción: en una Debian limpia no hay shell abierto y la
instalación no debe depender de que exista. El script instala también
`dnsmasq-base` (DHCP del punto de acceso), `libspa-0.2-bluetooth` (audio
Bluetooth), `qrencode` (QR del hotspot),
`bluez`/`bluez-obexd` (Bluetooth) y `network-manager-openvpn` (VPN), además
de `wpasupplicant` y `rfkill`. También detiene los servicios
`ifup@<interfaz>` y `dhcpcd` heredados de Debian, que si no se
detienen pueden volver a activar la Ethernet después de desconectarla. La
vista Red solo muestra quién controla la Ethernet; si vuelve a activarse sola,
se ejecuta otra vez `sudo ./scripts/network.sh`.

Opciones útiles:

- `--dry-run`: enseña los comandos sin ejecutarlos.
- `--skip-packages`: solo configura y compila.
- `--skip-fork`: no toca el compositor.
- `--skip-network`: no configura la red ni instala NetworkManager, Wi-Fi,
  hotspot, VPN ni Bluetooth.
- `--with-firmware`: instala también firmware y drivers de este equipo.
- `--help`: lista todas las opciones.

La guía manual, con el detalle de cada paso, sigue estando en
**[`INSTALACION.md`](INSTALACION.md)**.

> En los archivos de `install/` la ruta `/home/USUARIO` es un marcador: el
> instalador la sustituye por tu HOME real.

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
| `scripts/network.sh` | Módulo de NetworkManager, Ethernet y Wi-Fi. |
| `scripts/install-user-config.sh` | Módulo de enlaces y configuración del HOME. |
| `scripts/install-umbriel-fork.sh` | Compila e instala el fork de Umbriel. |
| `umbriel-fork.patch` | Parche del fork de Umbriel sobre `b6c4b7d`. |
| `FORK-UMBRIEL.md` | Cómo publicar el fork en GitHub y protegerlo de `apt`. |
| `INSTALACION.md` | Guía de instalación. |
| `PLAN.md`, `PENDIENTES.md`, `CONTEXTO.md` | Plan, tareas e historial. |

## Fork de Umbriel

`umbriel-fork.patch` se aplica sobre Umbriel `b6c4b7d` y añade la barra de
ventanas ampliada. El resto del shell funciona con el Umbriel estándar, pero sin
esa barra nativa.

Si actualizas Umbriel con `apt`, el binario del fork puede quedar reemplazado.
En ese caso hay que recompilarlo o restaurar la copia. Los detalles están en
`INSTALACION.md`.

## Licencia

El shell se distribuye bajo **GNU GPL v3.0** (ver [`LICENSE`](LICENSE)). Si
distribuyes una versión modificada, tiene que seguir siendo GPL-3.0 y con el
código disponible.

Umbriel es MIT; el parche de `umbriel-fork.patch` conserva esa licencia y su
aviso de copyright. El shell no incluye binarios de `wl-clipboard`: el
instalador usa el paquete del sistema.

## Créditos

- [Umbriel](https://noctalia.dev/umbriel/), el compositor.
- [Quickshell](https://quickshell.org/), el framework QML.
- [Noctalia](https://noctalia.dev/), el proyecto del que sale Umbriel.
- Breeze y el resto de KDE por los iconos y el tema base.
- Varios iconos SVG están inspirados en [Lucide](https://lucide.dev/) (ISC).

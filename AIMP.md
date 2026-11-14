# AIMP para Linux en Umbriel

AIMP tiene una versión nativa para Linux que funciona en Umbriel, pero no
arranca tal cual: comprueba el nombre del escritorio y, si no está en su lista,
muestra este diálogo y se cierra:

```text
App can not be run on UMBRIEL on WAYLAND.
Please, refer to the requirements list.
```

Este documento explica la causa, qué se cambia para evitarlo y cómo repetirlo
en otro equipo. Todo lo necesario está en
[`scripts/aimp-umbriel.sh`](scripts/aimp-umbriel.sh).

Probado con AIMP **6.00.3095 Beta 7** en Debian 13 con Umbriel (Wayland).

## La causa

AIMP lee `XDG_CURRENT_DESKTOP` al arrancar y solo acepta estos escritorios:

```text
GNOME, KDE, Cinnamon, Mate, Fly, XFCE
```

`XDG_SESSION_TYPE` solo aparece en el mensaje (`WAYLAND`); no es lo que
rechaza. En una sesión de Umbriel las variables son:

```text
XDG_CURRENT_DESKTOP=umbriel
XDG_SESSION_TYPE=wayland
XDG_SESSION_DESKTOP=umbriel
```

No falta ninguna biblioteca. El proceso llega a cargar BASS, los plugins y
MPRIS; lo único que falla es esa comprobación.

## La solución

Son tres piezas, y ninguna cambia la sesión:

1. **Lanzadores** que presentan `GNOME` solo al proceso de AIMP.
2. **Entradas de menú** propias que apuntan a esos lanzadores.
3. **Exclusión del render fijo** para que AIMP se redimensione como una ventana
   normal.

### 1. Lanzadores por proceso

El lanzador de AIMP es un script pequeño:

```sh
#!/bin/sh
XDG_CURRENT_DESKTOP=GNOME exec /opt/aimp/AIMP "$@"
```

Se crean tres, porque el conversor y el editor de etiquetas hacen la misma
comprobación:

| Lanzador | Binario |
| --- | --- |
| `~/.local/bin/aimp` | `/opt/aimp/AIMP` |
| `~/.local/bin/aimpac` | `/opt/aimp/AIMPac` |
| `~/.local/bin/aimpate` | `/opt/aimp/AIMPate` |

Detalles:

- La variable va delante del comando, así que solo la heredan AIMP y sus
  procesos hijos. No se exporta a la sesión.
- `exec` sustituye al shell: no queda un proceso extra y los argumentos
  (`-playpause`, una ruta, etc.) pasan tal cual.
- Se elige GNOME, no KDE o XFCE, porque AIMP es una aplicación GTK3 y GNOME es
  la referencia de GTK3.

Comprobación con AIMP abierto:

```sh
tr '\0' '\n' < /proc/$(pgrep -x AIMP)/environ | grep XDG_CURRENT_DESKTOP
# XDG_CURRENT_DESKTOP=GNOME
```

Y en el log propio de AIMP:

```text
D/Core: GUI: GNOME on WAYLAND
```

El resto de la sesión sigue viendo `umbriel`:

```sh
echo "$XDG_CURRENT_DESKTOP"   # umbriel
```

### 2. Entradas de menú

El `.desktop` del sistema (`/usr/share/applications/aimp.desktop`) usa
`Exec=aimp %U`, que encontraría el lanzador por `PATH`, pero sus acciones
llaman directamente a los binarios:

```ini
Exec=/opt/aimp/AIMPac
Exec=/opt/aimp/AIMPate
```

Por eso el script copia las tres entradas a
`~/.local/share/applications/` y reescribe todas las líneas `Exec` para que
usen los lanzadores de `~/.local/bin`. La copia de usuario tiene prioridad
sobre la del sistema, así que también sobrevive a una actualización del paquete.

El script añade `X-AIMP-Umbriel-Managed=true` a las copias. Esa marca le
permite saber qué archivos puede sustituir o borrar sin tocar nada tuyo.

### 3. Exclusión del render fijo

AIMP declara un tamaño mínimo de **1018x626**. El piloto de render fijo de
Umbriel detecta ventanas que «no se dejan redimensionar» y las escala en el
mosaico; con AIMP eso hacía que la ventana se viera como si no se pudiera
redimensionar.

La solución es excluirlo en `~/.config/umbriel/config.toml`:

```toml
[general]
fixed_render_exclude = ["aimp"]
```

- La comparación no distingue mayúsculas, así que cubre `Aimp`, `AIMP` y
  `aimp` (el app id cambia según cómo se lance).
- Se puede combinar con otros nombres:
  `fixed_render_exclude = ["vlc", "mpv", "aimp"]`.
- La clave existe en el edit de Umbriel a partir del commit `3642ef7`. En un
  Umbriel anterior la configuración no valida y hay que usar
  `--no-exclude`.

No se usa una regla de ventana flotante: AIMP debe seguir comportándose como
una ventana normal dentro del mosaico.

## El script

```sh
cd ~/Shell
./scripts/aimp-umbriel.sh --dry-run   # enseña lo que haría
./scripts/aimp-umbriel.sh             # lo aplica
./scripts/aimp-umbriel.sh --remove    # lo deshace
```

Opciones:

| Opción | Qué hace |
| --- | --- |
| `--dry-run` | Muestra los comandos y el diff de la configuración, sin tocar nada. |
| `--remove` | Quita lanzadores, entradas de menú y la exclusión. No desinstala AIMP. |
| `--force` | Sustituye o borra archivos que no creó el script. |
| `--no-exclude` | No modifica la configuración de Umbriel. |
| `-h`, `--help` | Ayuda. |

El script:

- No instala AIMP ni ejecuta `sudo`.
- No cambia variables de la sesión.
- Es idempotente: ejecutarlo dos veces no duplica nada.
- Conserva el resto de la configuración de Umbriel y el resto de exclusiones.
- Valida la configuración resultante con `umbriel config validate` antes de
  escribirla. Si falla, deja el archivo como estaba.

Variables de entorno, por si AIMP está en otra ruta:

| Variable | Valor por defecto |
| --- | --- |
| `AIMP_DIR` | `/opt/aimp` |
| `BIN_DIR` | `~/.local/bin` |
| `APPS_DIR` | `~/.local/share/applications` |
| `UMBRIEL_CONFIG` | `~/.config/umbriel/config.toml` |

## Qué toca

| Ruta | Contenido |
| --- | --- |
| `~/.local/bin/aimp`, `aimpac`, `aimpate` | Lanzadores con `XDG_CURRENT_DESKTOP=GNOME`. |
| `~/.local/share/applications/aimp.desktop` | Entrada principal y acciones del menú. |
| `~/.local/share/applications/aimpac.desktop` | Conversor de audio. |
| `~/.local/share/applications/aimpate.desktop` | Editor de etiquetas. |
| `~/.config/umbriel/config.toml` | `general.fixed_render_exclude`. |

Nada de esto está en `install.sh`: es un extra opcional. Quien no use AIMP no
necesita ejecutarlo.

## Audio

AIMP reproduce por **ALSA directo**, no a través de PipeWire. En este equipo
abre el DAC USB (`CX31993`) como `card0` y lo deja en `RUNNING` mientras suena:

```sh
cat /proc/asound/card0/pcm0p/sub0/status
# state: RUNNING
# owner_pid: <pid de AIMP>
```

Consecuencias:

- Suena, pero el volumen del escritorio y Easy Effects no lo controlan.
- Hay que usar el volumen propio de AIMP.
- Si otro programa tiene el dispositivo ocupado en exclusiva, AIMP puede no
  arrancar la reproducción.

No se enruta ALSA por PipeWire porque eso afectaría a todas las aplicaciones
que usan ALSA, no solo a AIMP. Si se necesita, es un cambio aparte y consciente
en `~/.asoundrc`.

## Tamaño mínimo y mosaico

AIMP pide 1018x626. El layout respeta ese mínimo, así que en un escritorio con
muchas ventanas la columna puede sobresalir por el borde derecho. Si pasa:

- flota la ventana con la tecla de flotar (en este escritorio, `Mod+T`), o
- ábrela en un escritorio con menos ventanas.

No se añade una regla de flotado automática para no cambiar el comportamiento
del mosaico.

## Deshacer

Lo más sencillo:

```sh
./scripts/aimp-umbriel.sh --remove
```

Si los archivos no los creó el script, `--remove` avisa y no los toca; con
`--force` los borra igualmente.

A mano sería:

```sh
rm ~/.local/bin/aimp ~/.local/bin/aimpac ~/.local/bin/aimpate
rm ~/.local/share/applications/aimp.desktop \
   ~/.local/share/applications/aimpac.desktop \
   ~/.local/share/applications/aimpate.desktop
update-desktop-database ~/.local/share/applications
```

y quitar `"aimp"` de `fixed_render_exclude` en
`~/.config/umbriel/config.toml`.

## Problemas frecuentes

**Sigue saliendo el diálogo.** Se está ejecutando `/opt/aimp/AIMP` directamente
en vez del lanzador. Comprueba `command -v aimp` y que apunta a
`~/.local/bin/aimp`. Algunos lanzadores externos guardan la ruta absoluta al
binario; cámbialos al lanzador.

**`configuration invalid` al añadir la exclusión.** El Umbriel instalado no
conoce `fixed_render_exclude` (versión anterior a `3642ef7`). Actualiza el edit
o repite con `--no-exclude`; AIMP funcionará igual, solo se queda el
comportamiento del render fijo.

**El menú muestra dos AIMP.** No debería: la entrada de
`~/.local/share/applications` sustituye a la del sistema con el mismo nombre de
archivo. Si pasa, ejecuta `update-desktop-database ~/.local/share/applications`
y vuelve a abrir el menú.

**No suena.** Comprueba el dispositivo elegido en AIMP y el estado de ALSA:

```sh
cat /proc/asound/cards
cat /proc/asound/card*/pcm*p/sub*/status
```

**El app id aparece como `Aimp` o `AIMP`.** Es normal. La exclusión no
distingue mayúsculas y el lanzador funciona igual.

## Licencia

El script forma parte de este repositorio y se distribuye bajo GPL-3.0, igual
que el resto del shell. AIMP es software de terceros y no se incluye aquí.

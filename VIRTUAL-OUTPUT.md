# Salida virtual y capturas

Umbriel puede crear una pantalla que no existe físicamente (una salida
*headless*) y usarla para jugar o compartir pantalla sin enseñar el monitor
real. `virtual-output` gestiona esa pantalla; **Steam Link es solo un preset**
encima de la misma herramienta.

## Por qué

El portal de escritorio (`xdg-desktop-portal`) entrega a las aplicaciones la
captura que piden: un monitor o una ventana. Si Steam Link pide «el monitor»,
lo normal es que capture `HDMI-A-1`, donde están el escritorio y las ventanas
personales. La salida virtual evita eso: los juegos y Big Picture viven en una
pantalla aparte, y mientras el modo está activo el portal solo ofrece esa
pantalla a las capturas.

## Uso

```sh
virtual-output on                       # salida genérica 1920x1080@60
virtual-output on --mode 2560x1080@60   # otra resolución
virtual-output on --name tele --mode 1920x864@60
virtual-output off
virtual-output toggle

virtual-output mode 1920x864@60         # cambia la resolución sin salir del modo
virtual-output status                   # «activa» o «inactiva»
virtual-output info                     # active=, name=, mode=, preset=, physical=
virtual-output presets
```

Presets:

| Preset      | Resolución   | Qué añade                                                       |
| ----------- | ------------ | --------------------------------------------------------------- |
| `steamlink` | 1920x864@60  | 20:9, juegos de Steam/Proton y Big Picture a la salida virtual.  |
| `none`      | 1920x1080@60 | Pantalla genérica, sin reglas de ventana.                        |

El preset de Steam Link conserva su nombre y su atajo:

```sh
steamlink-mode on       # equivale a virtual-output on --preset steamlink
steamlink-mode off
steamlink-mode toggle
steamlink-mode status
steamlink-mode info
steamlink-mode mode 2560x1080@60
```

Atajo: `Mod+Shift+F11`. También se puede activar desde la ficha **Steam Link**
del centro de control o desde la barra.

### Resolución

La resolución se guarda en `~/.config/umbriel/virtual-output.state` y se
reutiliza en el siguiente `on`. Para fijar una preferencia permanente, crea
`~/.config/umbriel/virtual-output.conf`:

```sh
# ~/.config/umbriel/virtual-output.conf (se lee como shell)
name=steamlink
mode=2560x1080@60
capture_apps=steam
# physical=HDMI-A-1        # solo si la detección automática falla
```

Con el preset de Steam Link también vale una variable puntual:

```sh
STEAMLINK_MODE=2560x1080@60 steamlink-mode on
```

Cambiar la resolución con una partida abierta destruye y recrea la pantalla
virtual: el juego y Big Picture vuelven al monitor físico. Vuelve a abrirlos
después del cambio.

## Cómo se garantiza que no se capture el monitor físico

Hay tres capas, todas en espacio de usuario:

1. **Reglas de ventana.** El include generado
   (`~/.config/umbriel/virtual-output.toml`) manda los juegos y Big Picture a la
   salida virtual y la marca como primaria de X11. Al desactivar el modo, el
   include queda vacío y los juegos vuelven a abrirse con normalidad.
2. **Selector de fuentes del portal.** Mientras hay una salida virtual activa,
   `virtual-output-chooser` responde al portal con esa salida y marca la
   captura como dinámica. Si la salida ya no existe, cancela la captura en
   lugar de caer al monitor físico. Sin salida virtual delega en el selector
   normal (`/usr/libexec/umbriel-share-picker`). Se configura en
   `~/.config/xdg-desktop-portal-umbriel/config.toml`.
3. **Datos de restauración.** El portal recuerda la última fuente de cada
   aplicación y la restaura sin preguntar. `virtual-output-restore` reescribe
   solo las selecciones de tipo monitor de las apps del preset (Steam, por
   defecto) para que apunten a la salida virtual y sean dinámicas. Hace copia
   de seguridad en `~/.local/state/umbriel/screencast-restore.bak` antes de
   escribir. Así una instalación que ya tenía «monitor físico» guardado se
   corrige al activar el modo.

Durante una emisión activa, `virtual-output` también llama a
`screencast-set-output` para redirigir la captura en caliente.

## Uso simultáneo con el monitor físico

Hoy la salida virtual separa el **render**, pero no la **entrada**: Umbriel
tiene un único *seat* (`seat0`) y el teclado, el ratón y la captura comparten
foco global. Mientras el invitado juega, si el usuario hace clic en el monitor
físico, el juego pierde el foco y deja de responder; si el invitado usa el
ratón táctil, mueve el cursor del usuario. La transmisión no se corta: los
fotogramas siguen llegando, pero la ventana pierde el control.

**Un segundo *seat* no resuelve el caso de Steam/Proton.** Xwayland crea
dispositivos esclavos por cada `wl_seat`, pero `EnableDevice` los engancha
siempre al único *master* del servidor X (`inputInfo.keyboard` /
`inputInfo.pointer`, véase `dix/devices.c`). El foco de teclado de X11 es
global, así que un segundo seat aislaría clientes Wayland nativos, no los
juegos de Proton.

La vía que sí aísla es una **sesión de invitado propia**: un segundo Umbriel
*headless* con su propio Xwayland y su propio seat, Steam dentro de esa sesión
y el portal de esa sesión para capturarla. Así la entrada del móvil nunca toca
la sesión del usuario. La herramienta `steamlink-guest` lo implementa:

```sh
steamlink-guest              # sesión 1920x864@60 y Big Picture
steamlink-guest --take-over  # cierra el Steam del escritorio y arranca
steamlink-guest status       # sesión, salida, display y modo
steamlink-guest stop         # cierra Steam, el portal y el compositor
```

La sesión usa un bus D-Bus privado, su propio `xdg-desktop-portal` y un
`XDG_CONFIG_HOME` temporal con `virtual-output-chooser` apuntando a la salida
`HEADLESS-1`. La captura de Steam sale de esa salida; la entrada de Steam
(XTest → Xwayland → libei) se queda en el seat del invitado. Validado: el
compositor arranca con aceleración real (AMD RX 570, Mesa 26.1.6), su Xwayland
funciona, `grim` captura 1920x864 y el portal entrega un nodo PipeWire de
`HEADLESS-1` a 1920x864 con `mapping_id`, `position` y `size` correctos.

Variables: `STEAMLINK_GUEST_MODE` (resolución), `STEAMLINK_GUEST_STEAM_ARGS`
(por defecto `-pipewire -tenfoot`). Los registros quedan en
`$XDG_RUNTIME_DIR/steamlink-guest/`; `steamlink-guest logs` los muestra.
`--app "comando"` sustituye a Steam para probar la sesión.

Límite del diseño: Steam solo admite una instancia por usuario, así que
mientras el invitado juega, Steam no puede estar abierto en la sesión del
usuario. El resto del escritorio (navegador, terminal, archivos) sigue
disponible. Para tener Steam en los dos monitores a la vez haría falta una
máquina virtual o un segundo equipo.

## Limitaciones

- Las capturas de **ventana** no se fuerzan: el selector normal sigue
  ofreciendo ventanas, porque compartir una ventana concreta no expone el
  escritorio.
- La entrada (teclado, ratón y mando) sigue siendo global: usar el monitor
  físico quita el foco al juego del invitado y el ratón táctil mueve el cursor
  del usuario. Para uso simultáneo, usa `steamlink-guest`, que arranca Steam en
  una sesión aparte con su propio seat.
- Cambiar la resolución no recoloca las ventanas que ya estaban abiertas; hay
  que reabrir el juego.
- Solo se gestiona una salida virtual a la vez. Activar otro preset retira la
  anterior.
- Si otra herramienta cambia la fuente desde el selector mientras el modo está
  activo, la siguiente captura vuelve a la salida virtual; los datos de
  restauración se reparan al activar el modo.

## Archivos

| Archivo | Función |
| ------- | ------- |
| `install/bin/virtual-output` | Crea, retira y redimensiona la salida virtual. |
| `install/bin/steamlink-mode` | Preset de Steam Link sobre `virtual-output`. |
| `install/bin/steamlink-guest` | Sesión aislada (compositor, Xwayland, portal y Steam) para jugar a la vez que se usa el monitor. |
| `install/bin/virtual-output-chooser` | Selector del portal: fuerza la salida virtual. |
| `install/bin/virtual-output-restore` | Repara los datos de restauración del portal. |
| `install/config/xdg-desktop-portal-umbriel.toml` | Plantilla del `chooser_cmd`. |
| `~/.config/umbriel/virtual-output.toml` | Include generado con reglas y tamaño. |
| `~/.config/umbriel/virtual-output.state` | Último nombre, resolución y preset. |

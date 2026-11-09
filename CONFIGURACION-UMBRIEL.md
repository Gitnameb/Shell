# Configuración de Umbriel y el shell

Este documento explica por qué `~/.config/umbriel/config.toml` es un archivo
delicado, qué se hizo para que no vuelva a dejar el escritorio negro y cómo se
centralizaron todas las escrituras en un único programa.

## 1. La regla que no se puede romper

Umbriel lee `~/.config/umbriel/config.toml` al arrancar. El shell no lo lanza
Umbriel por sí solo: lo lanza la clave `autostart` de la sección `[general]`.

```toml
[general]
autostart = ["/home/username/.local/bin/shell-start"]
```

Si el archivo pierde esa clave, Umbriel arranca correctamente pero **nunca
ejecuta Quickshell**. El resultado es una pantalla negra con el compositor
vivo: hay salida de vídeo, pero no barra, ni paneles, ni escritorio.

Por tanto, la invariante es:

> `config.toml` debe ser un TOML completo, válido y con
> `[general] autostart` apuntando al arranque del shell.

`autostart = []` sí es válido: es una decisión explícita de no lanzar el shell
desde Umbriel. El guardián respeta la clave vacía y solo repara la **ausencia**
de la clave.

## 2. Quién escribe el archivo

Varios componentes calculan ajustes durante el arranque, pero ya no escriben el
archivo por su cuenta: todos llaman a `shell-config-set`, el escritor único.

| Componente | Qué cambia | Cómo escribe |
| --- | --- | --- |
| `scripts/shell-mod-hold` | `[input] mod_hold_delay_ms` | `shell-config-set` |
| `scripts/shell-floating-defaults` | `[layout.stacking]` | `shell-config-set` |
| `scripts/shell-window-chrome` | `[appearance.title_bar] overlay` | `shell-config-set` |
| `scripts/shell-display-filter` | `[display]` | `shell-config-set` |
| `scripts/shell-glass` | `[[layer_rule]]`, `[[window_rule]]` y `[appearance.blur]` | `shell-config-set` |
| `install/bin/shell-keyboard-layout` | `[input.keyboard] layout` | `shell-config-set` |
| `install/bin/shell-umbriel-theme` | `[colors]`, `[colors.border]`, `[colors.title_bar]` y el tono de `[appearance.blur]` | `shell-config-set` |
| `install/bin/shell-config-set` | Cualquier clave de esas secciones | Python, `flock` + `tomllib` + validación + `os.replace` |
| `install/config/umbriel-config.toml` | Plantilla completa | Copia del instalador |

Todos comparten el mismo cerrojo:

```text
~/.config/umbriel/config.toml.shell-lock
```

El cerrojo debe ser el mismo en todos. Un escritor nuevo que use otro nombre de
lock no está protegido. La diferencia ahora es que solo `shell-config-set`
sustituye el archivo; los demás solo calculan valores y le pasan un parche.

## 3. Qué pasó el 2026-11-06

1. Al iniciar sesión, el shell lanzó varios ajustes a la vez.
2. Dos o más scripts escribían `config.toml` sin coordinarse.
3. Uno de ellos movió al archivo final un contenido parcial: quedaron 18
   líneas con solo `[display]`, `[appearance.title_bar]`, `[input.keyboard]`,
   `[layout.stacking]` e `[input]`.
4. Desaparecieron `[general]`, `[keybinds]`, `[layout]`, `[colors]`,
   `[output."HDMI-A-1"]` y, sobre todo, `autostart`.
5. Umbriel arrancó; Quickshell no.
6. El escritorio quedó negro.

El archivo truncado se conservó en:

```text
~/.config/umbriel/config.toml.truncado-20261106
```

La configuración se restauró desde `install/config/umbriel-config.toml`. Esa
restauración devolvió a valores de instalación los ajustes que no estaban en
las 18 líneas: atajos, colores, reglas de ventana y la sección del monitor.
El tema de colores lo vuelve a sincronizar el shell; los atajos y reglas hay
que revisarlos si se habían personalizado.

## 4. Por qué `umbriel config validate` no basta

Un TOML de 18 líneas puede ser sintácticamente válido. `config validate` dice
«ok» porque el archivo se puede leer, aunque le falte lo esencial para que el
shell arranque.

Por eso el guardián comprueba dos cosas además de la validación:

1. Que exista la clave `autostart` en `[general]`.
2. Que no se hayan perdido la mayoría de las secciones respecto a la última
   copia buena.

## 5. Defensas implementadas

### 5.1 Escritor único y escritura atómica

Todas las escrituras pasan por `shell-config-set`. El escritor:

- toma `flock` sobre `config.toml.shell-lock`;
- lee el archivo y aplica solo las claves del parche, conservando comentarios,
  orden y claves desconocidas;
- escribe el resultado en un temporal único del mismo directorio;
- valida el temporal con `tomllib` y con `umbriel config validate`;
- si algo falla, borra el temporal y deja el original intacto;
- si todo es válido, hace `os.replace` atómico y conserva el modo del archivo.

Los scripts del shell ya no abren `config.toml` para escribir: calculan sus
valores y llaman al escritor. `shell-glass` hace lo mismo con las reglas de
capa y el bloque de cristal. Si un proceso muere a mitad de la operación, el
archivo original sigue intacto.

### 5.2 Copia buena y plantilla

Junto al archivo conviven tres referencias:

| Archivo | Origen | Para qué |
| --- | --- | --- |
| `config.toml.good` | Guardián o instalador | Última configuración válida con autostart activo |
| `config.toml.template` | Instalador | Plantilla completa ya renderizada para este usuario |
| `config.toml.broken-AAAAmmdd-HHMMSS` | Guardián | Copia forense del archivo roto |

El guardián **no** guarda como buena una configuración sin autostart activo.
Así una copia buena nunca sirve para restaurar otra pantalla negra.

### 5.3 Guardián antes de Umbriel

`install/bin/umbriel-config-guard` se instala en
`~/.local/bin/umbriel-config-guard` y tiene tres modos:

```sh
umbriel-config-guard ensure   # repara antes de arrancar Umbriel
umbriel-config-guard save     # guarda la configuración actual como buena
umbriel-config-guard status   # muestra el estado sin tocar nada
```

El instalador añade un drop-in de systemd de usuario:

```text
~/.config/systemd/user/umbriel.service.d/50-config-guard.conf
```

con:

```ini
[Service]
ExecStartPre=-%h/.local/bin/umbriel-config-guard ensure
```

El guion inicial (`-`) es importante: si el guardián falla, Umbriel arranca
igual. El guardián nunca debe ser un nuevo motivo de pantalla negra.

Flujo de `ensure`:

1. Toma el mismo `flock` que los escritores.
2. Si el archivo no existe, está mal formado o perdió `autostart`, lo trata
   como roto.
3. Guarda una copia `config.toml.broken-*`.
4. Restaura `config.toml.good`; si no sirve, `config.toml.template`.
5. Valida el resultado.
6. Registra todo en `~/.local/state/shell/config-guard.log`.

### 5.4 Segunda capa en el arranque del shell

`install/bin/shell-start` también llama a `ensure` antes de `qs`. Es una segunda
capa para el caso de lanzar el shell a mano. Además, 15 segundos después del
arranque lanza `save` en segundo plano, cuando los ajustes de inicio ya
terminaron de escribirse.

La primera capa (systemd) es la que cubre el caso realmente peligroso: que
Umbriel no llegue a lanzar `shell-start` porque falta `autostart`. La segunda
capa no puede arreglar ese caso por sí sola, porque nunca se ejecutaría.

### 5.5 Instalador

`scripts/install-user-config.sh` ahora:

- instala `umbriel-config-guard`;
- renderiza `config.toml.template` con el HOME real;
- crea o actualiza `config.toml.good`;
- instala el drop-in de systemd;
- recarga systemd de usuario.

`--dry-run` muestra los pasos sin escribir nada.

## 6. Archivos y registro

```text
~/.config/umbriel/config.toml
~/.config/umbriel/config.toml.shell-lock
~/.config/umbriel/config.toml.good
~/.config/umbriel/config.toml.template
~/.config/umbriel/config.toml.broken-*
~/.config/systemd/user/umbriel.service.d/50-config-guard.conf
~/.local/bin/shell-config-set
~/.local/bin/umbriel-config-guard
~/.local/state/shell/config-guard.log
~/.local/state/shell/config-writer.log
```

Para ver el estado:

```sh
~/.local/bin/umbriel-config-guard status
systemctl --user cat umbriel.service
systemctl --user show umbriel.service -p ExecStartPre
```

## 7. Recuperación paso a paso si vuelve a quedar negro

1. Cambia a una terminal: `Ctrl+Alt+F3`.
2. Comprueba que Umbriel está vivo pero Quickshell no:

   ```sh
   systemctl --user status umbriel.service
   pgrep -a -f 'qs -c shell'
   ```

3. Mira el estado del archivo:

   ```sh
   ~/.local/bin/umbriel-config-guard status
   ```

4. Intenta la reparación automática:

   ```sh
   ~/.local/bin/umbriel-config-guard ensure
   ```

5. Si no hay copia buena ni plantilla, restaura desde el repositorio:

   ```sh
   sed "s|/home/USUARIO|$HOME|g" \
       ~/Shell/install/config/umbriel-config.toml \
       > ~/.config/umbriel/config.toml
   umbriel config validate -c ~/.config/umbriel/config.toml
   ```

6. Arranca el shell en la sesión viva de Umbriel:

   ```sh
   export XDG_RUNTIME_DIR="/run/user/$(id -u)"
   export WAYLAND_DISPLAY=wayland-0
   export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
   ~/.local/bin/shell-start >/tmp/shell-start.log 2>&1 &
   ```

7. Vuelve a la sesión gráfica:

   ```sh
   loginctl activate 3   # o el número de sesión de tty1
   ```

8. Si hiciste la restauración desde la plantilla, revisa atajos, colores,
   reglas de ventana y `[output."HDMI-A-1"]`.

## 8. Comprobaciones

### Concurrencia

Se probaron ocho procesos concurrentes, cinco rondas, ejecutando los siete
scripts y el guardián. El archivo conservó todas sus líneas, todas las
secciones y `autostart`, y siguió validando. El escritor solo hizo 22 sustituciones
reales; el resto fueron `unchanged` y no tocaron el archivo.

### Escritor único

```sh
./scripts/test-config-set.sh       # 48 comprobaciones
./scripts/test-config-writers.sh   # 48 comprobaciones
./scripts/test-glass-rules.sh      # 21 comprobaciones
```

`test-config-set.sh` cubre actualización de claves, idempotencia, varias
secciones en una llamada, valores TOML inválidos, claves desconocidas, claves y
secciones que faltan, bloques de tablas, conservación del modo y concurrencia.

`test-config-writers.sh` ejecuta los siete scripts migrados contra una copia
temporal y comprueba que escriben lo esperado, que solo piden recarga cuando
hay cambios y que el archivo conserva comentarios, `autostart` y todas sus
líneas.

### Guardián

Se probaron ocho escenarios con copias temporales:

1. configuración válida: no toca nada y actualiza `.good`;
2. archivo real truncado de 18 líneas: restaura desde `.good` y guarda
   `.broken-*`;
3. configuración ausente: la recrea desde `.good`;
4. `autostart = []` intencional: no la toca ni la guarda como buena;
5. TOML inválido: restaura desde `.good`;
6. sin `.good`: restaura desde `.template`;
7. sin `.good` ni `.template`: no rompe, deja el archivo y devuelve error;
8. plantilla sin renderizar (`/home/USUARIO`): la rechaza.

Las pruebas viven en `scripts/test-config-guard.sh` y no tocan la configuración
real: trabajan con copias en un directorio temporal. Ejecutar:

```sh
./scripts/test-config-guard.sh
```

Resultado esperado: 23 comprobaciones OK y 0 fallos.

### systemd

```sh
systemd-analyze --user verify umbriel.service
systemctl --user show umbriel.service -p ExecStartPre
```

Debe aparecer la ruta expandida a `/home/username/.local/bin/umbriel-config-guard`
y `ignore_errors=yes`.

## 9. El escritor único

Ya está implementado. `install/bin/shell-config-set` es el único programa que
sustituye `config.toml`; los scripts que antes escribían por su cuenta son
ahora envoltorios finos que calculan valores y le pasan un parche.

### 9.1 Interfaz

```sh
shell-config-set --section display brightness=0.900 extra_dim=0.100 warm=0.000
shell-config-set --section input.keyboard 'layout="es"'
shell-config-set \
    --section colors background='"#141519FF"' \
    --section colors.border focused='"#8ab4f8FF"'
```

- `--section` puede repetirse para tocar varias tablas en una sola escritura.
- Cada `clave=valor` se aplica a la sección anterior.
- `--append-block FILE` añade un bloque literal al final (por ejemplo, tablas
  `[[layer_rule]]`).
- `--drop-block BEGIN END` borra el tramo entre dos líneas marcadoras. Con
  `--drop-block` y `--append-block` en la misma llamada se sustituye un bloque
  gestionado de forma atómica, como hace `shell-glass`.
- Los valores son TOML en crudo: números sin comillas, cadenas entre comillas y
  `true`/`false`.
- La salida es `changed` o `unchanged`. Los scripts solo piden
  `umbriel msg config-reload` cuando la salida es `changed`.

### 9.2 Comportamiento

1. Toma `flock` sobre `config.toml.shell-lock`.
2. Lee el archivo y aplica solo las claves pedidas, conservando comentarios,
   orden, espacios y claves desconocidas.
3. Si una clave falta en una sección existente, la añade al final de esa
   sección. Si falta la sección, la crea.
4. Escribe en un temporal único del mismo directorio y conserva el modo.
5. Valida con `tomllib` y con `umbriel config validate`.
6. Si algo falla, borra el temporal y deja el original intacto.
7. Si todo es válido, hace `os.replace` atómico.
8. Registra el cambio en `~/.local/state/shell/config-writer.log`.

La validación semántica de Umbriel rechaza claves desconocidas. Eso es
deliberado: si una versión nueva del shell intenta escribir una clave que el
compositor instalado no entiende, el archivo no se toca y el error queda
visible.

### 9.3 Migración

| Script | Parche que envía |
| --- | --- |
| `shell-mod-hold` | `[input] mod_hold_delay_ms` |
| `shell-floating-defaults` | `[layout.stacking]` |
| `shell-animation-speed` | `[animation] speed` |
| `shell-window-chrome` | `[appearance.title_bar] overlay` |
| `shell-display-filter` | `[display]` |
| `shell-keyboard-layout` | `[input.keyboard] layout` |
| `shell-umbriel-theme` | `[colors]`, `[colors.border]`, `[colors.title_bar]`, tono de `[appearance.blur]` |
| `shell-glass` | `[[layer_rule]]`, `[[window_rule]]` y `[appearance.blur]` |

Las llamadas desde QML no cambiaron. Los scripts conservan su interfaz y sus
validaciones de argumentos; lo único que cambió es que ya no abren el archivo
para escribir.

### 9.4 Criterios de aceptación

Verificados:

- Ocho escritores concurrentes durante cinco rondas: el archivo siempre valida
  y conserva todas las secciones y `autostart`.
- Prueba de estrés: 40 escritores, 13 de ellos terminados con `kill -9`; el
  archivo quedó válido, con todas sus líneas, `autostart` y sin temporales
  huérfanos.
- Un valor TOML inválido no modifica el archivo.
- Una clave que Umbriel no conoce no modifica el archivo.
- Una clave conocida que faltaba se añade y valida.
- Una sección conocida que faltaba se crea y valida.
- El modo del archivo se conserva.
- Los siete scripts escriben lo esperado y solo recargan cuando hay cambios.
- La sustitución es `os.replace` sobre un temporal ya validado; un corte antes
  del reemplazo deja el original intacto.
- El guardián `ensure` sigue siendo la última red de seguridad.

### 9.5 Límites

- Para añadir una clave nueva hay que actualizar primero la plantilla y el
  esquema de Umbriel; el escritor no puede inventar claves.
- Los valores deben ser TOML válido. Las cadenas tienen que ir entre comillas.
- Si `umbriel` no está disponible, el escritor aún valida la sintaxis con
  `tomllib`, pero no la semántica del compositor.

## 10. Reglas para cambios futuros

- No abrir `config.toml` para escribir. Usar siempre `shell-config-set`.
- No volver a implementar `flock`/`mktemp` en cada script.
- Pasar valores TOML en crudo; las cadenas, entre comillas.
- No confiar solo en `umbriel config validate`: comprobar también
  `[general] autostart`.
- No guardar como `.good` una configuración sin autostart activo.
- No cambiar el nombre del lock sin cambiar todos los escritores.
- Probar con `./scripts/test-config-set.sh`,
  `./scripts/test-config-writers.sh` y `./scripts/test-glass-rules.sh` antes de
  dar un cambio por terminado.
- Si se toca el instalador, ejecutar `./scripts/install-user-config.sh
  --dry-run` antes de probar en limpio.

## 11. Cristal y desenfoque

El shell dibuja superficies transparentes, pero Umbriel solo las desenfoca si
una regla de capa coincide con su namespace. Las reglas viven en
`config.toml` y las administra `scripts/shell-glass`:

```sh
./scripts/shell-glass ensure                 # añade o actualiza las reglas
./scripts/shell-glass apply 16 simple 20 12 fondo
./scripts/shell-glass mode simple            # contenido real que hay detrás
./scripts/shell-glass mode fondo             # solo fondo de pantalla
./scripts/shell-glass blur 16                # radio del shell; 0 lo apaga
./scripts/shell-glass windows 20 12 simple   # ventanas: 20 %, 12 px, simple
./scripts/shell-glass tone dark              # brillo/contraste del modo oscuro
./scripts/shell-glass tone light             # brillo/contraste del modo claro
./scripts/shell-glass status
```

`apply` es el comando que usa el centro de control: recibe el radio y el tipo
del shell y el porcentaje, radio y tipo de las ventanas, y escribe los dos
bloques y el radio global en una sola operación atómica.

Bloque que se añade (idempotente, marcado con `# shell-glass: inicio`):

```toml
[[layer_rule]]
match.namespace = "^shell-(bar|side-panel|launcher|calendar|battery|tray|power|app-menu|osd|welcome-mode|notification-popup)$"
blur = true
blur_popups = true
blur_ignore_alpha = 0.04
blur_optimized = true
blur_strength = 1.0000

[[layer_rule]]
match.namespace = "^shell-(wallpaper|desktop-icons|outside-close|filter)$"
blur = false
```

- `blur_optimized = true` muestrea la caché del fondo de pantalla, así que el
  cristal nunca desenfoca las ventanas que haya detrás: es el modo «Fondo» del
  centro de control. Con `blur_optimized = false` Umbriel desenfoca el
  contenido real: es el modo «Simple». El valor se guarda como
  `glassBlurBehind` y se elige con el selector segmentado, con el mismo estilo
  que el de tema.
- `blur_ignore_alpha = 0.04` usa el alpha de la propia superficie como
  máscara: descarta los píxeles transparentes de las esquinas redondeadas y
  evita que el desenfoque asome fuera del panel. Debe quedar por debajo del
  alpha mínimo del cristal (0.10 con transparencia 90 %).
- `shell-glass` sustituye el bloque entero entre sus dos marcadores mediante
  `shell-config-set --drop-block`, sin tocar el resto del archivo.
- `shell-wallpaper`, `shell-desktop-icons`, `shell-outside-close` y
  `shell-filter` se excluyen: son superficies transparentes a pantalla
  completa (o el velo de luz nocturna) y no deben crear una región de blur.
- Umbriel solo tiene un radio **global** en `[appearance.blur] radius`. Para
  que el shell y las ventanas tengan radios distintos, `shell-glass` escribe
  el mayor de los dos en el radio global y reparte un `blur_strength` (0–1)
  por regla: así cada bloque conserva su propio radio efectivo. Por defecto
  son 16 px para el shell, 12 px para las ventanas y 3 pasadas.
- La transparencia (`glassTransparency`, 0–90) solo cambia el alpha del shell:
  `alpha = (100 - transparencia) / 100`. Por defecto 22 → 0.78.
- **Tono del desenfoque.** Umbriel aplica `brightness`, `contrast` y
  `saturation` de `[appearance.blur]`. El shell los escribe desde
  `~/.config/shell/glass-blur.conf` al cambiar de modo; en oscuro baja el
  brillo y en claro lo sube. Se puede afinar ese archivo y ejecutar
  `shell-glass tone dark|light` sin recompilar nada.
- **Shell y ventanas por separado.** La vista Temas divide el cristal en
  «Shell» y «Cristal de ventanas». Cada bloque tiene su transparencia, su
  radio y su selector «Simple / Fondo». «Sincronizar con el shell», dentro de
  Cristal de ventanas, copia en vivo la transparencia y el tipo del shell;
  mientras está activo, los controles de ventanas quedan bloqueados. Los
  valores propios se conservan y vuelven al desactivar la sincronización.
- **Ventanas transparentes.** Se aplica un `[[window_rule]]` global con
  `opacity` (desde `windowTransparency`, 0–90), `blur` y `blur_optimized`.
  Desenfoca el contenido que queda detrás de la ventana, no el contenido
  propio de la app. Con 0 % el bloque `# shell-windows` se elimina y las
  ventanas vuelven a ser opacas. El comando es
  `qs ipc -c shell call appearance windows 20 12 simple` (porcentaje, radio y
  tipo).
- Pruebas: `./scripts/test-glass-rules.sh` y
  `./scripts/test-config-writers.sh`.

### 11.1 Desenfoque al mantener Super

Umbriel incorpora un shader de ventana que se activa mientras se mantiene Mod
y el puntero está sobre una ventana. Desenfoca **solo el contenido del
cliente** (1.4 px y una desaturación suave, como el mockup) y añade un velo del
10 %; la barra de título nativa y sus botones no se tocan. No depende de
`[appearance.blur]`: es independiente del radio global del cristal.

El estado vive en el compositor (`View::setModHover` y
`Server::updateModHoverBlur`). Al soltar Mod o salir de la ventana, el slot de
efecto vuelve al preset configurado para esa ventana, si lo había. El parche
`umbriel-fork.patch` incluye el shader; para verlo hay que instalar el binario
nuevo y reiniciar la sesión.

Además, mantener Mod es un modo de **enfoque**: la ventana bajo el puntero
pasa a ser la que recibe el teclado, aunque antes tuviera el foco otra. Así
`Super+Q`, `Super+M` o `Super+Shift+H` actúan sobre la ventana que se está
señalando y no sobre la última enfocada. Al mover el puntero con Mod pulsado,
el foco cambia con él, incluso cuando el puntero está sobre la barra de título
nativa o sus iconos de opciones y no sobre el contenido. Mantener Mod también
cuenta como interactuar fuera de un panel del shell: el panel se cierra en
cuanto se activa el gesto, aunque la ventana señalada ya tuviera el foco
lógico, y se vuelve a reafirmar el foco aunque el puntero no haya cambiado de
ventana.

## 12. Calendario simple

El panel del reloj mantiene cuatro pestañas: **Calendario**, Clima, Alarmas y
Temporizador. La pestaña Calendario pinta el mes, marca con puntos los días
que tienen notas y debajo lista las notas del día elegido. La fecha larga que
antes aparecía al pie («viernes, 6 de noviembre de 2026») se eliminó.

- Archivo: `~/.config/shell/calendar-notes.conf`, una línea por nota con el
  formato `id|AAAA-MM-DD|texto`.
- El editor de nota no vive entre los días. El primer clic elige el día; el
  segundo clic sobre ese mismo día abre un apartado aparte, como las opciones
  avanzadas de los demás controles, con la fecha y el campo de nota. La nota
  se guarda con Intro o con el botón +; Escape, la × o un clic fuera lo
  cierran. Las notas existentes se borran con la × de la lista del día.
- `scripts/shell-calendar` administra el archivo (`list`, `note add`,
  `note remove`) y solo usa la biblioteca estándar. `CalendarEvents.qml` le
  pide el mes visible al abrir el panel o cambiar de mes.
- Cuando el día no tiene nada, el calendario no muestra ningún texto vacío:
  solo la lista de días y, si hay contenido, sus notas y eventos.
- Las notas son **locales**. No se sincronizan con Google ni con otros
  dispositivos: no hay integración iCal, cuentas ni claves externas.
- Pruebas: `./scripts/test-calendar.sh` (20 comprobaciones).

## 13. Clima

Los iconos del clima son SVG propios en `icons/weather-*.svg` y llevan el
color incorporado: sol amarillo, nubes grises, lluvia azul, nieve celeste y
rayo amarillo sobre nube oscura. Se pintan con `ShellIcon` y `tint: false`
para no teñirlos de un solo color. `WeatherState.iconFor` reparte los códigos
de wttr.in entre claro, pocas nubes, nubes, niebla, chubascos, lluvia, tormenta
y nieve.

## 14. Alarmas y temporizador

- `DurationField.qml` es el mismo editor para los dos. Se pulsa el tiempo y se
  escriben dígitos de derecha a izquierda, con los dos puntos automáticos y sin
  escribirlos nunca. Mientras se escribe se ven los dígitos tal cual y la
  conversión no se aplica hasta pulsar Intro o salir del campo; retroceso borra
  el último dígito y Escape cancela.
  - Temporizador (`showSeconds: true`): `123` → `1:23`, `12345` → `1:23:45`.
  - Alarma (`showSeconds: false`): `930` → `09:30`, `1230` → `12:30`.
- La edición se confirma al pulsar Intro, al tocar cualquier otra zona del
  panel, al cambiar de pestaña o al cerrar el panel. No hace falta apretar
  Intro para que el valor quede guardado.
- Editar el tiempo del temporizador detiene la cuenta atrás y lo deja listo.
  Un tiempo escrito a mano deselecciona los presets aunque coincida con uno.
- `AlarmState.qml` reproduce el sonido de alarma o del temporizador en bucle y
  muestra un aviso crítico sin caducidad. El sonido solo para al cerrar ese
  aviso o al pulsar el reloj de la barra (que además retira el aviso). El
  reproductor (`pw-play` o `paplay`) es el proceso directo, así que se corta al
  instante: no hay un bucle de shell esperando a que acabe la secuencia.
  Mientras suena, el fondo del reloj parpadea en azul. Si «No molestar» está
  activo no hay aviso registrado, así que el sonido se detiene al abrir el
  calendario. Hay un límite de seguridad de 10 minutos.
- Con el shell cerrado, `scripts/shell-alarms` usa `notify-send -w` (o un
  diálogo de KDialog/Zenity) y mantiene el sonido hasta que se cierra el aviso.

## 15. Bloqueo de pantalla

`shell-lock` es el **único** bloqueo del shell. El botón «Bloquear» del menú de
energía, `Mod+Shift+L` y el bloqueo automático de `shell-idle` pasan todos por
él. El ayudante crea `~/.config/hypr/hyprlock.conf` a partir de la plantilla
del repositorio si todavía no existe y lanza `hyprlock`, que dibuja la
superficie `ext-session-lock-v1`; Quickshell no puede crearla por sí mismo.
No hay respaldos con otros bloqueadores ni llamadas directas a `hyprlock`.

Antes el botón lanzaba `hyprlock` directamente y, sin archivo de
configuración, hyprlock salía sin bloquear. Ahora la configuración se crea
sola y el instalador también la copia en limpieza.

## 16. Teclado

La distribución del teclado físico se configura **solo** desde el centro de
control → Teclado, junto al interruptor del teclado flotante. La fila
«Distribución del teclado» que había en Ajustes se eliminó.

- Idiomas disponibles: español (`es`), inglés (`us`), ruso (`ru`),
  portugués (`pt`), chino (`cn`) y alemán (`de`). Cualquier otro valor se
  rechaza; si el archivo guardado tiene un valor inválido (por ejemplo
  `mosaic`), se migra a `es` al arrancar.
- El teclado flotante usa `wvkbd-mobintl`. La lista de idiomas cambia la capa
  de wvkbd: ruso carga la capa cirílica y el resto la QWERTY internacional con
  acentos. Al cambiar la distribución se reinicia solo si está visible.
- **Límite actual:** wvkbd no tiene capas nativas para español, alemán,
  portugués ni chino. Para esos idiomas el teclado flotante es la QWERTY
  internacional; el chino además necesita un método de entrada (IME). Si se
  quiere un teclado flotante con teclas nativas o estilo Android habría que
  sustituir wvkbd por un teclado propio; no se hace en este cambio.

## 17. Rendimiento

El consumo en reposo se midió con el shell dentro de Umbriel anidado, sin
paneles abiertos: **7,4 % → 0,6 % de CPU** de `qs`. Con el centro de control
abierto bajó de **12,4 % → 1,0 %**. El RSS pasó de unos 355 MB a 324 MB.

Cambios que lo explican:

- **Batería.** En un equipo de sobremesa `mains` es siempre verdadero. El
  barrido del contorno estaba atado a `charging || mains`, así que era una
  animación infinita a 60 fps permanente. Ahora el barrido solo corre con
  `charging`; el rayo sigue visible como indicador de corriente.
- **Wi-Fi.** Los dos indicadores de «buscando redes» giraban también cuando
  `hasScanned` era falso o `scanning` se quedaba atascado. Ahora solo giran
  con `scanning`, hay un vigilante de 12 s que corta la consulta y `nmcli`
  lleva `timeout=8`/`--wait` para no colgarse para siempre.
- **Ventanas y escritorios.** `UmbrielBackend` usaba dos procesos
  (`umbriel windows --json` y `umbriel workspaces --json`) cada 600 ms e
  invalidaba todas las fichas de la barra aunque nada cambiara. Ahora usa
  `umbriel subscribe workspaces,windows`; los procesos manuales solo quedan
  para el diagnóstico.
- **Centro de control.** Sus más de 7000 líneas de QML se cargan con un
  `Loader` la primera vez que se abre el panel, no al arrancar. Después se
  conserva para que abrir y cerrar sea instantáneo.
- **Iconos.** `ShellIcon` usa `MultiEffect` en lugar de `ColorOverlay` y ya no
  carga dos veces el mismo SVG. Esto elimina la dependencia
  `qml6-module-qt5compat-graphicaleffects`.
- **Sonido.** `pw-play` (PipeWire) es el reproductor principal; ya no hace
  falta `pulseaudio-utils`. `paplay` sigue como respaldo si existe.

### Dependencias ligeras por defecto

Estas sustituciones ya están aplicadas en el instalador:

| Antes | Tamaño | Ahora | Tamaño |
| --- | --- | --- | --- |
| `kitty` | ~23 MB | `foot` | ~0,7 MB |
| `fonts-inter` | ~21 MB | `fonts-inter-variable` | ~1,7 MB |

- `Mod+Return` y los lanzadores usan `foot`. No acepta `-e`: la forma correcta
  es `foot comando`, y así se construyen las órdenes.
- `Theme.fontFamily` es `Inter Variable`. Comprobado en Qt 6.8: la familia
  existe, el peso Bold se resuelve como estilo real y no como negrita
  sintética.
- El cursor de la sesión ya era Adwaita (`gsettings`). `breeze-cursor-theme`
  sigue instalado porque `plasma-integration` → `breeze` lo exige; quitarlo de
  la lista no ahorra espacio real.

## 18. Acciones propias de las apps

Al pulsar con el botón derecho sobre el icono de una app en la barra, el menú
muestra primero las acciones que declara su archivo `.desktop` en la clave
`Actions=`. Por ejemplo, Brave aporta «New Window» y «New Incognito Window»;
Thunar aporta «Home», «Computer» y «Trash».

- La fuente es `DesktopEntry.actions` de Quickshell. No hay que leer archivos a
  mano ni instalar nada extra.
- El escaneo de entradas es asíncrono. `DesktopActions.qml` lo arranca al
  inicio del shell, guarda un contador de revisión y vuelve a resolver las
  acciones cuando termina.
- `AppContextMenu.qml` dibuja esas acciones antes de las de ventana, que
  salen de `WindowActions.qml`. `AppMenuItem.qml` acepta iconos de tema, rutas
  completas y un atajo compacto a la derecha.
- Si una app no declara `Actions=`, no aparece la sección. Eso depende del
  `.desktop` de la app, no del shell.
- Iconos de las acciones: primero se usa el `Icon=` que declare el bloque
  `[Desktop Action ...]`. Muchas apps no lo rellenan (Brave, por ejemplo), así
  que `DesktopActions.iconFor()` lo deduce del id o del nombre con iconos del
  tema: `view-private` (sombrero y gafas) para incógnito, `window-new`,
  `tab-new`, `go-home`, `user-trash`, `computer` y `settings-configure`. Si el
  tema no tiene ninguno, queda el glifo `▸`.
- Las acciones con icono de archivo (`Icon=/ruta/icono.svg`) se dibujan a color;
  las del tema se tiñen como el resto del menú.

### Acciones de ventana del clic derecho

Las opciones de ventana del menú y las de la barra de título salen de la misma
lista, `WindowActions.qml`. Así no pueden desincronizarse: mismo orden, mismas
etiquetas, mismos iconos y mismos atajos. El orden imita los botones nativos
(volumen, flotar, fijar, pantalla completa, mover, minimizar, maximizar y
cerrar).

- Se eliminó «Enfocar ventana»; para eso ya sirve pulsar la ficha de la app.
- La opción de flotar solo aparece cuando puede hacer algo. En un escritorio
  en modo flotante Umbriel rechaza `window-toggle-floating`, así que se oculta.
  En mosaico la etiqueta cambia a «Hacer flotante»; el icono es el mismo
  `window-float.svg` de dos ventanas superpuestas que dibuja la barra nativa.
- Maximizar cambia entre «Maximizar» y «Restaurar tamaño»; minimizar entre
  «Minimizar» y «Restaurar ventana». Los dos usan los SVG equivalentes a la
  barra nativa (`window-maximize.svg` y `window-minimize.svg`), también en el
  estado restaurado. En pantalla completa se ocultan flotar y maximizar, pero
  aparece «Salir de pantalla completa» con el mismo icono de cuatro esquinas.
- Maximizar usa `window-toggle-maximize-to-edges`, no
  `window-toggle-maximize`. En mosaico, la segunda acción solo ensanchaba la
  columna y dejaba una franja de la ventana vecina al lado; la primera ocupa
  toda el área útil y funciona igual en flotante. `Mod+M` también apunta a la
  acción de bordes.
- Cerrar usa el mismo aspa que la barra nativa (`window-close.svg`) y mover el
  mismo `#` (`window-move.svg`). Fijar y volumen conservan los iconos del menú
  (`window-pin`/`window-unpin` y `volume-3`/`volume-off`).
- «Fijar siempre encima» viene de la barra de título y cambia a «Dejar de
  fijar» con el icono `window-unpin` cuando la ventana ya está fijada.
- «Mover a escritorio» muestra los nueve botones solo al pulsar la fila; por
  defecto el menú abre con esa lista plegada.
- El altavoz de la barra de título nativa abre una tarjeta de volumen para esa
  ventana. Controla el flujo de PipeWire de la app: el altavoz silencia y el
  deslizador ajusta el nivel. Si no hay audio activo, la tarjeta lo indica y
  deja el control desactivado. Se identifica por el PID de la ventana y, si
  falta, por el id o el nombre de la aplicación. El menú del icono de la app
  conserva la misma opción.
- Cada opción lleva un icono de teclado a la derecha (`ShortcutKey.qml`). Al
  pasar el ratón por ese icono aparece un tooltip con el atajo: `Super+T`
  flotar, `Super+P` fijar, `Super+Shift+1…9` mover, `Super+Shift+H` minimizar,
  `Super+M` maximizar, `Super+F` pantalla completa y `Super+Q` cerrar. El
  icono no es configurable al pulsarlo: editar atajos desde ahí obligaría a
  escribir y recargar la configuración de Umbriel, con más riesgo que
  beneficio. El atajo de minimizar se añadió a `[keybinds]` como
  `"Mod+Shift+H" = "window-minimize"`.

### Redimensionar e intercambiar ventanas

Con Super mantenido (o con el pin de «Mostrar con Super»), Umbriel dibuja los
indicadores **dentro del árbol de cada ventana** (`NativeHandles`):

- una banda de 14 px centrada en el hueco entre cada par de mosaicos vecinos,
  con una línea de 2 px en el centro y un margen del 7 % en los extremos como
  en el mockup;
- cuatro puntos en las esquinas de la ventana flotante **enfocada**, unos
  píxeles hacia dentro para que queden sobre el borde redondeado.

Al ser nodos de escena de la propia ventana, se mueven y redimensionan con ella
en el mismo frame, no capturan clics y quedan cubiertos por una ventana
flotante que pase por encima. El shell no superpone ninguna capa. La
manipulación la sigue haciendo Umbriel. En el fork:

- En mosaico **solo redimensiona la línea entre ventanas**. La banda activa
  es el hueco más dos píxeles por lado, centrada en la línea; los bordes
  exteriores de una ventana no redimensionan. En un cruce de cuatro ventanas
  se elige el eje más cercano, como en el mockup.
- En una ventana flotante, las cuatro esquinas tienen una zona de 24 px
  alrededor del punto y los bordes una franja fina de 6 px. El resto de la
  ventana sigue moviendo. El cursor muestra la doble flecha en la línea y en
  los agarres.
- Un arrastre con Mod y botón izquierdo sobre el contenido de un mosaico
  **intercambia** esa ventana con la que quede debajo: la origen se atenúa, la
  destino se resalta y al soltar cambian de sitio. Un clic sin arrastrar solo
  enfoca.
- El movimiento nativo de mosaicos pasa al botón derecho. Si el clic derecho
  empieza sobre un borde compartido, redimensiona ese reparto; si empieza en el
  contenido, mueve la ventana como antes.
- En una ventana flotante, el botón derecho sigue redimensionando.

Si una ventana flotante tapa un divisor, su propia escena queda por encima y
la línea no se dibuja sobre el contenido. El pin del shell se conserva con
`umbriel overlay-pin on|off|toggle`, que muestra los controles sin activar el
escudo de entrada de Mod. Probado con un puntero virtual en una sesión
anidada: el borde compartido redimensionó desde ambos lados, los indicadores
siguieron a la ventana durante el arrastre y el redimensionado, y el centro
izquierdo intercambió las dos ventanas mientras el derecho las reubicó.

### Cambiar entre mosaico y ventana

Al pasar un escritorio de mosaico a ventana, cada ventana vuelve a la última
posición y tamaño que tenía en modo ventana si ya había flotado antes. Solo
las que nunca flotaron usan el tamaño por defecto y entran en la cascada. Una
ventana nueva en modo ventana recibe ese tamaño en el configure inicial, así
que su primera imagen ya sale a tamaño definitivo y no se redimensiona unos
instantes después. El tamaño flotante queda anotado en cuanto empieza la
flotación, antes de que la app lo confirme: cambiar de modo varias veces
seguidas ya no toma el tamaño del mosaico como si fuera el de ventana.

### Barra de título nativa

La barra que dibuja Umbriel comparte la misma lista de acciones. En
`[appearance.title_bar] buttons` se añadió `"fullscreen"`:

```toml
buttons = ["volume", "float", "pin", "fullscreen", "move", "minimize", "maximize", "close"]
```

- El botón de pantalla completa va después de fijar y antes de mover, igual
  que en el menú del clic derecho. Usa el icono de cuatro esquinas
  (`comple.webp` de la referencia); maximizar usa un marco cuadrado más grande
  con esquinas interiores (`maxi.webp`) y flotar, dos ventanas superpuestas sin
  la línea interior que parecía una barra de título (`ventana.webp`). Los
  iconos se dibujan en `src/scene/title_bar_icon.cpp`; en el shell hay SVG
  equivalentes en `icons/window-*.svg`.
- Se eliminó el subtítulo de la derecha («app · escritorio»). El nombre de la
  app ya está a la izquierda y el escritorio se deduce por la barra y las
  fichas.
- El botón de flotar se sigue ocultando en escritorios flotantes y el de
  fijar en ventanas en mosaico. Pantalla completa se muestra siempre.

### Cierre de paneles

`Bar.qml` tiene una capa transparente a pantalla completa que cierra paneles,
calendario, energía, batería, bandeja y el menú de apps al pulsar fuera. La
franja de la barra queda libre para que sus controles sigan funcionando, pero
un clic en el fondo de la barra, en una ficha de escritorio o en una app
también cierra el panel abierto. Pulsar el mismo control lo alterna. Además,
enfocar una ventana o mantener Super cierra cualquier panel abierto: el shell
escucha el estado real de Mod y retira sus capas antes de aplicar el enfoque
por hover.

## 19. Orden de las fichas de la barra

El backend devuelve las ventanas en orden de apilado, que cambia al enfocar.
Para que los iconos no bailen, `CompositorState.windowsForWorkspace()` conserva
el orden en que apareció cada ventana:

- `windowOrder` guarda un número por dirección de ventana. La primera vez que
  se ve una ventana recibe el siguiente número; después se ordena por ese
  número, no por la lista del compositor.
- Las ventanas nuevas se añaden al final. Una ventana cerrada se olvida y, si
  se vuelve a abrir, entra como nueva.
- Las minimizadas conservan su número porque siguen en la lista con su
  escritorio de origen.
- El orden es el mismo en todas las píldoras: primero se numera la lista
  completa y después cada escritorio filtra las suyas.

## 20. Limpieza de dependencias

Además de `foot` e `Inter Variable`:

- Se eliminaron los binarios locales de `wl-clipboard` (`scripts/bin/`). El
  instalador ya instala `wl-clipboard` y los scripts usan `wl-paste`/`wl-copy`
  del sistema.
- Se eliminaron los antiguos `install/config/alternar-*.sh`, que no los usaba
  ningún atajo actual.
- Se eliminó el `portals.conf` duplicado de la raíz; el instalador usa
  `install/config/portals.conf`.
- Se eliminó `install/apt/trixie-backports.list`, porque el instalador escribe
  ese archivo directamente.
- Se eliminó `scripts/fix-network.sh`, que solo era un envoltorio de
  `scripts/network.sh`.

## 21. Notificaciones emergentes

`NotificationPopup.qml` muestra una tarjeta en la esquina superior derecha
cuando llega un aviso, como en el resto de escritorios. No sustituye al panel:
las notificaciones siguen guardándose en el historial hasta que se cierran.

- Se apilan hasta tres; las nuevas van arriba. El tiempo de permanencia es
  `expireTimeout` de la notificación (en milisegundos) y 5 s cuando la app
  deja que el servidor decida (`-1`). Un `-t 0` o una urgencia crítica se
  quedan hasta que se cierran.
- Comparten el margen de 8 px de la barra y el ancho de 360 px del panel
  lateral, y quedan 10 px por debajo de la barra, para que no parezcan
  descolgadas del resto del shell.
- El modelo es un `ListModel`: al llegar un aviso se inserta una tarjeta nueva
  sin reconstruir las anteriores, así que solo la nueva hace la animación de
  entrada y las viejas no parpadean.
- Al pasar el ratón, el temporizador se pausa. Un clic en la tarjeta abre el
  panel de notificaciones; la «×» descarta el aviso del historial (y con una
  alarma, `AlarmState` deja de sonar).
- No se muestran con «No molestar», con el panel abierto, en la vista general
  ni en la pantalla de bloqueo. Se limpian al abrir el panel o la vista
  general.
- Aparecen en el monitor de la ventana enfocada. La capa
  `shell-notification-popup` está incluida en la regla de cristal, así que
  hereda el desenfoque y el tono del shell.
- Sonido: si la app envía `sound-file` o `sound-name`, se respeta; si no,
  suena el aviso corto de freedesktop. `suppress-sound` lo silencia y el
  interruptor «Sonido de notificaciones» de Ajustes lo desactiva entero.
- Diagnóstico: `qs ipc -c shell call notifications popups` devuelve el número
  y los resúmenes de las tarjetas visibles.

Probado en una sesión anidada con un bus D-Bus privado (el de la sesión real
ya posee `org.freedesktop.Notifications`) y `notify-send`, incluyendo la
expiración automática y un aviso crítico persistente.

## 22. Animaciones y su velocidad

Umbriel anima apertura, cierre, movimiento, redimensión, cambio de escritorio,
vista general, scratchpad, diálogos, borde y capas con curvas propias. La
mayoría son resortes, y un resorte no usa `duration_ms`: su duración sale de
`stiffness`. Por eso bajar solo el tiempo no los acelera.

- `[animation] speed` multiplica toda la tabla. Las curvas por tiempo dividen
  su duración entre `speed`; los resortes multiplican `stiffness` por
  `speed²`, con lo que a `2.0` tardan la mitad y conservan la forma (`damping`).
- El valor por defecto del shell es `2.0`. Se ajusta en **Ajustes del shell →
  Velocidad de animaciones**, de 0.5× a 4× en pasos de 0.25.
- `scripts/shell-animation-speed` lo escribe con `shell-config-set` y pide
  `config-reload`; si el valor no cambia, no toca el archivo. Los ajustes se
  guardan en `settings.conf` como `animationSpeed`.
- El interruptor **Animaciones** escribe `[animation] enabled` con
  `scripts/shell-animations`. Al apagarlo, la fila de velocidad se atenúa y
  deja de tener efecto; las ventanas se mueven sin transición. Se guarda como
  `animationsEnabled` en `settings.conf`.
- No afecta a la física del arrastre (`[animation.windows_drag]`): esa responde
  al puntero y se siente mal si se escala como una transición.

## 23. Desenfoque al arrastrar

Con el cristal en «Fondo» (`optimized = true`) una ventana arrastrada ya no
cambia a desenfoque en vivo. Antes se forzaba el modo «Simple» al empezar el
arrastre, y por eso el fondo se veía distinto justo cuando movías la ventana.
Ahora se respeta la elección durante todo el gesto: «Fondo» sigue muestreando
la caché del fondo de pantalla y las ventanas de debajo quedan nítidas;
«Simple» sigue desenfocando el contenido real. La pista de inserción se ve,
pero no se desenfoca en modo «Fondo».

## 24. DNS: el punto de acceso no es una red

El perfil `shell-hotspot` que emite el punto de acceso también es de tipo
Wi-Fi, pero su `802-11-wireless.mode` es `ap`. `scripts/network-settings.py` lo
excluye de la lista de DNS y de proxy. Así dejan de aparecer tres entradas y
desaparece la que se llamaba «Desktop» con icono de Wi-Fi (era el SSID del
punto de acceso, tomado del nombre del equipo).

## 25. Cambio de modo: un único camino

El problema de la doble animación no era de tiempos ni de dobles clics: había
dos fuentes de verdad para el mismo cambio.

1. El shell enviaba `workspace-set-layout` en caliente.
2. Después escribía `[[workspace]]` en `config.toml`, y Umbriel recargaba la
   configuración y volvía a aplicar el layout.

Aunque el modo final coincidiera, las dos órdenes podían llegar en momentos
distintos y producir dos transiciones. Añadir comprobaciones y bloqueos solo
tapaba el síntoma.

Ahora el único camino en Umbriel es la configuración nativa:

- `WorkspaceModeState.setMode` solo guarda la preferencia en `settings.conf`.
- `SettingsState.applyWorkspaceModes` escribe el bloque `[[workspace]]` una
  vez y Umbriel lo aplica al recargar.
- El shell no llama a `workspace-set-layout` para cambiar de modo ni vuelve a
  aplicar el layout al enfocar un escritorio.
- En Umbriel no hay temporizador de 500 ms comprobando modos ni bloqueos de
  220/300 ms: el compositor ya aplicó la configuración al arrancar.
- El único agrupador que queda es el de escritura: 80 ms para unir varios
  cambios seguidos del mismo ajuste. No decide el modo ni vuelve a aplicar
  nada; solo evita escribir dos veces si se pulsan dos chips muy rápido.
- En Hyprland se conserva el camino de flotar/mosaicar ventanas, porque allí
  no existe la regla nativa.

Comprobado en sesión anidada con tres ventanas y dos cambios: las posiciones
muestran una sola transición por clic, una sola escritura de configuración y
una sola recarga.

## 26. Portapapeles con cliphist

El historial ya no lo guarda el shell: lo administra `cliphist`, que entiende
texto, listas de archivos e imágenes.

- `scripts/shell-clipboard-watch` ejecuta `wl-paste --watch cliphist store`.
  El shell solo mantiene vivo ese vigilante.
- `ClipboardState.qml` lee `cliphist list` cuando la vista del portapapeles
  está abierta y traduce cada línea a una entrada. Las imágenes se muestran
  como «Imagen PNG · 1920×1080»; el binario sigue dentro de la base de
  cliphist, no en un directorio propio.
- Pegar usa `scripts/shell-clipboard-copy` (`cliphist decode <id> | wl-copy`).
  Borrar usa `cliphist delete` y limpiar todo, `cliphist wipe`.
- El instalador añade el paquete `cliphist`. Si no está, la ficha muestra
  «Sin cliphist» y el resto del centro de control sigue funcionando.
- La base vive en la caché de cliphist (`~/.cache/cliphist/db`). Ya no se usa
  `~/.local/state/shell/clipboard.json`; se conserva por si hace falta
  recuperar algo de la versión anterior.

## 27. Brillo del panel interno

`scripts/shell-brightness` lee `/sys/class/backlight` sin permisos especiales.
Para escribir usa, en este orden:

1. El archivo `brightness` si el usuario puede escribirlo.
2. `brightnessctl`, instalado por el instalador y autorizado en
   `/etc/sudoers.d/shell-ddcutil` junto a `ddcutil`.
3. Si nada funciona, `DisplayState` mantiene el brillo por el filtro nativo.

`DisplayState.qml` prefiere DDC/CI para monitores externos y usa el panel
interno cuando DDC/CI no responde. Las teclas de brillo del portátil también
se detectan: el valor se relee cada 3 s. El deslizador y el OSD son los
mismos; no hay una vista nueva.

## 28. Atajo del micrófono

El atajo global ya no usa `hyprctl` (Herramienta de Hyprland, ausente en
Umbriel). `SettingsState` guarda la combinación en sintaxis de Umbriel, por
ejemplo `Mod+Shift+M`, y `scripts/shell-mic-shortcut` la escribe en
`[keybinds]` de `config.toml` con `shell-config-set`:

- Si el atajo nuevo no es el de fábrica, retira `"Mod+Shift+M"` para que no
  queden dos teclas haciendo lo mismo.
- Retira el atajo anterior y añade el nuevo.
- `shell-config-set` admite claves TOML entre comillas (`"Mod+Shift+M"`) y una
  opción `--remove-key` para reemplazar atajos sin duplicarlos.
- Al recargar, Umbriel aplica el cambio sin reiniciar la sesión.
- El capturador convierte `Ctrl`, `Alt`, `Shift` y `Super` a `Ctrl`, `Alt`,
  `Shift` y `Mod`.
- También acepta teclas multimedia (`XF86AudioPlay`, volumen, brillo,
  navegador, etc.) y `F13`–`F24` sin modificador. No acepta letras, números ni
  signos solos: un atajo global sobre ellos quitaría esa tecla a las
  aplicaciones.
- Los botones laterales del ratón se asignan solos como `MouseBack` y
  `MouseForward`. Umbriel ahora permite esos dos botones sin modificador;
  los botones principales y los botones con modificador siguen igual.
- Mientras se captura, el shell activa `shortcuts-inhibit-toggle`. Así Umbriel
  entrega también las combinaciones con Super al panel en vez de ejecutar el
  atajo global; al terminar se desactiva.
- La pulsación de Super no cierra el panel durante la captura. Sin esa regla,
  asignar `Mod+M` maximizaba una ventana y cerraba el editor.

Comprobado con clics reales en el chip: `Ctrl+M`, `Mod+M`, `XF86AudioPlay` y
`MouseBack` se asignan, no maximizan la ventana ni disparan otro atajo, y dejan
una sola línea en `[keybinds]`. Volver al valor de fábrica restaura
`Mod+Shift+M` sin duplicados.

No hace falta un servicio para las teclas multimedia habituales ni para los
botones laterales del ratón: libinput y Umbriel ya los entregan. Solo si una
tecla de marca no aparece habría que identificarla con `wev` y remapearla con
`keyd`; no se instala nada de eso por ahora.

## 29. Super abre y cierra el cajón

Un toque limpio de Super abre el lanzador; otro toque lo cierra. Mantener Super
sigue mostrando los controles de ventanas.

La causa de que no cerrara era que `shell.qml` cerraba todos los paneles al
detectar `CompositorState.modHeld`, incluido el lanzador. Al pulsar Super por
segunda vez, el lanzador se cerraba en la pulsación y la suelta lo volvía a
abrir. Ahora:

- La pulsación de Super cierra los demás paneles, pero no el lanzador.
- Mantener Super de verdad (`SuperState.active`) sí retira el lanzador.
- El bind suelto `"Mod"` se eliminó de `[keybinds]`: competía con el evento
  `modifiers` y podía abrir o cerrar dos veces.

Comprobado con un teclado virtual: `open=0 → open=1 → open=0`, y mantener
Super con el lanzador abierto lo cierra sin reabrirlo al soltar.

## 30. Discos internos y extraíbles

El plan completo está en `PLAN-DISCOS.md`.

- `scripts/mount-disks.sh --dry-run` detecta los discos internos NTFS sin
  montar y muestra las líneas que añadiría a `/etc/fstab`.
- `sudo ./scripts/mount-disks.sh --apply` las escribe, crea los puntos de
  montaje y comprueba que quedan montados. Usa `nofail`, así que un disco
  ausente no bloquea el arranque. `--uninstall` quita el bloque y desmonta.
- Las unidades USB no van a `fstab`: `udiskie` las monta al conectarlas y al
  iniciar sesión. El instalador añade el paquete y su servicio de usuario.
- `scripts/diagnose-usb-disk.sh` reúne `lsusb`, `lsblk`, `udisksctl` y el
  registro del kernel para saber por qué no aparece un disco externo. No
  modifica nada.

Si un SSD externo no aparece, el problema suele estar antes del automontaje:
cable, alimentación, puente USB-SATA/NVMe o formato no soportado.

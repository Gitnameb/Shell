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
| `scripts/shell-glass` | `[[layer_rule]]` y `[appearance.blur]` | `shell-config-set` |
| `install/bin/shell-keyboard-layout` | `[input.keyboard] layout` | `shell-config-set` |
| `install/bin/shell-umbriel-theme` | `[colors]`, `[colors.border]` y `[colors.title_bar]` | `shell-config-set` |
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

Los seis scripts ya no abren `config.toml` para escribir: calculan sus valores y
llaman al escritor. Si un proceso muere a mitad de la operación, el archivo
original sigue intacto.

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
sustituye `config.toml`; los seis scripts que antes escribían por su cuenta son
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
| `shell-window-chrome` | `[appearance.title_bar] overlay` |
| `shell-display-filter` | `[display]` |
| `shell-keyboard-layout` | `[input.keyboard] layout` |
| `shell-umbriel-theme` | `[colors]`, `[colors.border]`, `[colors.title_bar]` |

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
- Los seis scripts escriben lo esperado y solo recargan cuando hay cambios.
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
./scripts/shell-glass ensure        # añade las reglas si faltan
./scripts/shell-glass blur 12       # radio global; 0 apaga el blur
./scripts/shell-glass status
```

Bloque que se añade (idempotente, marcado con `# shell-glass: inicio`):

```toml
[[layer_rule]]
match.namespace = "^shell-(bar|side-panel|launcher|calendar|battery|tray|power|app-menu|osd|move-menu|welcome-mode|window-mode)$"
blur = true
blur_popups = true

[[layer_rule]]
match.namespace = "^shell-(wallpaper|desktop-icons|outside-close|filter)$"
blur = false
```

- `blur_optimized` queda en su valor por defecto (`true`): Umbriel muestrea la
  caché del fondo de pantalla, así que el cristal nunca desenfoca las ventanas
  que haya detrás. Es el mismo criterio que el mockup.
- `shell-wallpaper`, `shell-desktop-icons`, `shell-outside-close` y
  `shell-filter` se excluyen: son superficies transparentes a pantalla
  completa (o el velo de luz nocturna) y no deben crear una región de blur.
- El radio es **global** en Umbriel. El deslizador «Desenfoque» del shell
  escribe `[appearance.blur] radius` y también afecta al blur de las ventanas.
- La transparencia (`glassTransparency`, 0–90) solo cambia el alpha del shell:
  `alpha = (100 - transparencia) / 100`. Por defecto 22 → 0.78.
- No definir `blur_ignore_alpha` alto: con transparencias fuertes el alpha de
  la superficie baja y Umbriel podría saltarse el blur. El valor por defecto
  es 0.0 y se deja así.
- Pruebas: `./scripts/test-glass-rules.sh` y
  `./scripts/test-config-writers.sh`.

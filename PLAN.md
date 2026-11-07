# Shell · Plan para completar la integración

> Las menciones a «ALBA» en el texto histórico se conservan como registro del
> nombre anterior; el código y la documentación nuevos usan «shell».

Actualizado: 2026-11-05, ya dentro de la sesión real de Umbriel.

> **Plataforma decidida:** solo Umbriel sobre Debian. Hyprland y cualquier otro
> compositor quedan descartados; no se mantienen ni se prueban. El código
> antiguo de `HyprlandBackend.qml` puede quedarse como legado hasta la próxima
> instalación limpia.

> **Para retomar:** empieza por `PENDIENTES.md` (traspaso corto, estado actual,
> orden de tareas y errores que no hay que repetir).

La base funciona: ALBA arranca con Umbriel, la barra nativa reserva su espacio,
los seis botones actúan y los paneles responden. Lo que queda se ordena por
impacto en el uso diario, no por lucimiento.

## Criterios de este plan

1. Primero que funcione y se descubra; después la estética.
2. Nada que tape el contenido de las ventanas.
3. Todo en español y con iconos reales, sin emoji.
4. Cada punto se da por terminado con una prueba concreta, no con «compila».

## Lo que ya está

- Backend de Umbriel en `CompositorState` (ventanas, escritorios, foco, layouts,
  minimizar/restaurar, tema, teclado).
- Barra nativa propia (fork): icono real, subtítulo, seis botones, minimizar en
  mosaico, colores sincronizados con ALBA.
- Barra de ALBA con autoocultar, controles reordenables, fichas por ventana,
  anillo de progreso, bandeja, notificaciones, calendario, clima, alarmas,
  temporizador, música, portapapeles y teclado en pantalla.
- Centro de control 2×5 con Wi-Fi, Bluetooth, red, audio, brillo, luz nocturna,
  atenuación extra, hotspot, VPN, energía y ajustes.
- Menú contextual de las fichas, ahora anclado a la barra y con cambio directo
  de app con un clic derecho.
- Los paneles y menús se cierran al pulsar fuera, sin cerrar la barra.
- Al mantener Super, la píldora del escritorio activo permite cambiar entre
  Flotante y Mosaico con las fichas atenuadas debajo.
- Sesión Umbriel preseleccionada en SDDM, teclado `es`, ALBA en autostart.
- Puente X11 (`xwaylandvideobridge`) oculto en el scratchpad.

---

## Fase A · Cerrar la barra de título

**Objetivo:** que la decoración nativa sea indistinguible del mockup.

### A1. Estilo exacto de los botones (hecho)
- Iconos redibujados con los trazos del sprite (`i-mode-float`, `i-pin`,
  `i-move`, `i-minus`, `i-max`, `i-close`).
- Botones de 26 px, separación de 2 px e iconos de 13 px, como el mockup.
- Fondo transparente en reposo y tinte suave al pasar el ratón; cerrar usa un
  tinte rojo. Glifos en gris apagado y en color de texto al pasar.
- Icono real de la app a 20 px y subtítulo a 10 px.
- Aceptación: captura en Umbriel anidado. Falta verlo en la sesión real al
  reiniciar.

### A1b. Gesto de Super en Umbriel (hecho)
- Umbriel ya conocía el estado de Mod mientras se mantiene: lo usa para
  arrastrar ventanas y cambiar el cursor. Ahora lo publica también por IPC con
  el evento `modifiers` (`mod`, `modifiers` y `tap`).
- ALBA se suscribe a ese evento y muestra los controles de ventana durante el
  gesto, sin esperar al bind de modificador que llega al soltar. Si la barra
  está en autoocultar, también se revela mientras Super está pulsada.
- Un toque limpio abre el lanzador; un atajo (Super+Return, Super+1…) no lo
  abre al soltar. Umbriel decide el toque limpio y lo manda en el evento.
- El bind suelto `"Mod"` se conserva como respaldo para sesiones que aún no
  publican el evento: llama a `windows superTap`. Cuando el backend ya recibe
  `modifiers`, ese respaldo no hace nada, así que no se abre dos veces.
  `Mod+Space` sigue disponible y `Mod+Tab` sigue fijando los controles.
- Al desaparecer el teclado que mantenía Mod, el compositor emite el estado
  nuevo para que el overlay no se quede pegado.
- La hoja de atajos ya no aparece al arrancar; se abre con `Mod+F1`.
- Aceptación: con Super pulsada, la píldora del escritorio activo atenúa sus
  apps y muestra encima el icono del modo actual; al pulsarlo cambia entre
  Flotante y Mosaico. La barra inferior de modo ya no se abre.

### A1c. Cierre y menús de la barra (hecho)
- Pulsar fuera de un panel, del calendario, del menú de energía o del menú de
  una app cierra lo abierto. La capa de cierre deja libre la franja de la
  barra: un clic en otro widget abre su panel directamente.
- El menú contextual de una app es ahora una tarjeta, no una capa a pantalla
  completa. Un clic derecho en otra ficha cambia el menú a esa app sin cerrar
  el anterior; el mismo clic derecho en la misma ficha lo cierra.
- Las fichas minimizadas del escritorio activo se restauran al pulsarlas, así
  que ya no hace falta la barra de minimizadas del modo ventanas.

### A2. Botones según el estado (hecho)
- En un escritorio Flotante, «Flotar» se oculta y «Fijar» aparece.
- En Mosaico, «Flotar» aparece y «Fijar» se oculta; una ventana suelta dentro
  de un mosaico muestra los dos.
- «Fijar», «Flotar» y «Maximizar» usan el mismo indicador activo que
  `.wc.active` del mockup: acento al 13 % (20 % al pasar) y glifo de acento.
- Desanclar devuelve la ventana al escritorio activo en ese momento, como
  `w.ws = activeWs`: si allí el modo es mosaico, vuelve al mosaico; si es
  flotante, sigue flotando. Ya no se queda en el escritorio donde se fijó.
- Aceptación cumplida en Umbriel anidado: fijar en el escritorio 1, cambiar al
  2 y desanclar deja la ventana en el 2, mosaicada; si el 2 es flotante, sigue
  flotante. Capturas de los tres estados del indicador revisadas.

### A3. Botón «Mover» con selector (hecho)
- El mockup abre un selector 1–9 junto al botón. Umbriel ya no abre la vista
  general: emite un evento `move_menu` con la ventana, el puntero y un serial.
- ALBA se suscribe desde `UmbrielBackend` y dibuja `WorkspacePicker`, una
  tarjeta de 46 px con el escritorio actual resaltado. Elegir otro escritorio
  desancla la ventana si estaba fijada y la mueve con
  `window-move-to-workspace-silent`; elegir el actual solo cierra.
- Escape o un clic fuera cierran el selector. `umbriel move-menu <id>` permite
  abrirlo desde un atajo o un script; el botón nativo no necesita el comando.
- Aceptación: captura en Umbriel anidado con la tarjeta abierta y cerrada con
  Escape; el movimiento usa el mismo camino ya probado de `CompositorState`.
- **Corregido:** Umbriel estaba en escritorios dinámicos y solo existían dos o
  tres, así que 4–9 caían en el último. La configuración fija nueve escritorios
  (`[output."<conector>"] workspaces = 9`). El número de cada escritorio con
  ventanas se ilumina, incluidas las minimizadas.

### A4. Volumen por ventana (primera versión, hecho)
- El mockup tiene un botón de volumen antes de «Flotar» y un deslizador por
  ventana.
- Primera versión: el centro de control → Volumen lista «APLICACIONES CON
  AUDIO» con una fila por flujo de PipeWire, silencio y deslizador propio. No
  usa el volumen global y funciona con cualquier app que reproduzca.
- Aceptación: con Firefox reproduciendo, el panel mostró su flujo con título y
  el 100 %; el control escribe en `PwNode.audio`, el mismo camino del volumen
  global. Queda pendiente probar el arrastre con ratón físico y, más adelante,
  el botón nativo en la barra de título.

### A5. Persistencia de ventanas (hecho)
- La ficha minimizada desaparecía al reiniciar ALBA porque Umbriel publicaba
  `scratchpad_return_index` en base 0: el escritorio 1 devolvía `0` (que ALBA
  leía como «sin origen») y el 2 devolvía `1`. La ventana seguía en el
  scratchpad y se podía restaurar desde Ajustes, pero la barra no sabía dónde
  ponerla.
- Umbriel publica ahora el índice en base 1, igual que `workspaces`, y ALBA
  resuelve el nombre de retorno como respaldo. No se guarda `windows.json`.
- **Curiosidad descartada:** recordar la geometría de cada app entre sesiones.
  Choca con el tamaño por defecto de A20 y con las reglas de ventana; no se
  implementa.
- Aceptación: minimizar en mosaico y flotante, `qs -c shell kill`, relanzar y
  ver las fichas en su escritorio; restaurar una.

### A6. Fichas minimizadas y restauración (hecho)
- Una ventana minimizada conserva su ficha en la barra, atenuada al 40 % (85 %
  al pasar el ratón), en vez de desaparecer. La ficha va al escritorio de origen
  aunque Umbriel la haya movido al scratchpad y su `workspace` esté vacío.
- Umbriel publica `scratchpad_return_index` y `scratchpad_return_name` en
  `windows --json`; ALBA los usa como origen y guarda además el último
  escritorio visto por si el compositor es anterior a esos campos.
- `umbriel restore-window <id>` devuelve la ventana exacta a su escritorio sin
  mostrar el resto del scratchpad. Antes se enfocaba primero y eso revelaba
  todas las ventanas aparcadas, que quedaban flotando sin poder usarse como
  ventanas normales. La barra, el centro de control y «Enfocar» sobre una
  minimizada usan ese comando; si el binario no lo tiene, ALBA cae al camino
  anterior.
- Restaurar sin revelar el pad dejaba la ventana **invisible**: al ocultarse,
  el scratchpad la desvanece a opacidad 0 y apaga su nodo de escena, y solo
  mostrarlo deshacía ese estado. `restore-window` no lo mostraba, así que la
  ventana volvía a su escritorio con `visible=true` pero sin dibujarse.
  `ScratchpadManager::restoreView` ahora cancela el desvanecido y vuelve a
  habilitar el nodo al devolverla a un escritorio activo.
- Aceptación en Umbriel anidado: dos kitty minimizadas (una a scratchpad y
  otra nativa) siguen en la barra atenuadas con origen en el escritorio 1;
  restaurar una deja la otra oculta y la restaurada se ve y se enfoca con
  normalidad; restaurar la segunda devuelve ambas a su sitio. También se probó
  el estado «scratchpad visible» que antes dejaba la ventana inutilizable y la
  restauración nativa (flotante minimizada).

### A7. Cromo nativo con dos estilos (hecho)
- Umbriel gana `[appearance.title_bar] overlay`: dibuja su barra de título
  **dentro** del contenido y solo mientras se mantiene Mod. No reserva
  espacio, no desplaza la ventana y los botones siguen siendo nativos; ALBA no
  crea ninguna capa para esto.
- El ajuste público es «Barra de ventanas» con dos opciones, como el mockup:
  **Flotante** (`overlay = true`; aparece con Mod) e **Integrado**
  (`overlay = false`; siempre visible y el contenido empieza debajo). ALBA lo
  guarda en `settings.conf` y aplica el cambio en caliente escribiendo la
  configuración de Umbriel y recargándola.
- **Flotante son dos píldoras separadas**, como el `chrome-floating` del
  mockup: la del título (icono de la app + nombre) pegada a la izquierda y la de
  los botones a la derecha, ambas con margen y esquinas redondeadas. El
  subtítulo se oculta en este modo. La franja que cubren es más alta que la
  barra (margen de 7 px) para que no la recorte la esquina redondeada de la
  ventana, pero sigue sin reservar espacio. **Integrado** mantiene la franja a
  ancho completo con el subtítulo y los botones dentro.
- El botón «Mover a otro escritorio» usa el glifo `#` del ejemplo web, no la
  cruz de flechas.
- La barra oculta de ALBA ya se revelaba con Mod. Con este cambio también
  aparecen los controles de cada ventana, como el `chrome-floating` del mockup.
- La barra vive en el árbol de contenido de la vista; en modo flotante se
  eleva sobre la superficie del cliente y los diálogos adjuntos siguen por
  encima. El hit test de botones y arrastre se adapta a las píldoras, incluido
  el desplazamiento horizontal de los botones. Al alternar de estilo, el
  espacio de trabajo se recoloca solo; en ventanas flotantes el contenido
  encoge o crece por la altura de la barra para que el marco exterior no se
  mueva.
- Aceptación en Umbriel anidado: flotante sin Mod no tiene barra y el
  contenido llega al borde; manteniendo Alt (Mod del anidado) aparecen las dos
  píldoras con icono, título, seis botones y borde de ventana; al soltar
  desaparecen sin mover el contenido. Integrado deja la franja siempre visible
  y el contenido debajo. Se alternó en caliente en ambos sentidos sin
  reiniciar el compositor y la ventana conservó su posición exterior.
- Instalado en `/usr/bin/umbriel` (`fdf05109f9de`); hace falta cerrar sesión
  para que el compositor en marcha use el binario nuevo.

### A8. Fondo de pantalla (hecho)
- `Wallpaper.qml` dibuja la imagen elegida en una capa `Background` por
  pantalla, por debajo de los iconos y de las ventanas. Sin imagen se ve el
  fondo propio de Umbriel.
- Ajustes → «Fondo de pantalla» tiene miniatura, «Elegir» (selector KDE o
  Zenity) y «Quitar». La ruta se guarda en `settings.conf` y se mantiene entre
  sesiones; también se puede fijar con
  `qs ipc -c shell call appearance wallpaper <ruta>`.
- Aceptación: con la imagen 1920×1080 de Umbriel se vio a pantalla completa,
  también con espacios en la ruta; quitar la imagen devolvió el fondo del
  compositor.

---

## Fase B · Sesión real y servicios

**Objetivo:** que no haya sorpresas fuera del entorno anidado.

### B1. Pruebas físicas (S)
- Teclado `es` y cambio de layout desde Ajustes.
- `Mod` (toque abre el lanzador), mantener `Mod` (controles), `Mod+Tab`
  (fijar), `Mod+Shift+W`, `Mod+1..9`.
- Que un atajo como `Mod+Return` no abra el lanzador al soltar Mod.
- Teclas de volumen, brillo y silencio del micrófono.
- Ratón físico en la barra, el menú contextual y el centro de control.

### B2. Bloqueo e inactividad (hecho)
- `swayidle` instalado y `hyprlock` ya estaba.
- `~/.local/bin/shell-idle MINUTOS` arranca `swayidle` contra
  `ext_idle_notifier_v1` de Umbriel y lanza `hyprlock` al cumplirse el tiempo.
  También bloquea antes de suspender.
- Ajuste «Bloqueo automático» en el centro de control, con opciones Nunca, 1,
  5, 10, 15 y 30 minutos. Por defecto 5. Se guarda en `settings.conf`.
- Verificado en Umbriel anidado: la pantalla de bloqueo aparece con la hora y
  la fecha en español, y se desbloquea escribiendo la contraseña real.
- **No bloquea mientras hay reproducción.** La barra tiene un
  `IdleInhibitor` sobre su superficie, activo cuando `MusicState.playing`
  (música o vídeo por MPRIS), así que el compositor no emite inactividad a
  `swayidle`. Aceptación: con VLC exponiendo MPRIS en «Playing», un
  `swayidle` de prueba de 10 s no disparó; al cerrarlo, uno de 8 s sí.

### B3. Portales y captura (portal verificado, falta Firefox/X11)
- `umbriel.portal` implementa ScreenCast y Screenshot, pero no el diálogo de
  permiso (`org.freedesktop.impl.portal.Access`). Sin un backend para Access,
  `xdg-desktop-portal` se bloquea esperando y termina en «Failed to show access
  dialog: Timeout was reached»; una vez además terminó en SEGV.
- `~/.config/xdg-desktop-portal/portals.conf` mapea Access a GTK, que ya corre
  en la sesión. Así el diálogo se muestra y los portales siguen eligiéndose
  automáticamente para el resto de interfaces.
- Aceptación del portal: la captura devuelve `Response 0` con un PNG real y el
  flujo ScreenCast abre el selector de Umbriel (pestañas Screens/Windows, elige
  HDMI-A-1), y `Start` devuelve un stream de 1920×1080. Queda probar el flujo
  completo desde Firefox y desde una app X11.
- El puente `xwaylandvideobridge` está desactivado en el arranque con
  `~/.config/autostart/org.kde.xwaylandvideobridge.desktop` (`Hidden=true`).
  Sigue instalado y conserva su regla de scratchpad por si hace falta compartir
  pantalla desde una app X11: basta reactivarlo y lanzarlo.
- Nota: el selector de Umbriel y el diálogo de GTK están en inglés (son de los
  portales, no de ALBA); el resto de la interfaz sigue en castellano. Con
  PipeWire 1.4.2 el portal oculta el cursor en las capturas compartidas
  (pide 1.4.8 para los metadatos); no impide compartir.

### B4. Bandeja y notificaciones (hecho)
- Los iconos de bandeja ya no se amontonan en la barra: cuando hay alguno, la
  barra muestra un botón con chevron. Al pulsarlo se abre «Bandeja del sistema»,
  un panel con una rejilla de iconos; con la barra arriba el chevron se
  invierte para apuntar hacia dentro.
- Los iconos de la bandeja ya se ven: Quickshell los entrega como
  `image://icon/...`, no como nombre del tema, y antes la barra los ocultaba.
- Cada icono del panel conserva activar con clic izquierdo, menú con clic
  derecho, acción secundaria con el botón central y paso de rueda. El panel se
  cierra al pulsar fuera, con Escape, al abrir otro panel, al ocultarse la
  barra o al quedarse sin iconos.
- `shell.qml` lleva `//@ pragma UseQApplication`: sin él, Quickshell no puede
  mostrar menús de plataforma y el menú de la bandeja no aparece. Exige
  reiniciar el proceso de ALBA, no solo recargar QML.
- Verificado en anidado y en la sesión real con KDE Connect: chevron visible,
  panel desplegado y menú «Configure…» con clic derecho. Al cerrar la app de
  prueba, el chevron desaparece.

### B5. Red y Bluetooth reales (M)
- Wi-Fi: escanear solo con el panel abierto, reconexión automática, olvidar,
  QR y bandas.
- Bluetooth: emparejar un dispositivo nuevo y leer su batería.
- Autoapagado de 15 min y punto de acceso.
- Aceptación: cada flujo termina sin tocar la terminal.

---

## Fase C · Paneles y ajustes pendientes

### C1. Persistir el orden (hecho)
- `BarState` conserva `defaultControls` y `defaultCenterOrder`, valida las
  listas y expone `restore()` / `resetLayout()`.
- `SettingsState` guarda `barControls=` y `centerOrder=` en `settings.conf` y
  los restaura al arrancar. Ajustes → «Orden de los controles» → «Restablecer»
  vuelve a los defaults.
- Aceptación: reordenar barra y centro, reiniciar el shell y comprobar que se
  conserva; probar «Restablecer».

### C2. VPN y energía (hecho)
- VPN: pendiente de ampliar opciones; el usuario dirá cuáles más adelante. La
  vista lista los perfiles reales de NetworkManager y añade
  «Importar .ovpn» (KDialog/Zenity → `nmcli connection import type openvpn`).
  Cada perfil tiene un engranaje para cambiar el nombre visible y «Conectar al
  iniciar», y se puede borrar con confirmación. Requiere el paquete
  `network-manager-openvpn`; si falta, el error se explica en castellano.
- Energía en la batería: el icono de la barra usa el dibujo del mockup
  (contorno, relleno, punta, rayo y barrido de carga). Sin batería sigue
  visible, con rayo de corriente y sin porcentaje. Al pulsarlo se abre un panel
  con «Ahorro / Equilibrado / Rendimiento», estado y descripción; en Ahorro el
  icono se tiñe de celeste, y los avisos de batería mandan. También hay IPC:
  `qs ipc -c shell call battery toggle` y `battery profile ahorro`.
- Energía solo en la batería: por decisión del usuario, Ajustes ya no muestra
  la sección «ENERGÍA». Los tres perfiles de `power-profiles-daemon` se
  cambian desde el panel del icono de batería. El IPC
  `qs ipc -c shell call power profile ahorro` se mantiene para atajos y pruebas.
- Perfiles personalizados: idea futura, no implementada. Requiere un ayudante
  privilegiado para límites de CPU/GPU/TDP y detección de lo que expone cada
  equipo; no se inventan controles ni valores.
- Aceptación: por IPC se importó un `.ovpn` de prueba, se renombró a
  «Prueba VPN» con arranque automático desactivado y se borró; la lista se
  actualizó sola. Los perfiles de energía se probaron en real
  (performance → balanced → power-saver → balanced). El panel de la batería se
  verificó por IPC y captura; falta el clic físico en el engranaje, las fichas
  y el icono de batería.

### C3. Brillo y OSD (hecho)
- Las teclas de brillo ya llaman a `DisplayState.setBrightness`, que aplica el
  paso de 5 % y muestra el OSD con el icono de sol y el porcentaje.
- Verificado en anidado con `notifications brightnessDown`: el aviso aparece y
  se oculta solo. Falta la prueba con la tecla física del monitor.
- El brillo también se lee del monitor: `ddcutil` no avisa de los cambios
  hechos con sus botones, así que se relee cada 3 s y se actualiza el
  deslizador sin mostrar OSD. Verificado en real: un cambio externo a 40 se
  adoptó y la siguiente pulsación bajó a 35.

### C4. Fondo de pantalla y tema de apps (hecho)
- Además de la imagen, Ajustes ofrece «Color de fondo» con seis muestras y un
  campo `#RRGGBB`. Elegir un color quita la imagen; quitar la imagen vuelve al
  color. Se guarda como `wallpaperColor=` en `settings.conf` y se puede cambiar
  por IPC con `appearance wallpaperColor`.
- `shell-system-theme` verificado en la sesión real: GTK 3/4 reciben el acento
  en `gtk.css`, y KDE recibe `BreezeDark` y el mismo acento en `kdeglobals`.
- Verificado en anidado: el color sobrevive al reinicio de ALBA y se ve en la
  capa de fondo.

### C5. Extras del panel del reloj (hecho)
- **Clima manual.** Ajustes guarda `weatherPlace=` y `WeatherState` consulta
  esa ciudad en wttr.in; vacío vuelve a la detección por IP. En la pestaña
  Clima, «Cambiar» abre un campo con «Aplicar» (Intro también aplica).
  Aceptación: Madrid mostró su tiempo y al vaciar el campo volvió a la ciudad
  detectada por IP.
- **Alarmas con el shell cerrado.** `scripts/shell-alarms` corre como servicio
  de usuario (`shell-alarms.service`) y lee `alarms.conf`. Si `qs` está
  abierto no hace nada, para no duplicar el aviso del panel; si no lo está,
  usa `notify-send` o, cuando no hay servidor de notificaciones, un diálogo de
  KDialog/Zenity, y reproduce el sonido de alarma.
- **Temporizador persistente.** Al arrancar una cuenta atrás se escribe
  `deadline=` en `~/.config/shell/timer.conf`; al pausar o terminar se borra.
  El demonio termina el temporizador con el shell cerrado y el panel restaura
  la cuenta atrás al volver. Aceptación: se recuperó una cuenta atrás de
  01:12 «En marcha» tras recargar, un vencimiento con el shell abierto avisó y
  limpió el archivo, y el demonio avisó del temporizador con `--force`.

---

## Fase D · Escritorio y ventanas avanzadas

### D1. Iconos de escritorio (fase 1 hecha)
- Cuadrícula, arrastre, intercambio y doble clic para abrir.
- Es lo más grande que queda del mockup y no es imprescindible para el uso.
- Fase 1 implementada: `DesktopState.qml` lee `~/Desktop` con
  `FolderListModel` y `DesktopIcons.qml` pinta una capa por pantalla debajo de
  las ventanas. Muestra carpetas, archivos, imágenes como miniatura y
  lanzadores `.desktop` con su nombre e icono reales; selección con un clic y
  apertura con doble clic o `qs ipc -c shell call desktop open <índice>`.
- Aceptación: con dos carpetas, una imagen, un `.desktop` y un texto, la
  cuadrícula los mostró en orden, con Firefox ESR y su icono; abrir la carpeta
  por IPC lanzó Dolphin en esa ruta.
- Se puede soltar un archivo desde Dolphin sobre el escritorio: `DropArea` en
  `DesktopIcons.qml` llama a `scripts/shell-desktop-drop`, que mueve dentro de
  la misma unidad, copia entre unidades y evita pisar nombres. El script está
  probado por separado; falta la prueba del arrastre real.
- Pendiente fase 2: arrastrar para recolocar con posiciones persistentes,
  renombrar, papelera, menú contextual y selección múltiple. **Aparcada por
  decisión del usuario (2026-11-05):** se retoma al final, después del resto
  de bloques.

### D2. Apps web (M, opcional)
- «Instalar app web» como `.desktop` con `chromium --app=...`.
- El botón de volumen por ventana de A4 les sirve igual.

### D3. Vista general (hecho)
- `Mod+Tab` abre o cierra la vista general de Umbriel (`overview-toggle`).
- La barra de controles de ALBA que estaba en `Mod+Tab` pasa a `Mod+Shift+Tab`.
- ALBA escucha el evento `overview` y, al abrirse la vista, retira lanzador,
  notificaciones, calendario, energía, selector de movimiento y controles de
  ventana para no quedar flotando encima.
- Verificado en anidado con Alt+Tab y en la sesión real con Super+Tab:
  `overview=1`, el lanzador se cerró y un segundo atajo volvió a `overview=0`.

---

## Fase E · Mantenimiento y robustez

### E1. Script de compilación (S)
- `scripts/install-umbriel-fork.sh`: clona Umbriel si no existe, aplica
  `umbriel-fork.patch`, compila, instala con `mv` atómico, guarda copia del
  binario original y valida el hash.
- `install.sh`: instala repositorios, paquetes, configuración, sudoers y
  alarmas, y llama al script del fork.
- **Hecho.** Probado con `--dry-run` y con una compilación completa desde un
  clon limpio de Umbriel (`b6c4b7d` + parche). Falta la prueba definitiva en un
  Debian recién instalado.

### E2. Rebase del fork (M, recurrente)
- El parche está sobre `b6c4b7d`. Cada actualización de Umbriel exige rebasar
  y volver a probar los seis botones.
- Alternativa a valorar: enviar los cambios a Umbriel upstream para dejar de
  mantener el fork.

### E3. Prueba automática (M)
- Script que arranca un Umbriel anidado, lanza ALBA, comprueba que no hay
  errores QML, abre el menú y guarda capturas.

### E4. Reversión (S)
- Documentar y probar `sudo cp /usr/bin/umbriel.stock-0.1.0 /usr/bin/umbriel`.
- **Hecho parcial:** el comando de restauración atómica está en
  `INSTALACION.md`; falta probarlo en una instalación limpia.

---

## Orden recomendado

1. **Ahora:** cerrar sesión y volver a entrar para cargar `a4b9b8fdd314`:
   barra de título con estilos Flotante e Integrado, retardo del gesto Mod
   configurable, barra arriba/abajo, música estable y ajustable, reloj nuevo,
   tamaño y cascada de ventanas flotantes, memoria de la disposición en
   mosaico, borde redimensionable con Mod, barra usable con Super, vuelta de
   cada ventana a su hueco al volver a mosaicar, cursor que no se queda pegado,
   hueco conservado mientras la ventana está fijada y apertura en cascada
   también para las apps nuevas en escritorios Flotante.
2. **Después:** comprobar en real el gesto de Mod: un toque abre el lanzador
   sin atenuar; mantener el retardo elegido atenúa el contenido, suelta el
   ratón del juego y muestra las píldoras. Con Super pulsado, usar el botón de
   modo de la píldora para ir a Flotante y volver, y flotar una sola ventana
   con su botón para comprobar que al mosaicarla regresa a su hueco. Repetir
   con una ventana fijada: debe seguir a otros escritorios y, al volver al de
   origen y desanclarla, recuperar su hueco. Con Super pulsado, mover el ratón
   del borde de un mosaico a la barra y comprobar que el cursor deja de ser de
   redimensionar.
   En Ajustes, subir o bajar «Retardo al mantener Super» y comprobar que el
   compositor cambia con el mismo valor.
   Con ratón físico, estirar la música desde el asa y cambiar la barra
   arriba/abajo. Probar «Tamaño de ventanas flotantes» y «Separación en
   cascada»: flotar una ventana de un mosaico debe dar el tamaño elegido y
   cambiar un escritorio entero a Flotante debe dejar las ventanas en cascada.
   Abrir una app nueva en un escritorio Flotante: debe nacer con ese mismo
   tamaño y en el siguiente hueco de la cascada, no con el tamaño que pida la
   app.
   Con Super pulsado, arrastrar el borde entre dos ventanas de mosaico para
   redimensionar y el centro para mover; comprobar que volver de Flotante a
   Mosaico devuelve cada ventana a su sitio.
3. **También:** en Ajustes, alternar «Barra de ventanas» entre Flotante e
   Integrado y comprobar que la ventana se recoloca sin cerrar sesión; elegir
   un fondo de pantalla y quitarlo.
4. **También:** probar el volumen por aplicación con el centro de control →
   Volumen y el ratón físico, y abrir iconos del escritorio con doble clic.
5. **Hecho:** A5 (fichas minimizadas tras reiniciar ALBA, confirmado en real)
   y C1 (orden de los controles). Falta el reordenado con ratón y
   «Restablecer».
6. **Hecho:** arreglos rápidos: menú de la bandeja (B4), OSD de brillo (C3),
   color de fondo (C4) y vista general de Umbriel en `Mod+Tab` (D3).
   Verificados en anidado; queda la prueba con hardware real.
7. **Hecho:** C2 (perfiles de energía, importar y editar VPN) y C5 (clima
   manual, demonio de alarmas y temporizador persistente). Falta el clic
   físico en el engranaje de VPN y en las fichas de energía.
8. **Hecho:** B2 (no bloquear mientras hay reproducción) y el portal de B3
   (captura y ScreenCast). Falta probar Firefox/X11 y el hardware real de B5.
9. **Al final, por decisión del usuario (2026-11-05):** fase 2 de D1
   (recolocar iconos, renombrar, papelera y menú contextual).
10. **Antes de la instalación limpia:** E1 (script único de compilación e
    instalación), E4 (reversión documentada) y una copia de `~/Shell`,
    `~/.config/shell`, `~/.config/umbriel` y el parche del fork.
11. **Opcional / aparcado:** botón nativo de volumen por ventana, D2 y E3.

## Decisiones tomadas

- **Botones:** fondo transparente en reposo y tinte solo al pasar el ratón,
  como el mockup.
- **Volumen por ventana:** sí, en el centro de control por ahora; una fila por
  flujo de PipeWire. El botón en la barra de título queda para más adelante.
- **Bloqueo automático:** sí, 5 minutos por defecto y configurable.
- **Iconos de escritorio:** sí, fase 1 de ver y abrir; el arrastre y el menú
  contextual quedan para la fase 2.
- **Cromo de ventana:** nativo y con dos estilos, «Flotante» (aparece con Mod,
  superpuesto) e «Integrado» (siempre visible, con el contenido debajo). Lo
  dibuja Umbriel; ALBA solo guarda la preferencia y la aplica.
- **Fondo de pantalla:** imagen local elegida desde Ajustes, en capa
  `Background` por pantalla; sin imagen se mantiene el fondo del compositor.
- **Super:** mantenerlo muestra el cambio de modo en la píldora del escritorio
  activo y revela la barra; un toque limpio abre el lanzador; un atajo no lo
  abre. `Mod+Tab` sigue fijando los controles como camino alternativo.
- **Hoja de atajos:** oculta al arrancar; se abre con `Mod+F1`.
- **Fork:** se mantiene el fork y se avanza con los cambios hasta dejar el
  escritorio como se quiere. La opción de subir cambios a Umbriel queda para
  más adelante.

### A9. Filtro de pantalla nativo (hecho)
- Umbriel gana la tabla `[display]` (`brightness`, `extra_dim`, `warm`) y un
  shader de salida integrado, `screen.alba_display`, que se aplica después de
  todas las superficies. Cubre por igual ventanas, escritorio, barra, paneles,
  lanzador y OSD; el cursor hardware queda fuera, como en cualquier efecto de
  pantalla.
- La luz nocturna **multiplica** el color por un tono ámbar (rojo 1.0, verde
  hasta 0.84, azul hasta 0.64) en vez de superponer un velo. El negro sigue
  negro y el contraste se conserva; la atenuación y el brillo de respaldo
  también multiplican.
- Es un efecto de accesibilidad: mientras está activo sustituye a un efecto de
  pantalla decorativo, para que el filtro llegue a todo. No se incluye en las
  capturas por defecto (`effects.in_capture = false`), así una captura conserva
  los colores reales.
- `DisplayState.qml` usa este camino cuando el backend declara
  `displayFilter`. `scripts/shell-display-filter` escribe los tres valores en
  `~/.config/umbriel/config.toml` y pide `config-reload`; si no cambian, no
  toca el archivo. La capa QML de respaldo sigue existiendo para compositores
  sin filtro nativo.
- Aceptación en Umbriel anidado: con `extra_dim = 0.35` y `warm = 0.60`, el
  texto blanco pasa de `0.867` a `(0.565, 0.510, 0.443)`; con valores neutros
  vuelve a `0.867`. Cambiar los valores en caliente actualiza el shader sin
  recompilarlo. En capturas hace falta `in_capture = true` para verlo.

### A10. Modo ventanas sin interacción con el contenido (hecho)
- Mientras se mantiene Mod, el compositor trata el contenido de las ventanas
  como inerte: no envía movimiento, botones, rueda, toque ni movimiento
  relativo a los clientes, y desactiva cualquier `pointer-lock` o confinamiento
  activo. Así un juego deja de capturar el ratón y se pueden acomodar ventanas.
- El contenido se cubre con un velo negro al 28 % dentro del árbol de la
  ventana, por encima de la superficie del cliente y por debajo del cromo
  nativo; las píldoras de título, la barra y los paneles no se atenúan. El velo
  acompaña al contenido en ventanas flotantes, en mosaico y a pantalla completa.
- Las pulsaciones izquierda y derecha con Mod siguen iniciando mover y
  redimensionar. Un clic sobre las píldoras o la barra sigue funcionando.
- Aceptación en Umbriel anidado con `seat-log-client` y un puntero virtual: al
  mantener Alt el cliente recibe `pointer-unlocked` y `leave` y deja de recibir
  `relative-motion`; al soltar recibe `enter` y `pointer-locked` de nuevo. La
  captura muestra el contenido atenuado y las píldoras nativas sin atenuar.
- Binario integrado en `69fe1a58a28d` e instalado en `/usr/bin/umbriel`; falta
  cerrar sesión para que la sesión real lo use.

### A11. Gesto de Mod con retardo, barra arriba/abajo y música ajustable (hecho)
- El modo de mantener Mod ya no se enciende al instante. Umbriel espera
  320 ms (hoy `[input] mod_hold_delay_ms`, ver A12) antes de activar el
  aislamiento del contenido, el velo y las píldoras nativas. Un toque corto
  sigue abriendo el lanzador sin atenuar la pantalla ni soltar el ratón de un
  juego. ALBA usa el mismo valor en `SuperState.holdDelay`.
- La barra puede vivir arriba o abajo desde Ajustes → «Posición de la barra».
  Se guarda `barPosition` y se recolocan la barra, su franja de revelado, el
  panel lateral, el calendario, la energía, el OSD, la barra del modo ventanas
  y el menú contextual de las apps, además de la reserva de espacio de las
  ventanas.
- El reproductor de música se puede estirar manteniendo Mod: un asa en su
  borde derecho ajusta el ancho entre 140 y 420 px. Se guarda `musicWidth`
  (0 = automático) y un doble clic en el asa vuelve al ancho automático.
- Aceptación: con Alt mantenido en Umbriel anidado, la captura a 150 ms no
  muestra velo y la de 600 ms sí (brillo 0,914 → 0,659, un 28 % negro); un
  toque de 100 ms nunca atenúa. La barra arriba recoloca calendario y panel
  lateral; la música a 300 px ensancha la píldora sin romper el resto.
- Binario `69fe1a58a28d` instalado en `/usr/bin/umbriel`; falta cerrar sesión
  para estrenarlo en la sesión real.

### A12. Retardo ajustable, música estable y reloj más legible (hecho)
- El retardo del gesto de mantener Mod ya no es una constante. Umbriel lee
  `[input] mod_hold_delay_ms` (320 por defecto, 50–2000) y ALBA lo ajusta en
  Ajustes → «Retardo al mantener Super» con pasos de 50 ms. El valor se guarda
  como `superHoldMs` en `settings.conf` y el script `shell-mod-hold` lo escribe
  en la configuración del compositor y recarga. `SuperState.holdDelay` usa el
  mismo valor para que el overlay no se adelante ni se retrase.
- La música deja de temblar al mantener Super. La causa era un ciclo de
  tamaño (`Item` medía desde `root.width` y la píldora medía desde su fila),
  el asa metida en la fila de contenido de `Pill.qml`, y el `Loader` de la
  barra conservando el ancho del primer montaje. Ahora el texto se mide desde
  `musicWidth`, el asa cuelga de la píldora con `parent: root`, y el `Loader`
  publica `Layout.preferredWidth/Height` del elemento cargado. El ancho cambia
  en vivo entre 140 y 420 px.
- El reloj mantiene el lado izquierdo en dos líneas (hora arriba, día de la
  semana abajo) y devuelve el derecho a tres filas: número del día arriba, mes
  en medio y año abajo, con poco aire entre ellas. La barra sube de 40 a 44 px
  para dar más margen vertical al contenido.
- Aceptación: en Umbriel anidado, con `mod_hold_delay_ms = 600` una pulsación
  de 1,6 s no atenúa a los 300 ms y sí a los 900 ms; un toque de 200 ms no
  atenúa. Al recargar el valor a 200 ms, la captura a 350 ms ya muestra el velo.
  En la sesión real, la música a 140 y 300 px cambia de ancho en vivo sin
  desplazar el texto, y el reloj muestra el día, el mes y el año en tres filas.
- Binario `0f9951fa5f30` instalado en `/usr/bin/umbriel`; falta cerrar sesión
  para que el compositor en marcha estrene el retardo configurable.

### A13. Tamaño y cascada de ventanas flotantes (hecho)
- Flotar una ventana de un mosaico ya no conserva el tamaño del mosaico. La
  primera vez que una ventana deja de estar en mosaico toma
  `[layout.stacking] default_width_fraction` por `default_height_fraction` del
  área útil (0,6 por defecto). Un tamaño recordado, incluido el que el usuario
  elige al redimensionar, tiene prioridad en las siguientes veces.
- Las ventanas nuevas se colocan centradas y, si taparían a otra ventana
  visible, se desplazan en diagonal. `cascade_step` fija la separación mínima
  en píxeles; 0 la calcula desde la barra de título, nunca por debajo de 32 px.
- Cambiar un escritorio entero de mosaico a flotante ignora las posiciones
  recordadas y coloca las ventanas en orden de cascada, para que no se apilen
  todas en el último sitio donde flotaron. Las que ya estaban flotando se
  quedan donde están.
- ALBA lo ajusta en Ajustes → «Tamaño de ventanas flotantes» (40–80 %, pasos
  de 5) y «Separación en cascada» (0 = automático, hasta 96 px, pasos de 8).
  Se guarda como `floatingSizePercent` y `floatingCascade` en `settings.conf`;
  `scripts/shell-floating-defaults` escribe la configuración de Umbriel y
  recarga.
- Aceptación en Umbriel anidado (946×496): con 0,6 una ventana flotante mide
  568×298 y aparece centrada; con 0,5 y cascada de 48 mide 473×248. Tres
  ventanas en mosaico pasan a flotante en 189,99 / 221,131 / 253,163 con la
  cascada automática, sin apilarse. `umbriel config validate` acepta los
  valores y recorta los fuera de rango.
- Binario `af15084668f2` instalado en `/usr/bin/umbriel`; falta cerrar sesión
  para que la sesión real use el tamaño configurable y la cascada.

### A14. Memoria de la disposición en modo mosaico (hecho)
- Cada modo de mosaico guarda su disposición al salir del escritorio y la
  recupera al volver. En dwindle se conservan las divisiones y sus
  proporciones; en master, las áreas y sus filas; en scrolling, las columnas y
  sus anchos. Funciona tanto en la ida y vuelta a Flotante como al cambiar
  entre dos modos de mosaico.
- Las ventanas abiertas mientras el escritorio estaba en Flotante se añaden
  después; las que se cerraron dejan su hueco y el diseño lo colapsa como
  cualquier cierre. Se implementa en `Workspace::rememberTilingLayout`,
  `restoreRememberedLayout` y `forgetViewInRememberedLayouts`, llamados desde
  `applyLayoutConfig` y `removeView`.
- Aceptación en Umbriel anidado: cuatro ventanas en dwindle vuelven a
  963,365 / 645,365 / 645,9 / 9,9 tras pasar por stacking; master vuelve
  idéntico; cerrar una en Flotante y abrir otra conserva los huecos del resto
  y coloca la nueva en el libre.

### A15. Redimensionar mosaico arrastrando el borde (hecho)
- Con Mod (Super) pulsado, un arrastre con el botón izquierdo que empieza a
  10 px o menos del borde de una ventana en mosaico, o en el hueco entre dos
  ventanas, redimensiona el reparto. En el centro de la ventana el mismo gesto
  sigue moviéndola. El puntero muestra el cursor de redimensionar en esa
  franja. Mod+clic derecho sigue redimensionando desde el tercio exterior.
- El cálculo vive en `tiledFrameBorderEdges` y `Cursor::tiledBorderTarget`,
  que busca la ventana más cercana aunque el puntero esté en el hueco;
  `hoverResizeEdges` usa la misma franja para que el cursor coincida con lo que
  hará el clic.
- Aceptación en Umbriel anidado (1280×720, mod = Alt en sesión anidada):
  en dwindle, arrastrar el borde de 630 a 800 deja las columnas en 796 y 456;
  arrastrar desde el centro del hueco (810) a 600 las deja en 586 y 666; en
  master, de 703 a 900 deja 886 y 366; un arrastre desde el centro sigue
  intercambiando la ventana.
- Binario `8d1317f9205c` instalado en `/usr/bin/umbriel` (sha256
  `a13ce3462695372c…`); falta cerrar sesión para estrenarlo.

### Incidencia: configuración de Umbriel restaurada
- Al recargar ALBA, `shell-mod-hold` y `shell-floating-defaults` podían correr a
  la vez y compartían el temporal `config.toml.shell-tmp`; uno movía el archivo
  mientras el otro escribía y `config.toml` quedó reducido a 13 líneas. Se
  restauró la copia completa (180 líneas) y se guardó una copia en
  `Shell/umbriel-config-backup.toml`.
- Ambos scripts usan ahora un cerrojo `flock` sobre `config.toml.shell-lock` y
  un temporal único de `mktemp`. Probado con 25 ejecuciones simultáneas: el
  archivo conserva sus 180 líneas y `umbriel config validate` lo acepta.

### A16. La barra sigue viva con Super pulsado (hecho)
- Con Mod mantenido, el compositor solo intercepta el botón izquierdo cuando
  el puntero está sobre el escritorio. Si el clic cae en un panel o en la capa
  superpuesta, el evento llega a la interfaz: el botón de modo del escritorio
  activo, los chips Flotante/Mosaico y el resto de la barra responden sin
  soltar Super.
- El cambio está en la condición de `Cursor::processButton`; el arrastre
  central y el redimensionado por borde siguen igual sobre las ventanas.
- Aceptación en anidado: con Alt pulsado (mod de la sesión anidada), pulsar el
  botón de modo de la píldora cambia el escritorio a stacking y, al pulsarlo
  otra vez, vuelve a dwindle restaurando la misma geometría.

### A17. Cada ventana vuelve a su hueco al volver a mosaicar (hecho)
- Al flotar una ventana de un modo de mosaico se guarda una copia del árbol o
  columnas de ese escritorio, incluida la propia ventana. Al volver a mosaicarla
  en el mismo escritorio y modo, se reconstruye la disposición y la ventana
  recupera su hueco, sus proporciones y su ancho de columna, en vez de añadirse
  al final.
- La reconstrucción solo se aplica si el resto de la disposición sigue igual:
  todas las demás ventanas del recuerdo siguen mosaicadas y no se ha añadido
  ninguna. Si algo cambió, la ventana se coloca como una nueva y no se rompe el
  mosaico actual.
- El recuerdo es por escritorio y por modo, y se borra al cerrar la ventana o
  al moverla a otro escritorio. Mientras la ventana está fijada, el recuerdo
  permanece en el escritorio de origen aunque la ventana siga al activo; se
  conserva si se vuelve allí y se desancla, y se borra si se desancla en otro
  escritorio. También sobrevive a una ida y vuelta por Flotante: una ventana que
  ya estaba flotante antes del cambio puede volver a su hueco al mosaicarla
  después.
- Aceptación en anidado (1280×720): en dwindle, flotar y devolver `dos` la
  devuelve a 645,9 y `tres` a 645,335; en master, `cuatro` vuelve a 708,9; en
  scrolling, `tres` vuelve a 9,9. Con una ventana nueva abierta mientras tanto,
  la devolución usa la inserción normal y el mosaico sigue coherente.
- Binario `43e5f7496f04` instalado en `/usr/bin/umbriel` (sha256
  `9aac59e71aaefd97…`); falta cerrar sesión para estrenarlo.

### A18. El cursor de redimensionar no se queda pegado (hecho)
- Con Mod pulsado, el cursor solo muestra la forma de redimensionar cuando el
  puntero está en el borde de un mosaico o en el hueco entre dos. Al pasar al
  escritorio vacío, a la barra o a un panel, vuelve al cursor normal o al del
  panel; ya no se queda con las flechas de redimensionar.
- La causa era doble: al no haber vista bajo el puntero se salía sin restaurar
  el cursor anterior, y el seguimiento del cursor se saltaba las zonas sin
  superficie. Ahora `updateInteractiveCursor` recibe si el puntero está sobre
  un panel, limpia el aviso cuando no hay borde y se recalcula también sobre
  huecos y paneles.
- Aceptación en anidado (946×1002): en el borde x=468 aparece el cursor
  horizontal; en el centro, la mano; en la barra, la mano del widget o la
  flecha. Las transiciones borde→barra y centro→barra no arrastran la forma
  anterior, y al soltar Super también se restaura.

### A19. El hueco guardado sobrevive mientras la ventana está fijada (hecho)
- Fijar una ventana la convierte en flotante y la hace seguir al escritorio
  activo. Su recuerdo de hueco se queda en el escritorio de origen, no se
  borra al adoptarla otro escritorio.
- Al volver al origen, desanclar la ventana o quitarle el modo flotante la
  devuelve a su hueco exacto, con las mismas proporciones. Si se desancla o se
  acopla en otro escritorio, el recuerdo se borra en todos los escritorios para
  que no vuelva después al hueco antiguo; al moverse allí se inserta como una
  ventana normal.
- Cerrar una ventana limpia su recuerdo en todos los escritorios y también los
  recuerdos de otras ventanas que la citaban, para no dejar punteros muertos.
- Aceptación en anidado (946×1002): fijar `dos`, ir y volver de otro escritorio
  y desanclar la devuelve a 478,9; fijar una ventana ya flotante y hacer dos
  idas y vueltas también recupera su hueco; desanclar en el segundo escritorio
  y volver hace que `dos` se inserte abajo (478,476), no en el hueco viejo.
  Cerrar `tres` mientras `dos` flota y volver a mosaicar `dos` no rompe el
  mosaico.
- Binario `43e5f7496f04` instalado en `/usr/bin/umbriel` (sha256
  `9aac59e71aaefd97…`); falta cerrar sesión para estrenarlo.

### A20. Las apps nuevas nacen con el tamaño y la cascada del modo Flotante (hecho)
- En un escritorio Flotante, una ventana que se abre ya no conserva el tamaño
  que pide la aplicación: toma `default_width_fraction` ×
  `default_height_fraction` del área útil y entra en la siguiente posición de
  la cascada, igual que las ventanas que llegan al cambiar de Mosaico a
  Flotante. Así una app nueva no aparece enorme ni tapando el resto.
- El primer posicionamiento de una ventana recién mapeada es el único que
  aplica el tamaño por defecto. Un tamaño puesto por una regla de ventana, o
  recordado de una flotación anterior, sigue mandando. Los diálogos y ventanas
  transitorias conservan su tamaño y se centran sobre su padre; las reglas de
  posición explícitas se respetan.
- Aceptación en anidado (946×436 útil): la primera ventana nueva quedó en
  568×262 en 189,87 y la segunda en 221,119, los mismos huecos que produjo
  cambiar el escritorio de Mosaico a Flotante con tres ventanas. Una regla con
  tamaño 300×200 conservó 300×200; una regla solo de posición mantuvo el
  tamaño por defecto (568×262) en 40,60. Abrir una ventana en un escritorio en
  mosaico siguió insertándola como baldosa normal.
- Nota: las pruebas de integración de `tests/harness/checks` que asumen el
  tamaño del cliente al abrir en stacking necesitan actualizarse; el harness
  no forma parte del flujo de aceptación actual.
- Binario `a4b9b8fdd314` instalado en `/usr/bin/umbriel` (sha256
  `98591e442ac8b635…`); falta cerrar sesión para estrenarlo.

### A21. Cambiar la barra de ventanas no saca las ventanas del mosaico (hecho)
- Alternar «Barra de ventanas» entre Flotante e Integrado recarga
  `[appearance.title_bar]`. Esa recarga marcaba `workspaceLayout` y
  `refreshLayouts()` borraba el modo de escritorio elegido con
  `workspace-set-layout`, así que todos los escritorios en mosaico volvían al
  modo configurado (stacking por defecto) y sus ventanas se convertían en
  flotantes.
- `ConfigEffects` distingue ahora entre rehacer la disposición y reafirmar el
  modo configurado. Solo las fuentes que deciden el modo (`[layout] mode`,
  reglas de escritorio, inventario de escritorios) borran el override; los
  cambios cosméticos (barra de título, colores, bordes, pestañas) conservan el
  modo actual y solo lo recolocan. Cambiar `[layout.stacking]` tampoco borra el
  modo, para que ajustar el tamaño flotante no deshaga el mosaico.
- Aceptación en anidado: una ventana en dwindle siguió en mosaico tras
  Flotante→Integrado→Flotante; cambiar `[layout.stacking]` la mantuvo en
  mosaico; cambiar `[layout] mode` a stacking sí la pasó a flotante.
- Binario instalado en `/usr/bin/umbriel` (sha256 `d3f5effaad771b37…`); falta
  cerrar sesión para estrenarlo.

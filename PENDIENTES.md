# ALBA · Traspaso para la siguiente sesión

Documento corto para continuar sin reexplicar el proyecto. El detalle largo está
en `PLAN.md` (plan y aceptación) y `CONTEXTO.md` (historial). **No leas
`CONTEXTO.md` entero**: busca solo la sección que necesites.

## Estado al cerrar esta sesión

- **Binario nuevo ya en uso.** `/usr/bin/umbriel` es `d3f5effaad771b37` y la
  sesión se reinició a las 17:49, así que el arreglo de A7 (cambiar la barra de
  ventanas ya no devuelve los mosaicos al modo configurado) está cargado. A5
  confirmado en real. La cadena de versión sigue diciendo `2ae0007635ec` por
  cómo se compila, pero el proceso arrancó después del binario nuevo.
- **C2 y C5 completados.** Perfiles de energía, importar/editar VPN, clima
  manual, demonio de alarmas y temporizador persistente. Se instaló
  `network-manager-openvpn` (necesario para `.ovpn`) y se habilitó
  `alba-alarms.service`. No se tocó el fork; el binario nuevo ya está
  cargado (ver el punto anterior).
- El usuario confirmó que la restauración de A6 funciona. Si dudas, comprueba:
  `umbriel --version` y `ps -o etime= -p $(pgrep -x umbriel)`; si el proceso es
  anterior al binario, hay que cerrar sesión y volver a entrar.
- Fork en `~/umbriel-fork`, rama con 24 commits sobre `b6c4b7d`, árbol limpio.
  Parche regenerable en `~/Documents/Alba/umbriel-fork.patch` (50 archivos).
- **Plataforma decidida: solo Umbriel sobre Debian.** Hyprland y cualquier otro
  compositor quedan descartados; no se mantiene ni se prueba ese backend. El
  código antiguo de `HyprlandBackend.qml` puede quedarse como legado, pero no
  es objetivo de trabajo. Tras la próxima instalación limpia se eliminará si
  estorba.
- Copia de seguridad del binario original: `/usr/bin/umbriel.stock-0.1.0`.
- ALBA vive en `~/Documents/Alba` y está enlazado desde
  `~/.config/quickshell/alba`. Se recarga sola al guardar QML, salvo el pragma
  `UseQApplication` de `shell.qml`, que exige reiniciar el proceso.
- **Guía de instalación limpia preparada.** `INSTALACION.md` reúne hardware,
  repositorios, paquetes, compilación del fork, configuración de Umbriel,
  portales, sudoers, SDDM y copias de seguridad. Los archivos que vivían fuera
  del proyecto están guardados en `install/` (`bin/`, `config/`, `systemd/`,
  `sudoers/`, `apt/` y `packages.txt`).
- **Instalador automático (E1).** `install.sh` instala repositorios, paquetes,
  configuración de usuario, sudoers y alarmas; `scripts/install-umbriel-fork.sh`
  clona el fork si hace falta, aplica el parche, compila e instala con `mv`
  atómico. Probado con `--dry-run` y con una compilación completa desde un clon
  limpio. Falta ejecutarlo de principio a fin en un Debian recién instalado.
- **Veredicto para uso principal:** sí en este equipo, con dos reservas: B3
  sigue sin probar y el instalador aún no se ha probado en limpio. B5 sí es
  comprobable aquí porque el AX210 tiene Wi-Fi y Bluetooth. Lo pendiente de
  diseño (reloj, A4, VPN, iconos del escritorio, perfiles personalizados y
  portátiles) no bloquea el uso diario.

### Hecho en la sesión del 2026-11-05

- **C2 · Perfiles de energía en la batería.** El icono de batería de la barra
  ahora se dibuja como el mockup: contorno, pista, relleno, punta, rayo amarillo
  y barrido del contorno al cargar. En este equipo no hay batería, así que el
  icono sigue visible con el rayo de corriente y sin porcentaje. Al pulsarlo se
  abre un panel con «Ahorro / Equilibrado / Rendimiento», el estado y la
  descripción de cada modo; en Ahorro el icono se tiñe de celeste y los avisos
  de batería (naranja al 20 %, rojo al 10 %) tienen prioridad. La energía vive
  solo aquí: Ajustes ya no muestra esa sección. Además del clic, hay IPC:
  `qs ipc -c alba call battery toggle` (también `openPanel`, `closePanel`,
  `profile`, `status`). Verificado en real: el panel aparece, cambia el perfil
  y el icono pasa a celeste en Ahorro. Falta el clic con ratón físico.
- **C2 · Energía solo en la batería.** A petición del usuario se quitó la
  sección «ENERGÍA» de Ajustes: los tres perfiles se cambian desde el panel del
  icono de batería, que es donde se consultan el estado y el modo actual. El
  IPC `power profile` se mantiene para atajos y pruebas. Verificado en real:
  performance → balanced → power-saver y vuelta a balanced.
- **Música · Portada de borde a borde.** La carátula del widget de la barra
  pasó de 22 px con relleno a 34 px (todo el alto de la píldora), pegada al
  borde izquierdo. El ancho del texto se recalcula para que el estirado con
  Super siga cuadrando. Verificado en real con una pista reproduciéndose.
- **Música · Portada con la forma del widget.** La imagen se recorta con
  `MultiEffect` y una máscara del mismo radio que la píldora, así que sus cuatro
  esquinas siguen la curva y no asoma ningún pico cuadrado. Verificado en real.
- **Tráfico de red · Ancho fijo y cifras más juntas.** El botón mide siempre
  50 px, de modo que al pasar de pocos a muchos dígitos no empuja a los demás
  controles. La cifra baja a 9 px, la unidad sube con espaciado negativo y las
  flechas quedan más cerca del número y de la unidad. Verificado en real con
  tráfico de 825 KB/s.
- **Escritorios fijos y números ocupados.** Umbriel estaba en modo dinámico,
  así que solo existían dos o tres escritorios: elegir el 4–9 seleccionaba el
  último disponible y «Mover a escritorio 9» terminaba en el 2. La configuración
  de Umbriel fija ahora nueve (`[output."HDMI-A-1"] workspaces = 9`). Además, el
  número de cada escritorio se ilumina con el acento si tiene cualquier ventana,
  incluidas las minimizadas o en el scratchpad. Verificado en real: cambio al 9
  y movimiento de una ventana al 9, con el número 9 encendido; la ventana se
  devolvió a su escritorio. Si cambia el conector (portátil o instalación
  limpia), hay que repetir esa sección con el nombre nuevo (`eDP-1`, etc.).
- **Verificación en real del usuario.** Casi todo lo pendiente quedó probado y
  funciona. B3 (captura y uso compartido desde Firefox/X11) queda aparcado por
  decisión del usuario. El único fallo encontrado fue mover ventanas a los
  escritorios 4–9, corregido con el inventario fijo de nueve.
- **C2 · VPN: importar y editar.** La vista VPN gana «Importar .ovpn»
  (KDialog/Zenity y `nmcli connection import type openvpn`) y un engranaje por
  perfil para cambiar el nombre y «Conectar al iniciar», con borrado en dos
  pasos. Requiere `network-manager-openvpn`, ya instalado; sin él nmcli
  responde «unknown VPN plugin» y la vista lo explica. Verificado por IPC:
  importar un `.ovpn` de prueba, renombrarlo con arranque automático
  desactivado y borrarlo; la lista se actualiza sola. Falta probar los clics
  con ratón físico. **El usuario quiere más opciones de VPN; las dirá más
  adelante** (no improvisar cuáles).
- **B3 · Portales: captura y uso compartido.** Faltaba el backend del diálogo
  de permiso: `umbriel.portal` implementa ScreenCast y Screenshot, pero no
  `org.freedesktop.impl.portal.Access`, así que `xdg-desktop-portal` se quedaba
  esperando («Failed to show access dialog: Timeout was reached») y una vez
  terminó en SEGV. `~/.config/xdg-desktop-portal/portals.conf` mapea Access a
  GTK y ya funciona. Verificado: la captura devuelve un PNG real y el flujo de
  ScreenCast abre el selector de Umbriel, deja elegir pantalla o ventana y
  `Start` devuelve un stream de HDMI-A-1 a 1920×1080. Falta la prueba final
  desde Firefox y desde una app X11. El selector y el diálogo de permiso son
  de los portales (en inglés); el resto de ALBA sigue en castellano.
- **B2 · No bloquear mientras hay reproducción.** La barra crea un
  `IdleInhibitor` sobre su propia superficie y lo activa con
  `MusicState.playing`, así que `swayidle` no bloquea mientras suena música o
  vídeo (MPRIS). Verificado: con un reproductor MPRIS en «Playing», un
  `swayidle` de prueba de 10 s no disparó; al cerrarlo, uno de 8 s sí disparó.
- **C5 · Ubicación manual del clima.** `WeatherState` consulta la ciudad
  guardada en `weatherPlace=`; si está vacía sigue usando wttr.in por IP. En
  la pestaña Clima, «Cambiar» abre un campo con «Aplicar» (Intro también
  aplica). Verificado en real: Madrid mostró su tiempo y al vaciar el campo
  volvió a la detección automática.
- **C5 · Alarmas y temporizador con el shell cerrado.**
  `scripts/alba-alarms` y la unidad de usuario `alba-alarms.service`
  (habilitada) leen `alarms.conf`; no duplican avisos si `qs` está abierto y,
  si no lo está, usan `notify-send` o un diálogo de KDialog/Zenity. El
  temporizador escribe `deadline=` en `~/.config/alba/timer.conf`; el demonio
  lo termina con el shell cerrado y el panel lo restaura al volver. Verificado:
  aviso de alarma y de temporizador, restauración de una cuenta atrás y
  limpieza del archivo al vencer.
- **Pestañas del reloj: rediseño pendiente.** Las pestañas actuales
  (Calendario/Clima/Alarmas/Temporizador) no convencen al usuario; las
  rediseñará él más adelante. No tocarlas por iniciativa propia.
- **D1 · El escritorio queda para el final.** El usuario prefiere no seguir con
  iconos del escritorio por ahora; la fase 2 (recolocar, renombrar, papelera,
  menú contextual) se retoma al final, después del resto de bloques.
- **B4 · Bandeja usable.** Los iconos de bandeja se agrupan en un desplegable
  «Bandeja del sistema» que se abre con un chevron en la barra, así que no
  ocupan sitio permanente. La barra trataba el icono como nombre del tema, pero
  Quickshell lo entrega como `image://icon/...`; por eso antes no se veía
  ninguno. Ahora se usa la fuente tal cual. Dentro del panel, clic izquierdo
  activa (o abre el menú si la app solo tiene menú), derecho abre el menú,
  central lanza la acción secundaria y la rueda reenvía el paso. Los menús
  necesitan `//@ pragma UseQApplication` en `shell.qml`; verificado en anidado y
  en real con KDE Connect.
- **C3 · Brillo y OSD.** Las teclas bajan o suben el brillo en pasos de 5 % y
  el OSD muestra el sol y el porcentaje. Verificado por IPC en anidado; falta
  la tecla física.
- **C3 · El brillo también se lee del monitor.** `ddcutil` no avisa cuando el
  brillo se cambia con los botones del monitor, así que ALBA relee el valor
  cada 3 s y actualiza el deslizador. La lectura se salta mientras el shell
  escribe o está detectando. Verificado en real: se puso el monitor a 40 por
  fuera, ALBA lo adoptó y la siguiente pulsación de brillo bajó a 35.
- **A7 · Cambiar la barra de ventanas no altera el mosaico.** La recarga por
  `[appearance.title_bar]` ya no borra el modo de escritorio elegido en tiempo
  de ejecución (`workspace-set-layout`): solo se rehace la disposición con el
  modo actual. Una recarga que cambie de verdad el modo configurado
  (`[layout] mode` o reglas de escritorio) sí lo reafirma. Verificado en
  anidado: Flotante→Integrado→Flotante con una ventana en dwindle la mantuvo
  en mosaico, y cambiar `mode` a stacking sí la pasó a flotante.
- **D1 · Soltar archivos en el escritorio.** `DesktopIcons` acepta arrastres
  desde Dolphin u otro gestor. `scripts/alba-desktop-drop` mueve los archivos
  de la misma unidad y copia los de otra, añade « (1)», « (2)»… si el nombre
  existe y nunca sobrescribe. El script está probado por separado; falta
  probar el arrastre real con el ratón.
- **C4 · Fondo por color.** Ajustes → Fondo de pantalla → «Color de fondo»
  (seis muestras y `#RRGGBB`). Se guarda `wallpaperColor=` y sobrevive al
  reinicio. `alba-system-theme` verificado con GTK 3/4 y KDE.
- **D3 · Vista general de Umbriel.** `Mod+Tab` abre/cierra la vista general;
  los controles de ALBA pasan a `Mod+Shift+Tab`. ALBA escucha el evento
  `overview` y cierra sus paneles al abrirse. Verificado con Alt+Tab en anidado.
- **Puente XWayland desactivado.** `xwaylandvideobridge` servía para que las
  apps X11 (Discord, Zoom, etc.) pudieran capturar la pantalla por PipeWire;
  abría una ventana-herramienta que no debe verse. Se desactivó el autostart
  con `~/.config/autostart/org.kde.xwaylandvideobridge.desktop` (`Hidden=true`)
  y se cerró el proceso. El paquete sigue instalado; para volver a usarlo,
  borrar ese archivo y lanzarlo.
- **A5 · La ficha minimizada vuelve a su escritorio.** La causa era un índice en
  base 0: `scratchpad_return_index` devolvía `0` para el escritorio 1 (leído
  como «sin origen») y `1` para el 2. Umbriel publica ahora base 1 y ALBA
  resuelve también por nombre. No se persiste geometría por app: descartado
  como curiosidad.
- **C1 · El orden de los controles ya se guarda.** `settings.conf` incluye
  `barControls=` y `centerOrder=`; Ajustes tiene «Restablecer».
- **A20 · Las ventanas nuevas nacen en cascada.** En un escritorio Flotante
  (stacking), una app que se abre toma el mismo tamaño por defecto que tendría
  al cambiar el escritorio de Mosaico a Flotante (`default_width_fraction` ×
  `default_height_fraction`) y entra en la siguiente posición de la cascada.
  Antes conservaba el tamaño que pedía la app y solo se colocaba en cascada.
  Un tamaño explícito de regla o recordado de una flotación anterior sigue
  ganando; los diálogos mantienen su tamaño y se centran sobre su padre.
  Verificado en anidado: dos ventanas nuevas quedaron en 568×262 en 189,87 y
  221,119, exactamente los mismos huecos que al cambiar Mosaico→Flotante.
- **A18 · El cursor vuelve a la normalidad.** Con Super pulsado, el cursor de
  redimensionar ya no se queda pegado al salir del borde de una ventana hacia
  el escritorio o la barra. El compositor recalcula la forma del cursor sobre
  cualquier zona, no solo al entrar en otra superficie, y los paneles conservan
  su propio cursor. Verificado en anidado: borde → cursor horizontal, centro →
  mano, barra → mano o flecha, y las transiciones borde→barra y centro→barra
  sin arrastrar el cursor anterior; al soltar Super también se restaura.
- **A19 · El hueco sobrevive mientras la ventana está fijada.** Al fijar una
  ventana flotante, su hueco guardado permanece en el escritorio de origen
  aunque la ventana siga al escritorio activo. Si se vuelve al origen y se
  desancla o se quita el modo flotante allí, recupera su hueco exacto. Si se
  desancla o se acopla en otro escritorio, el recuerdo se borra para que no
  vuelva luego al hueco antiguo. Al cerrar la ventana se limpian los recuerdos
  de todos los escritorios, incluidos los de otras ventanas que la citaban.
  Verificado en anidado: ida y vuelta con fijado restaura píxeles exactos;
  desanclar en otro escritorio y volver usa la inserción normal; cerrar una
  ventana capturada mientras otra flota no rompe el mosaico.
- **A16 · Barra utilizable con Super.** El clic izquierdo con Mod solo se
  intercepta sobre el escritorio; los paneles y la capa superpuesta reciben el
  clic. El botón de modo de la píldora y los chips Flotante/Mosaico funcionan
  sin soltar Super. Verificado en anidado: ida y vuelta con el botón y
  geometría idéntica.
- **A17 · Hueco por ventana al flotar.** `Workspace` guarda el árbol o columnas
  al flotar una ventana y lo reconstruye al mosaicarla de nuevo, siempre que el
  resto de la disposición no haya cambiado. Funciona en dwindle, master y
  scrolling; con ventanas nuevas o cerradas cae en la inserción normal. El
  recuerdo se borra al cerrar la ventana o moverla de escritorio. Verificado en
  anidado: `dos` vuelve a 645,9, `cuatro` a 708,9 y `tres` a 9,9.
- **A14 · Memoria de la disposición en mosaico.** Cada modo de mosaico guarda
  su árbol/columnas y proporciones al salir y los recupera al volver. Ida y
  vuelta a Flotante devuelve cada ventana a su hueco; también entre dwindle y
  master. Las ventanas abiertas mientras tanto se añaden al final y las
  cerradas dejan un hueco que se colapsa. Verificado en anidado con cuatro
  ventanas: geometría idéntica tras el viaje por stacking.
- **A15 · Redimensionar mosaico con el borde.** Con Super pulsado, arrastrar
  con el botón izquierdo a 10 px o menos de un borde, o del hueco entre dos
  ventanas, redimensiona; en el centro se sigue moviendo. El cursor de
  redimensionar aparece en esa franja. Verificado en dwindle (796/456),
  desde el hueco (586/666) y en master (886/366), además de que el arrastre
  central sigue moviendo.
- **Incidencia de configuración.** Los scripts `alba-mod-hold` y
  `alba-floating-defaults` compartían `$cfg.alba-tmp` y, al coincidir,
  truncaron `~/.config/umbriel/config.toml` a 13 líneas. Se restauró desde una
  copia completa; hay respaldo en `Documents/Alba/umbriel-config-backup.toml`.
  Ahora usan `flock` y `mktemp`, probado con 25 ejecuciones simultáneas.
- **A13 · Tamaño y cascada de ventanas flotantes.**
  `[layout.stacking]` gana `default_width_fraction`, `default_height_fraction`
  y `cascade_step`. Flotar una ventana de un mosaico ya no conserva el tamaño
  del mosaico: la primera vez usa el 60 % del área útil y se centra. Si la
  ventana ya flotó o se redimensionó, conserva su tamaño. Cambiar un escritorio
  entero de mosaico a flotante coloca las ventanas en cascada en vez de
  apilarlas. Ajustes → «Tamaño de ventanas flotantes» (40–80 %, pasos de 5) y
  «Separación en cascada» (Auto o 8–96 px); se guarda como
  `floatingSizePercent` y `floatingCascade` y lo aplica
  `scripts/alba-floating-defaults`. Verificado en anidado: 0,6 da 568×298 en
  una salida de 946×496; 0,5 y 48 px dan 473×248; tres ventanas en mosaico se
  colocan en 189,99 / 221,131 / 253,163. Binario `af15084668f2` instalado;
  falta cerrar sesión.
- **A12 · Retardo ajustable, música estable y reloj más legible.**
  Ajustes → «Retardo al mantener Super» (100–1000 ms, pasos de 50) guarda
  `superHoldMs` y escribe `[input] mod_hold_delay_ms` en Umbriel mediante
  `scripts/alba-mod-hold`. En anidado se comprobó con 600 ms: 300 ms sin velo,
  900 ms con velo; un toque de 200 ms no atenúa. Al recargar a 200 ms, 350 ms
  ya atenúa. La música ya no se desplaza ni tiembla al mantener Super: se
  corrigió el ciclo de tamaño, el asa salió de la fila de contenido y el
  `Loader` actualiza su ancho preferido; 140 y 300 px se aplican en vivo. El
  reloj deja la izquierda en dos líneas (hora y día de la semana) y la derecha
  en tres (día arriba, mes en medio, año abajo), con la barra a 44 px. Falta
  instalar el binario nuevo y probar el ajuste con el compositor nuevo tras
  cerrar sesión.
- **A11 · Gesto de Mod con retardo, barra arriba/abajo y música ajustable.**
  Mantener Mod ya no se confunde con un toque: Umbriel espera 320 ms antes de
  atenuar el contenido y aislar el puntero (verificado en anidado: 150 ms sin
  velo, 600 ms con velo del 28 %, toque de 100 ms sin velo). Ajustes →
  «Posición de la barra» permite arriba o abajo y recoloca paneles, OSD y
  reserva de espacio. La píldora de música tiene un asa de estirado mientras
  se mantiene Mod; guarda `musicWidth` y un doble clic vuelve al ancho
  automático. Falta probarlo con el ratón físico en la sesión real.
- **A10 · Modo ventanas sin interacción.** Al mantener Mod, Umbriel deja de
  enviar puntero, rueda, toque y movimiento relativo al contenido de las
  ventanas; desactiva el bloqueo de puntero del cliente y tiñe el contenido
  con un velo oscuro para indicar que no se puede interactuar. Las píldoras
  nativas, la barra y los paneles siguen activos, y arrastrar o redimensionar
  con Mod sigue funcionando. Verificado en Umbriel anidado con
  `seat-log-client`: al mantener Alt el cliente recibe `pointer-unlocked` y
  `leave`, y ningún `relative-motion`; al soltar vuelve a entrar y el lock se
  reactiva.
- **A7 · Barra de ventanas con dos estilos.** «Flotante» dibuja dos píldoras
  nativas separadas (título a la izquierda, botones a la derecha) que aparecen
  solo con Mod; «Integrado» deja la franja a ancho completo siempre visible con
  el contenido debajo. Se alterna en caliente desde Ajustes y el espacio de
  trabajo se recoloca sin reiniciar; en flotantes el contenido se ajusta para
  que el marco exterior no se mueva. El botón de mover usa `#`. Verificado en
  Umbriel anidado con Alt y alternando en ambos sentidos.
- **Barra sin botones.** Los widgets de estado no pintan un fondo propio en
  reposo: comparten el de la barra y solo se tiñen al pasar el ratón, como el
  icono de energía del mockup. La ficha del escritorio actual conserva ese
  mismo tinte para marcar dónde estamos.
- **A8 · Fondo de pantalla.** Ajustes → «Fondo de pantalla» permite elegir una
  imagen, ver la miniatura y quitarla. Se dibuja en una capa `Background` por
  pantalla, debajo de iconos y ventanas, y se guarda en `settings.conf`.
- **D1 fase 1 · Iconos del escritorio.** `DesktopState.qml` y
  `DesktopIcons.qml`: cuadrícula de `~/Desktop` debajo de las ventanas, con
  carpetas, archivos, miniaturas de imágenes y lanzadores `.desktop` con su
  nombre e icono. Un clic selecciona, doble clic abre. Probado con una carpeta
  (abrió Dolphin) y con Firefox ESR.
- **A4 primera versión · Volumen por aplicación.** El centro de control →
  Volumen lista «APLICACIONES CON AUDIO», una fila por flujo de PipeWire, con
  silencio y deslizador propio. Verificado que aparece el flujo de Firefox; el
  arrastre con ratón físico queda pendiente.

- **Filtro de pantalla nativo.** La luz nocturna y la atenuación extra ya no
  son una capa QML: Umbriel aplica `[display]` como shader de salida completo.
  Cubre barra, paneles y ventanas, y la luz nocturna multiplica el color para
  no lavar el negro. Verificado en Umbriel anidado con captura.
- **Escritorio activo.** La ficha del escritorio actual lleva el mismo fondo
  que al pasar el ratón y es la única con el acento a plena intensidad; las
  demás quedan atenuadas. Si no tiene apps, muestra su número, así que nunca
  parece un hueco vacío. En Umbriel hay un escritorio «siguiente» siempre
  creado: antes su número también salía en el acento y confundía.
- **Cerrar sesión.** El menú de energía lanzaba `hyprctl dispatch exit` en
  todos los compositores; en Umbriel ese comando no existe y el botón no hacía
  nada. Ahora `CompositorState` expone `sessionQuit` y `lockScreen` (Umbriel:
  `session-quit skip-confirmation`).
  Reiniciar y apagar siguen usando `systemctl`. Verificado el cierre en
  Umbriel anidado.
- **Barra uniforme.** Los iconos de estado usan el mismo acento (atenuado
  cuando están apagados) en vez de mezclar blanco, gris y colores de texto.

## Reglas para no repetir tiempo ni errores

1. **No re-diagnostiques lo ya cerrado.** A6 (fichas minimizadas y
   restauración) está hecho y verificado. Si algo falla ahí, es una regresión
   nueva: revisa `ScratchpadManager::restoreView` en
   `~/umbriel-fork/src/workspace/scratchpad.cpp`.
2. **Restaurar nunca con `window-focus`.** Enfocar una ventana del scratchpad
   muestra el pad completo. Usa siempre `umbriel restore-window <id>`
   (comando de primer nivel, **no** va dentro de `umbriel msg`).
3. **Cambios del compositor: probar en Umbriel anidado** antes de instalar:
   ```sh
   sed 's#^autostart = .*#autostart = []#' ~/.config/umbriel/config.toml > /tmp/opencode/test.toml
   cd /tmp/opencode && WAYLAND_DISPLAY=wayland-0 nohup ~/umbriel-fork/build/umbriel -c /tmp/opencode/test.toml -s kitty >/tmp/opencode/nested.log 2>&1 &
   export UMBRIEL_SOCKET=/run/user/1000/umbriel-wayland-1.sock
   ```
   Captura con `WAYLAND_DISPLAY=wayland-1 grim /tmp/opencode/x.png`. Al
   terminar, cierra el compositor anidado con
   `UMBRIEL_SOCKET=/run/user/1000/umbriel-wayland-1.sock umbriel msg session-quit skip-confirmation`
   (no uses `pkill -f umbriel-test.toml`: el patrón también coincide con la
   propia orden de la shell y la mata).
   Para ver el cromo superpuesto, `wtype -M alt -s 2500 x` mantiene Alt
   pulsado durante 2,5 s; captura mientras duerme. Si sueltas antes, la barra
   desaparece y la captura sale sin ella.
4. **El puntero virtual (`wlrctl`) no sirve para clics en capas de ALBA** en la
   sesión real: mueve el cursor y revela la barra, pero los clics no llegan a
   las layer surfaces. Los clics de barra/paneles se validan con ratón físico o
   con `qs ipc -c alba call ...`.
5. **Instalar el fork solo con `mv` atómico** (no se puede sobrescribir el
   binario en uso):
   ```sh
   cd ~/umbriel-fork && ninja -C build
   sudo cp build/umbriel /usr/bin/umbriel.new && sudo mv -f /usr/bin/umbriel.new /usr/bin/umbriel
   git diff b6c4b7d > ~/Documents/Alba/umbriel-fork.patch
   ```
   La contraseña de sudo está en `~/.config/alba/credenciales` (modo 600).
   Tras instalar, **cerrar sesión y volver a entrar**: el compositor en marcha
   no cambia de binario.
6. **No dejes `console.log` de depuración** en los QML. Comprueba el log con:
   `L=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1); grep -aE "TypeError|ReferenceError|is not defined|SyntaxError" "$L"`.
7. **`umbriel config-replace <archivo>` borra los layouts por escritorio.** Si
   lo usas, reaplica con `qs ipc -c alba call windows mode <n> <modo>`.
8. Todo en español, iconos reales, sin emoji. Nada de texto explicativo visible
   en la interfaz.

## Tareas, en orden

### 1. Cerrar la verificación de A6 en la sesión real (5 min)
Con ratón físico:
- Minimizar una ventana en mosaico y otra flotante. La ficha debe seguir en la
  barra, atenuada al 40 % (85 % al pasar el ratón), en su escritorio de origen.
- Pulsar la ficha: la ventana vuelve visible y enfocada, sin revelar el resto
  del scratchpad.
- Repetir desde el centro de control (vista Compositor → Restaurar).
- Fijar una ventana (`Fijar`), comprobar que aparece en todos los escritorios y
  que al desanclar cae en el escritorio activo.
- Comprobar indicadores `.wc.active` en Fijar/Flotar/Maximizar y el selector
  «Mover» → 1–9.
Si algo falla: anótalo con nombre de ventana, escritorio y comando usado, y
adjunta captura. No abras una investigación larga sin evidencia.

### 1b. Verificar en real la barra de ventanas y el fondo (5 min)
Tras cerrar sesión y volver a entrar:
- Mantener Mod: la barra de ALBA aparece y, sobre cada ventana, dos píldoras
  nativas separadas: icono y título a la izquierda, botones a la derecha. El
  contenido no se desplaza. El botón de mover muestra `#`.
- Soltar Mod: los controles desaparecen y la ventana recupera su contenido
  completo. Un toque corto sigue abriendo el lanzador.
- Ajustes → «Barra de ventanas»: alternar Flotante e Integrado y comprobar que
  la ventana se recoloca sin cerrar sesión ni reiniciar el compositor; el marco
  exterior no debe saltar.
- Barra: los iconos de estado y el escritorio activo no deben tener un fondo de
  botón en reposo, solo el tinte al pasar el ratón; todos los iconos deben
  compartir el mismo acento.
- Ir a un escritorio vacío: su ficha debe mostrar el número, no quedarse muda.
- Luz nocturna y atenuación extra: deben afectar también a la barra, paneles y
  lanzador, y la luz nocturna no debe lavar el negro. Comprobarlo con una
  ventana clara y con el centro de control abierto.
- Ajustes → «Fondo de pantalla»: elegir una imagen, ver que aparece detrás de
  los iconos y quitarla.
- Abrir una carpeta del escritorio con doble clic y una imagen; comprobar que
  no hay iconos duplicados en varios monitores.
- Centro de control → Volumen: con música o vídeo reproduciendo, mover el
  deslizador de la fila de la app y comprobar que cambia solo ese flujo.

### 1c. Comprobar los arreglos nuevos (3 min)
- **Barra de ventanas:** con al menos una ventana en mosaico, alternar
  «Flotante» e «Integrado» en Ajustes. La ventana debe seguir en mosaico y solo
  recolocarse. El binario nuevo ya está cargado.
- **Brillo:** cambiar el brillo con los botones físicos del monitor y esperar
  unos segundos; el deslizador de ALBA debe reflejar el valor. Después subir o
  bajar desde el shell y comprobar que el monitor lo sigue.
- **Escritorio:** arrastrar un archivo desde Dolphin a una zona libre del
  escritorio y comprobar que aparece. Arrastrar dos con el mismo nombre no debe
  sobrescribir ninguno.

### 1d. Comprobar C2 y C5 con ratón (4 min)
- Barra → icono de batería (sin porcentaje en este equipo): abrir el panel,
  pulsar Rendimiento y comprobar `powerprofilesctl get`; volver a Equilibrado.
  En Ahorro el dibujo de la batería debe teñirse de celeste. Cerrar con Escape
  o pulsando fuera. Ajustes ya no muestra perfiles de energía.
- Red → VPN → «Importar .ovpn», elegir un archivo; abrir el engranaje, cambiar
  el nombre y el arranque automático, guardar y borrar el perfil.
- Reloj → Clima → «Cambiar», escribir una ciudad y pulsar Aplicar; vaciar y
  aplicar para volver a la detección por IP.
- Reloj → Alarmas: programar una para el minuto siguiente, cerrar ALBA
  (`qs -c alba kill`) y comprobar que el demonio avisa y suena. Arrancar un
  temporizador, cerrar ALBA y volver a abrirla: debe seguir la cuenta atrás.

### 2. A5 · Persistencia de ventanas (hecho)
- Causa real: Umbriel publicaba `scratchpad_return_index` en base 0 (la primera
  ventana devolvía `0`, que ALBA interpretaba como «sin origen»; la del
  escritorio 2 devolvía `1`, un escritorio antes). Al reiniciar ALBA se perdía
  el mapa en memoria y la ficha desaparecía de la barra, aunque la ventana
  siguiera en el scratchpad y se pudiera restaurar desde Ajustes.
- Arreglo en Umbriel: `ScratchpadManager::returnWorkspaceIndexFor` ya no trata
  el índice 0 como ausencia (usa el nombre vacío) y el IPC publica
  `scratchpad_return_index` en base 1, igual que el campo `index` de
  `workspaces`. Documentado en `docs/user/ipc.md`.
- Respaldo en ALBA: `UmbrielBackend.qml` resuelve primero
  `scratchpad_return_name` a índice con `workspaceIndexByName`, así también
  funciona con binarios antiguos.
- No se guarda `windows.json` ni geometría por app. **Curiosidad descartada:**
  recordar la geometría de cada app entre sesiones choca con el tamaño por
  defecto de A20 y con las reglas de ventana de Umbriel; no se hará.
- Verificado en anidado y confirmado por el usuario en la sesión real: tras
  minimizar, reiniciar ALBA y consultar `windows status`, la ventana aparece
  con `origin=1` y la ficha sigue en su escritorio. Restaurar funciona.

### 3. C1 · Persistir el orden de controles (hecho)
- `BarState.qml` guarda ahora `defaultControls` y `defaultCenterOrder`, valida
  las listas y expone `restore()` y `resetLayout()`.
- `SettingsState.qml` escribe `barControls=` y `centerOrder=` en
  `settings.conf`, los lee al arrancar y guarda cuando cambian.
- Ajustes → «Orden de los controles» → «Restablecer» vuelve a los defaults.
- Verificado en anidado con `barControls=cpu`: tras reiniciar ALBA, la barra
  mostró solo ese control y el centro recibió el resto. Falta probar en real
  el reordenado con ratón y «Restablecer».

### 4. B4, C3, C4 y D3 (hecho)
- B4: la barra muestra un chevron cuando hay apps y «Bandeja del sistema» abre
  un panel con sus iconos. Cada uno conserva activar, menú con clic derecho,
  acción secundaria y rueda; el panel cierra al pulsar fuera, Escape, abrir otro
  panel u ocultarse la barra. `UseQApplication` activo. Verificado en anidado y
  en real con KDE Connect; al cerrar la app de prueba desaparece el chevron.
- C3: OSD de brillo con paso del 5 %. Falta la tecla física.
- C4: fondo por color con muestras y `#RRGGBB`; GTK/KDE verificados en real.
- D3: `Mod+Tab` abre la vista general de Umbriel y ALBA cierra sus paneles al
  recibir el evento `overview`; los controles de ALBA pasan a `Mod+Shift+Tab`.
  Verificado en real con Super+Tab.

### 5. B1 · Pruebas físicas de teclado y ratón (S)
- Teclado `es` y cambio de layout desde Ajustes.
- Toque de `Mod` abre el lanzador; mantener `Mod` muestra controles; un atajo
  como `Mod+Return` **no** debe abrir el lanzador al soltar.
- `Mod+Tab` abre la vista general de Umbriel; `Mod+Shift+Tab` fija los
  controles de ALBA; `Mod+Shift+W`, `Mod+1..9`.
- Teclas de volumen, brillo y silencio del micrófono.
- Ratón físico en barra, menú contextual y centro de control.
- Aceptación: cada punto probado y anotado como OK/fallo en `PLAN.md` (B1).

### 6. B3–B5 · Servicios reales (M)
- B3: `xdg-desktop-portal-umbriel`; compartir una ventana concreta desde
  Firefox y desde una app X11. El puente `xwaylandvideobridge` está desactivado
  en el arranque; si se necesita, reactivar
  `~/.config/autostart/org.kde.xwaylandvideobridge.desktop`.
- B4: hecho en anidado; falta probar con una app real (KeePassXC/Telegram).
- B5: Wi-Fi (escanear solo con el panel abierto, reconectar, olvidar, QR,
  bandas) y Bluetooth (emparejar, batería); autoapagado a 15 min y hotspot.
- Aceptación: cada flujo termina sin usar la terminal.

### 7. C2 y C5 (hecho)
- C2: importar `.ovpn` y editar nombre/arranque automático; perfiles de
  energía con `power-profiles-daemon`. Verificado por IPC y con `nmcli`; falta
  el clic físico en el engranaje y en las fichas de energía.
- C5: ubicación manual del clima y demonio de alarmas con el shell cerrado,
  incluido el temporizador persistente. Verificado en real.
- C3 y C4 están hechos; solo queda la prueba de la tecla física de brillo.
- Si se reinstala el sistema, recordar `network-manager-openvpn`, copiar
  `portals.conf` a `~/.config/xdg-desktop-portal/` y volver a enlazar
  `~/.config/systemd/user/alba-alarms.service` (contenido abajo).

### 8. Opcionales (no empezar sin pedirlo)
- D1 fase 2 (recolocar iconos y persistir posiciones), D2 apps web, E3 prueba
  automática y E4 reversión.
- **Instalación limpia:** `install.sh` y `scripts/install-umbriel-fork.sh`
  automatizan el proceso; la guía manual está en `INSTALACION.md` y los
  archivos de sistema en `install/`. Antes de formatear, seguir la sección de
  copias y comprobar B3/B5. Falta probar el instalador en una VM o disco
  aparte, y probar la reversión (E4).
- **Acento de KDE sin `plasma-workspace`:** pendiente. Sin ese paquete, las
  apps KDE usan Breeze pero no el acento de ALBA. Alternativas a estudiar:
  generar un `.colors` propio en `~/.local/share/color-schemes`, `matugen` o
  `wallust`. No instalar `plasma-workspace` solo por esto.
- **D1 fase 2 aparcada por decisión del usuario (2026-11-05):** se retoma al
  final, después del resto de bloques.
- A4 (volumen por ventana) sigue descartado.
- **Escritorios automáticos (mejora futura).** El inventario fijo de nueve está
  escrito a mano para `HDMI-A-1`. Conviene un `alba-workspaces` que lea
  `umbriel outputs --json`, localice la sección `[output."..."]` correcta y
  escriba `workspaces = N` sin depender del conector. Así funcionará igual en el
  sobremesa y en un portátil (`eDP-1`). No empezar sin pedirlo.
- **Perfiles de energía personalizados (idea futura, sin empezar).** El usuario
  quiere poder crear un perfil propio con límite máximo de frecuencia de CPU,
  de GPU y, en portátiles, algo parecido al TDP de una Steam Deck. Es viable,
  pero `power-profiles-daemon` solo ofrece los tres perfiles fijos: haría falta
  un ayudante privilegiado (polkit) que escriba en `cpufreq`/`intel_pstate`,
  `amdgpu`/`nvidia-smi` y, si el firmware lo permite, en los límites RAPL o
  `ryzenadj`. Nunca inventar valores: detectar qué expone cada equipo y mostrar
  solo esos controles, con topes validados y reversión al cerrar sesión o
  apagar el perfil. En este sobremesa Intel probablemente solo se pueda limitar
  frecuencia máxima y turbo; el TDP/GPU depende de la placa. Esperar a que el
  usuario concrete qué controles quiere antes de implementarlo.
- **Adaptación a portátiles (pendiente, sin empezar).** El brillo real usa
  `ddcutil`, que sirve para monitores externos pero no para el panel eDP de un
  portátil; allí cae al atenuado por shader. Haría falta leer y escribir
  `/sys/class/backlight`. Para completar la adaptación: umbral de carga de la
  batería si el firmware lo expone, `platform_profile` cuando exista y los
  controles de energía personalizados de arriba. La batería ya muestra nivel
  real, colores de aviso y barrido solo al cargar.

## Comandos útiles

```sh
export UMBRIEL_SOCKET=/run/user/1000/umbriel-wayland-0.sock

umbriel windows --json | python3 -m json.tool | less   # id, ws, scratch, min, vis
umbriel restore-window <id>                            # restaurar sin revelar el pad
umbriel msg window-toggle-floating <id>
umbriel msg window-minimize <id>
umbriel msg window-move-to-scratchpad
umbriel move-menu <id>                                 # selector Mover desde CLI

qs ipc -c alba call windows status                      # diagnóstico del contrato
qs ipc -c alba call windows mode <n> <floating|mosaic>  # layout por escritorio
qs ipc -c alba call appearance chrome floating           # barra flotante/integrada
qs ipc -c alba call appearance wallpaper <ruta>          # fondo de pantalla
qs ipc -c alba call notifications settings               # abrir Ajustes
qs ipc -c alba call notifications scroll -700            # desplazar el panel
qs ipc -c alba call calendar weather                     # pestaña del clima

# Energía y VPN
qs ipc -c alba call power profile rendimiento            # equilibrado/ahorro
qs ipc -c alba call power status
qs ipc -c alba call vpn list                             # nombre|tipo|activa|auto
qs ipc -c alba call vpn importFile /ruta/perfil.ovpn
qs ipc -c alba call vpn save "viejo" "nuevo" true
qs ipc -c alba call vpn remove "perfil"

# Clima manual (vacío = detección por IP)
qs ipc -c alba call appearance weatherPlace Madrid

# Demonio de alarmas y temporizador
systemctl --user status alba-alarms.service
systemctl --user restart alba-alarms.service

# log de ALBA
L=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1); tail -50 "$L"
```

## Archivos clave

- `~/Documents/Alba/CompositorState.qml` — fachada común de compositores.
- `~/Documents/Alba/UmbrielBackend.qml` — backend Umbriel (minimizar,
  restaurar, foco, mover, layouts).
- `~/Documents/Alba/WorkspacePill.qml` — fichas, opacidad de minimizadas, clic.
- `~/Documents/Alba/Bar.qml`, `ControlCenterContent.qml` — barra y centro.
- `~/Documents/Alba/SettingsState.qml` — ajustes persistentes.
- `~/Documents/Alba/DesktopState.qml` — modelo de `~/Desktop` y apertura.
- `~/Documents/Alba/DesktopIcons.qml` — cuadrícula de iconos por pantalla.
- `~/Documents/Alba/scripts/alba-desktop-drop` — mueve o copia al escritorio lo
  que se suelta desde Dolphin.
- `~/Documents/Alba/PowerProfilesState.qml` — perfiles de energía.
- `~/Documents/Alba/VpnState.qml`, `VpnView.qml` — perfiles VPN, importación y
  edición.
- `~/Documents/Alba/scripts/alba-vpn-pick` — selector de `.ovpn`.
- `~/Documents/Alba/WeatherState.qml` — clima con ciudad manual o por IP.
- `~/Documents/Alba/CalendarPanel.qml` — clima, alarmas y temporizador
  persistente.
- `~/Documents/Alba/scripts/alba-alarms` — demonio de alarmas y temporizador.
- `~/Documents/Alba/alba-alarms.service` — copia de la unidad de usuario; la
  activa está en `~/.config/systemd/user/`.
- `~/.config/xdg-desktop-portal/portals.conf` — mapea el diálogo Access a GTK;
  copia en `~/Documents/Alba/portals.conf`. Sin él, captura y uso compartido
  se quedan esperando.
- `~/Documents/Alba/Wallpaper.qml` — fondo de pantalla en capa Background.
- `~/Documents/Alba/Audio.qml` — salidas, micrófono y flujos por aplicación.
- `~/Documents/Alba/scripts/alba-window-chrome` — aplica flotante/integrado a la
  configuración de Umbriel.
- `~/Documents/Alba/scripts/alba-wallpaper-pick` — selector de imagen.
- `~/Documents/Alba/scripts/alba-display-filter` — escribe `[display]` en la
  configuración de Umbriel y recarga.
- `~/Documents/Alba/DisplayState.qml` — brillo, atenuación extra y luz
  nocturna; elige filtro nativo de Umbriel o capa QML.
- `~/.config/umbriel/config.toml` — `[display]` con `brightness`,
  `extra_dim` y `warm`.
- `~/Documents/Alba/WindowChrome.qml` — barra de título de ALBA (solo si el
  usuario desactiva la nativa).
- `~/umbriel-fork/src/workspace/scratchpad.cpp` — ocultar/mostrar/restaurar.
- `~/umbriel-fork/src/view/view_chrome.cpp` y `src/scene/ssd_frame.cpp` — barra
  nativa flotante o integrada; al alternar se recoloca el espacio de trabajo.
- `~/.config/umbriel/config.toml` — `[appearance.title_bar] overlay` guarda el
  estilo elegido (true = flotante, false = integrado).
- `~/umbriel-fork/src/server/ipc_commands.cpp` — `restore-window` y campos
  `scratchpad_return_*`.
- `~/Documents/Desktop.html` — maqueta de referencia.

## Al terminar cada tarea

1. Prueba concreta (no vale «compila»).
2. Actualiza el apartado correspondiente de `PLAN.md` a «(hecho)» con la
   aceptación real.
3. Añade una entrada breve al final de `CONTEXTO.md` solo si hubo un hallazgo
   o un fallo que convenga recordar.
4. Si tocaste el fork: recompila, instala atómicamente, regenera el parche y
   avisa de que hace falta cerrar sesión.

# Shell · Traspaso para la siguiente sesión

> Las menciones a «ALBA» en el texto histórico se conservan como registro del
> nombre anterior; el código y la documentación nuevos usan «shell».

Documento corto para continuar sin reexplicar el proyecto. El detalle largo está
en `PLAN.md` (plan y aceptación) y `CONTEXTO.md` (historial). **No leas
`CONTEXTO.md` entero**: busca solo la sección que necesites.

## Estado al cerrar esta sesión

- **Fork nativo instalado (2026-11-09).** `/usr/bin/umbriel` ya es la compilación
  del fork e incluye tamaño flotante en cambios rápidos, foco al pasar por la
  barra de título, `[animation] speed` y desenfoque «Fondo» al arrastrar. Si se
  vuelve a cambiar el parche, reinstalar con
  `cd ~/Shell && ./scripts/install-umbriel-fork.sh --yes` y reiniciar sesión.
- **Animaciones, cristal, DNS y calendario (2026-11-09).** La velocidad de las
  animaciones se puede ajustar en Ajustes del shell; por defecto es 2× y el
  script escribe `[animation] speed`. El interruptor «Animaciones» escribe
  `[animation] enabled`. Arrastrar una ventana ya no cambia el cristal «Fondo»
  a «Simple». El perfil del punto de acceso (`mode = "ap"`) se excluye de DNS
  y proxy, así que desaparece la entrada «Desktop» con icono Wi-Fi. El
  calendario ya no muestra el campo de nota entre los días: el segundo clic
  sobre el día seleccionado abre un apartado aparte con el editor.
- **Portapapeles y brillo (2026-11-09).** El portapapeles se delega en
  `cliphist` (texto, listas de archivos e imágenes) y el brillo usa el panel
  interno por `brightnessctl`/sysfs antes de caer al filtro nativo. El
  instalador añade `cliphist` y `brightnessctl` con su regla de sudo.
- **Atajo del micrófono (2026-11-09).** Ya no usa `hyprctl`: se escribe en
  `[keybinds]` de Umbriel con `shell-config-set`, que ahora admite claves
  entre comillas y `--remove-key`. El cambio se aplica con una recarga.
- **Calendario (2026-11-09).** Se quitó el texto «Sin eventos ni notas para
  este día»; el editor de notas sigue en el apartado del segundo clic.
- **Cambio de modo sin doble animación (2026-11-09).** Se eliminó el segundo
  camino: el modo ya no se aplica con `workspace-set-layout` y con una recarga
  de configuración a la vez. El shell solo guarda la preferencia y escribe la
  regla nativa; Umbriel la aplica una vez. También se quitaron el temporizador
  de comprobación de modos y los bloqueos de doble clic.
- **Plan de dependencias opcionales.** `PLAN-DEPENDENCIAS.md` separa lo que ya
  funciona de lo que mejoraría con paquetes extra. Portapapeles con imágenes y
  brillo de portátil ya están hechos; quedan para después el teclado para
  es/de/pt, más tipos de VPN y los códecs Bluetooth.
- **Alternativas ya hechas.** `PLAN-ALTERNATIVAS.md` lista qué partes del shell
  ya delegan en herramientas del sistema y cuáles podrían hacerlo, con la
  recomendación de mantener la barra, los paneles y la integración de Umbriel.
- **Ajustes de apariencia (2026-11-09).** «Controles de ventana» desapareció
  de Configuración de ventanas: el modo Super sigue funcionando, pero ya no
  hay una fila que lo duplique. «Cristal de ventanas» se movió a Temas, junto
  al cristal del shell. Las paletas de acento y de fondo usan azul marino,
  vino, rosa, verde, arena, negro, blanco y el acento actual; las opciones ya
  no llevan descripciones.
- **Ventanas, iconos y foco (2026-11-09).** Se eliminó la pantalla de
  bienvenida que preguntaba el modo de ventanas; los modos de partida se
  aplican directamente. El menú del clic derecho usa los mismos iconos que la
  barra de título (salvo fijar y volumen, que conservan los del menú). Cambiar
  de mosaico a ventana ya conserva la posición y el tamaño que el usuario dejó
  en modo ventana. Al empezar a flotar se recuerda el tamaño objetivo aunque
  la app todavía no lo haya confirmado; así, cambiar de modo varias veces
  seguidas ya no adopta el tamaño del mosaico como tamaño flotante. Mantener
  Super cierra los paneles del shell y enfoca la ventana bajo el puntero,
  también cuando el puntero está sobre la barra de título nativa o sus iconos
  de opciones. Las ventanas nuevas en modo ventana se configuran con su tamaño
  final antes de mapear, sin el redimensionado posterior.
- **Monitor de red y muestreo ligero (2026-11-09).** La vista se llama
  «Monitor de tráfico de red». `stats.py` ya no hace `ping` cada 10 s: la
  latencia se mide cada segundo solo mientras el monitor está abierto y se
  detiene al cerrarlo. Fuera del panel solo lee la temperatura de CPU/GPU y el
  tráfico de la barra; carga, núcleos, frecuencias, potencia, VRAM e historial
  se consultan solo con la vista de rendimiento abierta.
- **Volumen por ventana y sonido de avisos (2026-11-09).** El altavoz de la
  barra de título nativa abre una tarjeta del shell con silencio y deslizador
  para esa ventana; el menú de opciones de la app conserva la misma fila. Se
  enlaza al flujo de PipeWire por PID o por id de la app. Las notificaciones
  pueden sonar con el aviso corto del sistema o con el `sound-file`/`sound-name`
  que pida la app, y se puede desactivar en Ajustes.

- **Falta instalar el fork actual.** `/usr/bin/umbriel` es del 2026-11-07 y no
  incluye el botón de volumen de la barra de título ni los últimos cambios
  nativos; el binario compilado está en `~/umbriel-fork/build/umbriel`
  (2026-11-09). Ejecuta
  `cd ~/Shell && ./scripts/install-umbriel-fork.sh --yes` y cierra sesión.
  El instalador añade `"volume"` a la lista de botones si todavía tiene la
  lista por defecto. Hasta entonces, `~/.config/umbriel/config.toml` conserva
  la lista antigua para que el Umbriel instalado pueda validarla.
- **C2 y C5 completados.** Perfiles de energía, importar/editar VPN, clima
  manual, demonio de alarmas y temporizador persistente. Se instaló
  `network-manager-openvpn` (necesario para `.ovpn`) y se habilitó
  `shell-alarms.service`. No se tocó el fork; el binario nuevo ya está
  cargado (ver el punto anterior).
- El usuario confirmó que la restauración de A6 funciona. Si dudas, comprueba:
  `umbriel --version` y `ps -o etime= -p $(pgrep -x umbriel)`; si el proceso es
  anterior al binario, hay que cerrar sesión y volver a entrar.
- **Red de seguridad de `config.toml` activa.** `umbriel-config-guard` se
  ejecuta antes de Umbriel (`ExecStartPre`) y repara el archivo si pierde
  `[general] autostart`. Hay copia `config.toml.good`, plantilla renderizada y
  registro en `~/.local/state/shell/config-guard.log`. Todas las escrituras
  pasan por el escritor único `shell-config-set`, que serializa, valida y
  sustituye el archivo de forma atómica. Detalle y recuperación:
  `CONFIGURACION-UMBRIEL.md`.
- **Cristal y desenfoque.** La barra, los paneles y los menús son ahora
  translúcidos y Umbriel los desenfoca con `[[layer_rule]]` (blur nativo). El
  centro de control separa «Shell» y «Ventanas»: cada bloque tiene su
  transparencia, su radio y un selector «Simple / Fondo» con el estilo del
  selector de tema. «Simple» desenfoca el contenido real y «Fondo» usa solo el
  fondo de pantalla; se guarda en `glassBlurBehind` y `windowBlurBehind`.
  Umbriel solo tiene un radio global, así que `scripts/shell-glass` escribe el
  mayor y reparte un `blur_strength` por regla para conservar los radios
  propios (16 px shell y 12 px ventanas por defecto, 3 pasadas).
  «Sincronizar con el shell» copia en vivo la transparencia y el tipo del
  shell; los valores propios se conservan al desactivarla. El tono (brillo,
  contraste y saturación) se elige por modo desde
  `~/.config/shell/glass-blur.conf`, sin recompilar. La sección «Ventanas»
  añade transparencia y blur de lo que hay detrás a todas las ventanas con un
  `[[window_rule]]` global; con 0 % el bloque se elimina. Pruebas:
  `scripts/test-glass-rules.sh`. Detalle: `CONFIGURACION-UMBRIEL.md` §11.
- **Menos controles en Ajustes.** Se quitó el selector de número de
  escritorios: `maxWorkspaces` se configura editando
  `~/.config/shell/settings.conf` y sigue valiendo 9 por defecto. «Tema en las
  apps» queda como interruptor; las opciones se explican por su nombre.
- **Redimensionar e intercambiar ventanas en modo Super (2026-11-07).** Con
  Super mantenido aparece una banda con una línea fina en cada borde compartido
  entre mosaicos y cuatro puntos en las esquinas de la ventana flotante
  enfocada. Los dibuja Umbriel dentro del árbol de cada ventana
  (`NativeHandles`), así que se mueven y redimensionan con ella en el mismo
  frame; el shell ya no superpone ninguna capa. En el fork, **solo la línea
  entre mosaicos redimensiona**: la banda activa es el hueco más dos píxeles
  por lado, no los 16 px dentro de cada ventana, y los bordes exteriores no
  redimensionan. En una flotante, los cuatro puntos de esquina tienen una zona
  de 24 px y los bordes una franja fina de 6 px, como el mockup. Un arrastre
  con Mod y botón izquierdo sobre el contenido de un mosaico intercambia esa
  ventana con la de debajo, con la origen atenuada y la destino resaltada; el
  movimiento nativo pasa al botón derecho, que sigue redimensionando si
  empieza sobre el divisor. Las líneas se ocultan si una ventana flotante las
  tapa. Probado con un puntero virtual en una sesión anidada: divisor desde
  ambos lados, borde exterior sin efecto, intercambio con izquierdo y
  reubicación con derecho. Detalle: `CONFIGURACION-UMBRIEL.md` §11 y §18.
- **Avisos emergentes de notificaciones (2026-11-07).** Al llegar un aviso se
  muestra una tarjeta en la esquina superior derecha (en el monitor de la
  ventana enfocada) durante su tiempo de expiración; las de `-t 0` o críticas
  se quedan hasta cerrarlas. Se apilan hasta tres, se ocultan con «No
  molestar», al abrir el panel o la vista general, y un clic abre el panel de
  notificaciones. La «×» descarta el aviso del historial y corta el sonido de
  una alarma. Comparten el margen y el ancho del panel lateral, y el modelo es
  un `ListModel` para que las tarjetas viejas no parpadeen al llegar una nueva.
  La capa `shell-notification-popup` se añadió a la regla de cristal para que
  tenga el mismo desenfoque que los paneles. Probado en una sesión anidada con
  D-Bus privado, incluyendo expiración automática, aviso crítico persistente y
  dos avisos seguidos sin recrear la primera tarjeta.
- **Configuración de ventanas unificada (2026-11-07).** La vista «Modo de
  ventanas» pasa a llamarse «Configuración de ventanas» y reúne la barra de
  título, el modo por escritorio, el tamaño y la cascada de ventanas
  flotantes. En Ajustes del shell queda
  solo el acceso «Configuración de ventanas»; se eliminó la fila duplicada de
  «Barra de ventanas». La barra de título va primero, encima de los modos
  manuales. Los modos se muestran «Mosaico» a la izquierda y «Ventana» a la
  derecha, sin la opción global ni descripciones. Por defecto el escritorio 1
  es mosaico, el 2 ventana y el resto (incluidos los nuevos) mosaico. El botón
  de modo de la píldora enseña el modo al que se va a cambiar. Además,
  `applyWorkspace` aplica el layout nativo aunque `umbriel windows --json`
  todavía no haya llegado, así el primer clic tras iniciar sesión ya funciona.
- **Temas como vista propia (2026-11-07).** En Ajustes del shell queda una
  fila «Temas → Abrir», igual que «Configuración de ventanas». La vista nueva
  reúne el modo oscuro/claro, el acento y el color propio, el cristal del
  shell y el de las ventanas (transparencia, desenfoque y tipo), «Tema en las
  apps», el fondo de pantalla y sus colores. Del ajuste general solo se movió
  lo relativo a colores, fondos y apariencia; bloqueo, barra y tamaños siguen
  en Ajustes.
- **Escritorios rápidos sin cambiar el modo equivocado (2026-11-07).** Umbriel
  solo cambia el layout del escritorio activo. Ahora el shell guarda el modo y
  espera 320 ms a que el escritorio se asiente antes de aplicarlo; si el
  destino cambió, no envía nada. Si el layout real ya coincide, tampoco envía
  la orden. Al elegir el modo de un escritorio que no está activo solo se
  guarda la preferencia y se aplica al entrar, en vez de saltar a él y volver.
  Probado en una sesión anidada con cambios rápidos entre un escritorio en
  mosaico y otro en ventana: los layouts se mantuvieron y el foco no saltó.
- **Modos de escritorio nativos (2026-11-07).** El modo por escritorio se
  guarda también en `config.toml` como `[layout] mode` y reglas
  `[[workspace]] layout.mode`, mediante `scripts/shell-workspace-modes`. Así
  Umbriel aplica el reparto desde el arranque y una recarga de configuración
  ya no lo borra: antes, el modo vivía solo en un override en caliente y una
  recarga podía devolver el escritorio entero a ventana. La orden
  `workspace-set-layout` sigue dando el cambio inmediato y las reglas
  nativas lo hacen persistente. Probado cambiando el escritorio 1 a ventana,
  recargando la configuración y volviendo a mosaico.
- **Indicadores de ventana nativos (2026-11-07).** Los puntos y divisores
  pasan del overlay QML `WindowHandles` a nodos de escena de Umbriel. Viven en
  el árbol de la ventana, así que no se quedan atrás al arrastrar ni al
  redimensionar, se recortan bajo una ventana flotante por el orden de escena
  y siguen el acento del tema. Se muestran con Mod mantenido o con el pin de
  «Mostrar con Super»; Umbriel conserva ese pin con
  `umbriel overlay-pin on|off|toggle` sin bloquear la entrada. El overlay del
  shell se eliminó.
- **Selector de escritorio nativo (2026-11-07).** El botón «Mover» de la
  barra de título ya no pide una tarjeta al shell: Umbriel dibuja el selector
  1–9 en su propia escena (`MoveMenu`), junto al puntero y por encima de las
  ventanas. Admite clic, Escape y las teclas 1–9; el escritorio actual queda
  resaltado y elegirlo solo cierra. La ventana se mueve sin cambiar de
  escritorio, como hacía el selector anterior. Se eliminaron
  `WorkspacePicker.qml`, `MoveMenuState.qml` y el evento `move_menu`; el
  comando `umbriel move-menu <id>` sigue abriendo el selector nativo.
- **Limpieza de capas de respaldo (2026-11-07).** Se borraron
  `WindowChrome.qml`, `DisplayFilter.qml`, `HyprlandBackend.qml`,
  `WindowModeBar.qml`, `WorkspacePicker.qml`, `MoveMenuState.qml` y
  `ChromeButton.qml`: eran fallbacks de otros compositores o capas que ya no
  se instanciaban. El shell queda solo con Umbriel como backend. También se
  quitó `move-menu` y `window-mode` del desenfoque de cristal.
- **Desenfoque y foco al mantener Super.** Umbriel desenfoca ahora solo el
  contenido de la ventana bajo el puntero mientras se mantiene Mod, como el
  mockup: shader de ventana con blur de 1.4 px y desaturación suave, más un
  velo del 10 %. Al mantener Mod también se enfoca esa ventana, así los atajos
  actúan sobre la que se señala y no sobre la última enfocada. La barra nativa
  y los botones quedan nítidos porque el shader se aplica
  al nodo del cliente, no al marco. Sustituye el velo del 28 % que se aplicaba
  a todas las ventanas. El parche del fork está regenerado; falta instalar el
  binario nuevo (cerrar sesión) y probarlo con ratón real.
- Fork en `~/umbriel-fork`, rama de trabajo sobre `b6c4b7d`.
  Parche regenerable en `~/Shell/umbriel-fork.patch` (66 archivos).
- **Plataforma decidida: solo Umbriel sobre Debian.** Hyprland y cualquier otro
  compositor quedan descartados; no se mantiene ni se prueba ese backend. El
  backend antiguo de Hyprland y las capas de respaldo del shell ya se
  eliminaron.
- Copia de seguridad del binario original: `/usr/bin/umbriel.stock-0.1.0`.
- El shell vive en `~/Shell` y está enlazado desde
  `~/.config/quickshell/shell`. Se recarga solo al guardar QML, salvo el pragma
  `UseQApplication` de `shell.qml`, que exige reiniciar el proceso.
- **Guía de instalación limpia preparada.** `INSTALACION.md` reúne hardware,
  repositorios, paquetes, compilación del fork, configuración de Umbriel,
  portales, sudoers, SDDM y copias de seguridad. Los archivos que vivían fuera
  del proyecto están guardados en `install/` (`bin/`, `config/`, `systemd/`,
  `sudoers/`, `apt/` y `packages.txt`).
- **Instalador automático (E1).** `install.sh` es el punto de entrada y delega
  en `scripts/install-packages.sh`, `scripts/network.sh` y
  `scripts/install-user-config.sh`; `scripts/install-umbriel-fork.sh` clona el
  fork si hace falta, aplica el parche, compila e instala con `mv` atómico.
  Instala repositorios, paquetes, configuración de usuario, sudoers y alarmas.
  Probado con `--dry-run` y con una compilación completa desde un clon limpio.
  Falta ejecutarlo de principio a fin en un Debian recién instalado.
- **Conflictos de backports corregidos (2026-11-06).** `install-packages.sh`
  instala PipeWire y Mesa en bloque desde `trixie-backports`; añade
  `libpixman-1-0` junto a `libpixman-1-dev`, mueve `wayland-protocols` al
  grupo de backports y añade `cmake`. `network.sh` instala el plugin Bluetooth
  con el stack completo de PipeWire si hace falta y reinicia PipeWire y
  WirePlumber. Falta confirmarlo con otra instalación limpia.
- **Paneles rápidos por control (2026-11-06).** Los controles de la barra ya no
  abren el panel de notificaciones: `QuickPanelState` muestra `SidePanel` en
  modo rápido, solo con la vista avanzada del control y sin la sección de
  notificaciones. La campana mantiene el panel completo con notificaciones,
  centro de control y opciones avanzadas. Verificado por IPC y en una instancia
  aislada de Quickshell; falta la confirmación visual con clic real.
- **Notificaciones y centro de control separables (2026-11-06).** En Ajustes del
  shell, «Notificaciones y control juntos» decide si la campana abre ambos
  bloques o si aparecen dos iconos (campana y cuadrícula). Cuando comparten
  panel, cada uno va en su propia tarjeta redondeada, con fondo y borde, y solo
  los une un hueco de 8 px como en el diseño de referencia; con la barra arriba
  el centro de control queda primero y las notificaciones debajo, y con la barra
  abajo se invierte. IPC: `notifications status`, `notifications unified
  true|false` y `notifications control`.
- **Barra lateral izquierda/derecha (2026-11-06).** «Posición de la barra»
  admite los cuatro bordes. En los laterales la barra se dibuja en vertical:
  logo y escritorios arriba, reloj compacto en el centro y controles abajo.
  Los escritorios muestran solo su número y la música solo la portada para
  caber en 44 px. Paneles, OSD, bandeja, batería, calendario, energía, menú de
  apps y reserva de espacio se anclan al lado correcto; el panel rápido se abre
  junto al control pulsado. Verificado con captura interna y por IPC en la
  instancia aislada, sin errores QML; falta la prueba con clic real en la
  sesión.
- **Renombrado completo (2026-11-06).** Hecho:
  - tipos QML: `ShellIcon`, `ShellIcons`, `ShellSwitch`, `ShellSlider`;
  - scripts `scripts/shell-*` e `install/bin/shell-*`;
  - rutas `~/.config/shell/`, `~/.local/state/shell/`,
    `~/.local/bin/shell-*` y `~/.config/quickshell/shell`;
  - servicio `shell-alarms.service`;
  - instancia `qs -c shell`;
  - cerrojos y temporales `config.toml.shell-lock` y `.shell-*`;
  - namespaces de capas (`shell-bar`, `shell-calendar`, `shell-osd`, etc.);
  - cadenas visibles: autor de las notificaciones, nombre de equipo por
    defecto, contraseña inicial y perfil del hotspot (`shell-hotspot`);
  - marcadores internos: heredoc `SHELL`, `$0` de los `sh -c`, marcadores
    `SHELL-THEME` (con migración del bloque antiguo en `gtk.css`) y variables
    `SHELL_COMPOSITOR`, `SHELL_ALARMS_FILE` y `SHELL_TIMER_FILE`;
  - comentarios, docstrings, títulos y rutas de la documentación vigente.
  En este equipo se migraron los datos a `~/.config/shell` y
  `~/.local/state/shell`, se instalaron los `shell-*`, se creó el enlace
  `quickshell/shell` y la unidad `shell-alarms`, y la sesión se reinició con
  `qs -c shell`. El repo ya no contiene `alba` en código ni configuración.
  Solo quedan menciones históricas a «ALBA» en `CONTEXTO.md`, `PLAN.md` y
  `PENDIENTES.md`, y el shader `screen.alba_display` del parche de Umbriel,
  que no se toca porque pertenece al compositor.
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
  `qs ipc -c shell call battery toggle` (también `openPanel`, `closePanel`,
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
  `scripts/shell-alarms` y la unidad de usuario `shell-alarms.service`
  (habilitada) leen `alarms.conf`; no duplican avisos si `qs` está abierto y,
  si no lo está, usan `notify-send` o un diálogo de KDialog/Zenity. El
  temporizador escribe `deadline=` en `~/.config/shell/timer.conf`; el demonio
  lo termina con el shell cerrado y el panel lo restaura al volver. Verificado:
  aviso de alarma y de temporizador, restauración de una cuenta atrás y
  limpieza del archivo al vencer.
- **Pestañas del reloj.** El calendario quedó como calendario simple: fuera la
  fecha larga del pie, puntos en los días con notas y lista de notas del día.
  Se descartó la integración con Google/ICS porque las notas no se podían
  sincronizar. El clima usa iconos SVG con color propio. Alarmas y
  temporizador comparten el mismo editor de dígitos de derecha a izquierda, sin
  escribir «:»: el temporizador muestra `123` → `1:23` y la alarma `930` →
  `09:30`. La edición se confirma al tocar fuera o cerrar el panel. El sonido
  de alarma y el del temporizador se repiten hasta cerrar el aviso o pulsar el
  reloj de la barra, que parpadea en azul mientras suenan. Detalle:
  `CONFIGURACION-UMBRIEL.md` §12–14.
- **Teclado.** La distribución se configura solo en el centro de control →
  Teclado, con seis idiomas: español, inglés, ruso, portugués, chino y alemán.
  El valor inválido `mosaic` se migra a `es`. El teclado flotante de wvkbd
  cambia a cirílico con ruso; el resto usa QWERTY internacional. Detalle:
  `CONFIGURACION-UMBRIEL.md` §16.
- **Rendimiento.** La barra reserva solo su altura (el margen ya lo suma el
  compositor), la animación de la batería solo corre al cargar de verdad, el
  Wi-Fi tiene límite de 12 s, las ventanas llegan por `umbriel subscribe`, el
  centro de control se carga con `Loader` y los iconos usan `MultiEffect`.
  Medido: `qs` en reposo 7,4 % → 0,6 %; panel abierto 12,4 % → 1,0 %. Detalle:
  `CONFIGURACION-UMBRIEL.md` §17.
- **Acciones de apps.** El clic derecho en la barra lee `Actions=` del
  `.desktop` mediante `DesktopEntry.actions`; Brave muestra «New Window» y
  «New Incognito Window». `DesktopActions.qml` arranca el escaneo asíncrono y
  avisa cuando termina. Si la acción no trae `Icon=`, se deduce del id
  (`view-private` para incógnito, `window-new`, `tab-new`, `go-home`,
  `user-trash`…). Detalle: `CONFIGURACION-UMBRIEL.md` §18.
- **Acciones de ventana sincronizadas.** `WindowActions.qml` alimenta la barra
  de título y el clic derecho con la misma lista: flotar, fijar, pantalla
  completa, mover, minimizar, maximizar y cerrar. Flotar desaparece en
  escritorios flotantes (Umbriel lo rechaza) y su icono/etiqueta cambia entre
  «Hacer flotante» y «Volver al mosaico». Cada fila lleva un icono de teclado
  cuyo tooltip muestra el atajo; los escritorios de «Mover» abren plegados. Se
  añadió `Mod+Shift+H` para minimizar. La barra nativa de Umbriel incorpora
  «fullscreen» después de fijar y comparte los iconos nuevos: dos ventanas sin
  línea de título para flotar, marco cuadrado grande con esquinas interiores
  para maximizar y cuatro esquinas para pantalla completa. Se quitó el
  subtítulo «app · escritorio» de la derecha. Un clic en el fondo de la barra,
  en una ficha o fuera del panel cierra el panel abierto. Detalle:
  `CONFIGURACION-UMBRIEL.md` §18.
- **Orden de las fichas.** La barra ya no hereda el orden de apilado del
  compositor: `CompositorState` numera cada ventana la primera vez que la ve y
  conserva ese orden al enfocar, minimizar o cambiar de escritorio. Detalle:
  `CONFIGURACION-UMBRIEL.md` §19.
- **Limpieza.** `foot` e `Inter Variable` son las dependencias por defecto. Se
  quitaron `scripts/bin/`, los `alternar-*.sh`, el `portals.conf` duplicado,
  `install/apt/trixie-backports.list` y `scripts/fix-network.sh`. Detalle:
  `CONFIGURACION-UMBRIEL.md` §20.
- **Bloqueo de pantalla.** El botón lanzaba `hyprlock` sin configuración y
  salía sin bloquear. `shell-lock` es ahora el único bloqueo: crea
  `~/.config/hypr/hyprlock.conf` desde la plantilla si falta y lo usan el menú
  de energía, `Mod+Shift+L` y `shell-idle`. Se quitaron los respaldos con
  swaylock/gtklock y las llamadas directas a hyprlock. Detalle:
  `CONFIGURACION-UMBRIEL.md` §15.
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
  desde Dolphin u otro gestor. `scripts/shell-desktop-drop` mueve los archivos
  de la misma unidad y copia los de otra, añade « (1)», « (2)»… si el nombre
  existe y nunca sobrescribe. El script está probado por separado; falta
  probar el arrastre real con el ratón.
- **C4 · Fondo por color.** Ajustes → Fondo de pantalla → «Color de fondo»
  (seis muestras y `#RRGGBB`). Se guarda `wallpaperColor=` y sobrevive al
  reinicio. `shell-system-theme` verificado con GTK 3/4 y KDE.
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
  Ese tamaño se envía ya en el configure inicial, así que la primera imagen
  aparece con su tamaño definitivo y no se redimensiona después. Antes
  conservaba el tamaño que pedía la app y solo se colocaba en cascada.
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
- **A15 · Redimensionar e intercambiar mosaico con el borde.** Con Super
  pulsado, arrastrar con el botón izquierdo a 16 px o menos de un borde, o del
  hueco entre dos ventanas, redimensiona; en el centro se intercambia con la
  ventana de debajo. El movimiento nativo de mosaicos vive en el botón derecho,
  que también redimensiona si empieza sobre un borde. El cursor de
  redimensionar aparece en una franja más gruesa. Verificado en dwindle desde
  ambos lados del borde compartido (666/586), intercambio de dos ventanas con
  izquierdo y reubicación con derecho. La versión anterior movía con el
  izquierdo en el centro y usaba 10 px de franja.
- **Incidencia de configuración.** Los scripts `shell-mod-hold` y
  `shell-floating-defaults` compartían `$cfg.shell-tmp` y, al coincidir,
  truncaron `~/.config/umbriel/config.toml` a 13 líneas. Se restauró desde una
  copia completa; hay respaldo en `Shell/umbriel-config-backup.toml`.
  Ahora usan `flock` y `mktemp`, probado con 25 ejecuciones simultáneas.
- **Recaída de la truncación y red de seguridad (2026-11-06).** Tras
  reiniciar, el escritorio quedó negro: `~/.config/umbriel/config.toml` se
  había reducido a 18 líneas y perdió `[general] autostart`, así que Umbriel
  arrancaba pero Quickshell nunca se lanzaba. La causa era que, además de los
  dos scripts ya protegidos, `shell-window-chrome`, `shell-display-filter`,
  `shell-keyboard-layout` y `shell-umbriel-theme` seguían escribiendo el archivo
  sin cerrojo, en el sitio o con el temporal compartido. Ahora los seis scripts
  no escriben el archivo: calculan el valor y llaman a `shell-config-set`, el
  escritor único que toma `flock` sobre `config.toml.shell-lock`, aplica solo las
  claves pedidas, valida con `tomllib` y `umbriel config validate` sobre un
  temporal y hace `os.replace` atómico. Además se añadió
  `umbriel-config-guard`, un drop-in de systemd (`ExecStartPre` antes de
  Umbriel), una copia `config.toml.good`, una plantilla renderizada y un
  registro de incidencias. Se restauró la configuración completa desde
  `install/config/umbriel-config.toml` y se validó con
  `umbriel config validate`. Pruebas: 8 escritores concurrentes × 5 rondas,
  36 comprobaciones del escritor y 39 de los seis scripts; el archivo conserva
  188 líneas, todas las secciones y `autostart`. Copia del archivo truncado:
  `~/.config/umbriel/config.toml.truncado-20261106`.
  **Detalle completo y recuperación:** `CONFIGURACION-UMBRIEL.md`.
- **A13 · Tamaño y cascada de ventanas flotantes.**
  `[layout.stacking]` gana `default_width_fraction`, `default_height_fraction`
  y `cascade_step`. Flotar una ventana de un mosaico ya no conserva el tamaño
  del mosaico: la primera vez usa el 60 % del área útil y se centra. Si la
  ventana ya flotó o se redimensionó, conserva su tamaño y su posición.
  Cambiar un escritorio entero de mosaico a flotante coloca en cascada solo
  las ventanas que nunca flotaron; las demás vuelven a donde el usuario las
  dejó. Ajustes → «Tamaño de ventanas flotantes» (40–80 %, pasos de 5) y
  «Separación en cascada» (Auto o 8–96 px); se guarda como
  `floatingSizePercent` y `floatingCascade` y lo aplica
  `scripts/shell-floating-defaults`. Verificado en anidado: 0,6 da 568×298 en
  una salida de 946×496; 0,5 y 48 px dan 473×248; tres ventanas en mosaico se
  colocan en 189,99 / 221,131 / 253,163. Binario `af15084668f2` instalado;
  falta cerrar sesión.
- **A12 · Retardo ajustable, música estable y reloj más legible.**
  Ajustes → «Retardo al mantener Super» (100–1000 ms, pasos de 50) guarda
  `superHoldMs` y escribe `[input] mod_hold_delay_ms` en Umbriel mediante
  `scripts/shell-mod-hold`. En anidado se comprobó con 600 ms: 300 ms sin velo,
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
  «Posición de la barra» permite abajo, arriba, izquierda o derecha y recoloca
  paneles, OSD y reserva de espacio; en los laterales la barra se apila en
  vertical con logo y escritorios arriba, reloj compacto en el centro y
  controles abajo. La píldora de música tiene un asa de estirado mientras
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
   con `qs ipc -c shell call ...`.
5. **Instalar el fork solo con `mv` atómico** (no se puede sobrescribir el
   binario en uso):
   ```sh
   cd ~/umbriel-fork && ninja -C build
   sudo cp build/umbriel /usr/bin/umbriel.new && sudo mv -f /usr/bin/umbriel.new /usr/bin/umbriel
   git diff b6c4b7d > ~/Shell/umbriel-fork.patch
   ```
   La contraseña de sudo está en `~/.config/shell/credenciales` (modo 600).
   Tras instalar, **cerrar sesión y volver a entrar**: el compositor en marcha
   no cambia de binario.
6. **No dejes `console.log` de depuración** en los QML. Comprueba el log con:
   `L=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1); grep -aE "TypeError|ReferenceError|is not defined|SyntaxError" "$L"`.
7. **`umbriel config-replace <archivo>` borra los layouts por escritorio.** Si
   lo usas, reaplica con `qs ipc -c shell call windows mode <n> <modo>`.
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
- Temas → «Fondo de pantalla»: elegir una imagen, ver que aparece detrás de
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
  (`qs -c shell kill`) y comprobar que el demonio avisa y suena. Arrancar un
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
  DNS global implementado (ficha propia, automático/manual IPv4/IPv6) y proxy
  por red (PAC generado + environment.d); falta probarlo con apps reales y
  tras reiniciar sesión.
- Aviso de dependencias bajo demanda en el panel de notificaciones (icono
  junto a «No molestar»), con botón para copiar la solución; falta comprobarlo
  visualmente.
- Audio Bluetooth: `libspa-0.2-bluetooth` añadido a `network.sh` y al chequeo
  de dependencias; falta ejecutar el script y probar los Galaxy Buds como
  salida y micrófono.
- Porcentajes por panel (volumen, brillo, atenuación, batería y Bluetooth):
  el ajuste global de Ajustes se sustituyó por interruptores independientes,
  todos desactivados por defecto y persistidos en `settings.conf`; falta
  comprobar visualmente que ocultan y muestran el porcentaje en la barra y en
  las fichas del centro de control.
- Aceptación: cada flujo termina sin usar la terminal.

### 7. C2 y C5 (hecho)
- C2: importar `.ovpn` y editar nombre/arranque automático; perfiles de
  energía con `power-profiles-daemon`. Verificado por IPC y con `nmcli`; falta
  el clic físico en el engranaje y en las fichas de energía.
- C5: ubicación manual del clima y demonio de alarmas con el shell cerrado,
  incluido el temporizador persistente. Verificado en real.
- C3 y C4 están hechos; solo queda la prueba de la tecla física de brillo.
- Si se reinstala el sistema, recordar `network-manager-openvpn`,
  `wpasupplicant` y `rfkill`; ejecutar `sudo ./scripts/network.sh` si
  NetworkManager deja la Ethernet como «unmanaged» o el Wi-Fi como
  «unavailable»; copiar `portals.conf` a `~/.config/xdg-desktop-portal/` y
  volver a enlazar `~/.config/systemd/user/shell-alarms.service` (contenido
  abajo).

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
  escrito a mano para `HDMI-A-1`. Conviene un `shell-workspaces` que lea
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

qs ipc -c shell call windows status                      # diagnóstico del contrato
qs ipc -c shell call windows mode <n> <floating|mosaic>  # layout por escritorio
qs ipc -c shell call appearance chrome floating           # barra flotante/integrada
qs ipc -c shell call appearance windows 20 12 simple   # ventanas 20 %, 12 px, contenido detrás
qs ipc -c shell call appearance windowsSync 1           # sincronizar con el shell
qs ipc -c shell call appearance glassStatus            # diagnóstico del cristal
qs ipc -c shell call appearance wallpaper <ruta>          # fondo de pantalla
qs ipc -c shell call notifications settings               # abrir Ajustes
qs ipc -c shell call notifications scroll -700            # desplazar el panel
qs ipc -c shell call calendar weather                     # pestaña del clima

# Energía y VPN
qs ipc -c shell call power profile rendimiento            # equilibrado/ahorro
qs ipc -c shell call power status
qs ipc -c shell call vpn list                             # nombre|tipo|activa|auto
qs ipc -c shell call vpn importFile /ruta/perfil.ovpn
qs ipc -c shell call vpn save "viejo" "nuevo" true
qs ipc -c shell call vpn remove "perfil"

# Clima manual (vacío = detección por IP)
qs ipc -c shell call appearance weatherPlace Madrid

# Demonio de alarmas y temporizador
systemctl --user status shell-alarms.service
systemctl --user restart shell-alarms.service

# Configuración de Umbriel y red de seguridad
~/.local/bin/shell-config-set --section display brightness=0.900  # escritor único
~/.local/bin/umbriel-config-guard status
~/.local/bin/umbriel-config-guard ensure          # repara si falta autostart
~/.local/bin/umbriel-config-guard save            # guarda copia buena
systemctl --user show umbriel.service -p ExecStartPre
tail -20 ~/.local/state/shell/config-guard.log
tail -20 ~/.local/state/shell/config-writer.log

# log de ALBA
L=$(ls -t /run/user/1000/quickshell/by-id/*/log.qslog | head -1); tail -50 "$L"
```

## Archivos clave

- `~/Shell/CompositorState.qml` — fachada común de compositores.
- `~/Shell/UmbrielBackend.qml` — backend Umbriel (minimizar,
  restaurar, foco, mover, layouts).
- `~/Shell/WorkspacePill.qml` — fichas, opacidad de minimizadas, clic.
- `~/Shell/Bar.qml`, `ControlCenterContent.qml` — barra y centro.
- `~/Shell/SettingsState.qml` — ajustes persistentes.
- `~/Shell/DesktopState.qml` — modelo de `~/Desktop` y apertura.
- `~/Shell/DesktopIcons.qml` — cuadrícula de iconos por pantalla.
- `~/Shell/scripts/shell-desktop-drop` — mueve o copia al escritorio lo
  que se suelta desde Dolphin.
- `~/Shell/PowerProfilesState.qml` — perfiles de energía.
- `~/Shell/VpnState.qml`, `VpnView.qml` — perfiles VPN, importación y
  edición.
- `~/Shell/scripts/shell-vpn-pick` — selector de `.ovpn`.
- `~/Shell/WeatherState.qml` — clima con ciudad manual o por IP.
- `~/Shell/CalendarPanel.qml` — clima, alarmas y temporizador
  persistente.
- `~/Shell/scripts/shell-alarms` — demonio de alarmas y temporizador.
- `~/Shell/shell-alarms.service` — copia de la unidad de usuario; la
  activa está en `~/.config/systemd/user/`.
- `~/.config/xdg-desktop-portal/portals.conf` — mapea el diálogo Access a GTK;
  copia en `~/Shell/portals.conf`. Sin él, captura y uso compartido
  se quedan esperando.
- `~/Shell/Wallpaper.qml` — fondo de pantalla en capa Background.
- `~/Shell/Audio.qml` — salidas, micrófono y flujos por aplicación.
- `~/Shell/scripts/shell-window-chrome` — aplica flotante/integrado a la
  configuración de Umbriel.
- `install/bin/shell-config-set` — escritor único de `config.toml`: aplica el
  parche, valida y sustituye el archivo de forma atómica.
- `install/bin/umbriel-config-guard` — repara `config.toml` antes de Umbriel y
  guarda copias buenas y rotas.
- `scripts/test-config-set.sh`, `scripts/test-config-writers.sh` y
  `scripts/test-config-guard.sh` — pruebas del escritor, de los seis scripts y
  del guardián.
- `~/Shell/scripts/shell-wallpaper-pick` — selector de imagen.
- `~/Shell/scripts/shell-display-filter` — escribe `[display]` en la
  configuración de Umbriel y recarga.
- `~/Shell/DisplayState.qml` — brillo, atenuación extra y luz
  nocturna; usa el filtro nativo de Umbriel.
- `~/.config/umbriel/config.toml` — `[display]` con `brightness`,
  `extra_dim` y `warm`.
- `~/Shell/WindowActions.qml` — lista única de acciones de ventana para la
  barra de título y el clic derecho.
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
5. Si tocaste la configuración de Umbriel o sus escritores, ejecuta
   `./scripts/test-config-set.sh`, `./scripts/test-config-writers.sh` y
   `./scripts/test-config-guard.sh`; comprueba que `config.toml` sigue
   validando y conserva `[general] autostart`.

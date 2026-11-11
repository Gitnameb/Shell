# Shell · Contexto del proyecto

## 1. Objetivo

Construir **Shell**, un escritorio Wayland con **Quickshell desde cero**, inspirado en el
mockup `~/Documents/Desktop.html` (“Noctalia OS — Mockup v0”), pero **sin** depender de
Noctalia ni de la antigua barra Shell en Rust/GTK4.

Prioridad acordada:

1. **Funcionalidad primero**: que las cosas funcionen de verdad.
2. **Apariencia casi al final**: colores, cristal, blur, animaciones y detalles visuales.
3. **El mockup es una idea general**, no un contrato pixel-perfect. Se cambiarán y añadirán cosas.

## 2. Decisiones tomadas

- Shell: **Quickshell** (QML/Qt Quick) desde cero.
- Compositor: **Umbriel sobre Debian** es el único objetivo. Shell conserva un
  **`CompositorState.qml`** de fachada, pero ya no se mantiene ningún otro
  backend. Hyprland, KWin y SwayFX quedan descartados. La interfaz solo consulta
  capacidades (`nativeTitlebar`, `superHold`, `nativeMinimize`, `snapZones`,
  `perWorkspaceLayout`, etc.), así que el código antiguo no rompe lo que ya
  funciona, pero no se prueba ni se amplía.
- Las **acciones de ventana** (enfocar, cerrar, flotar, fijar, maximizar, pantalla
  completa, mover, minimizar y cambiar layout) pasan por `CompositorState`, no por
  llamadas sueltas a Hyprland. En Hyprland, cerrar usa `killwindow` porque
  `closewindow` no cerraba con dirección; minimizar usa `special:minimized` porque no
  hay minimizar nativo; el layout se cambia con `hyprctl keyword workspace`. La UI
  muestra solo las acciones que el backend declara como capacidad.
- No se usará Noctalia como dependencia. Aparece en el mockup solo como referencia
  histórica: la versión v5 ya no es Quickshell (es C++/OpenGL), y la v4 (Quickshell)
  está archivada.
- Las apps del mockup (navegador, archivos, terminal, música, ajustes) son **apps reales**.
  El shell no dibuja su contenido.
- La barra de ventanas, el tiling, el pin, el movimiento entre escritorios y el
  minimizar son responsabilidad de **Hyprland** + scripts/overlays, no de Quickshell.
- El proyecto viejo **Shell en Rust/GTK4** (`~/shell`, `~/Documents/instalar-shell-completo.sh`)
  queda como referencia y respaldo. No se borra.
- El mockup incluye una función de “apps web” solo para demos; no es prioridad.
- Un control del centro de control solo puede estar en un sitio: si se arrastra a la
  barra, desaparece de la cuadrícula; si se arrastra de vuelta al panel, vuelve a la
  cuadrícula. No hay duplicados, como en los mosaicos rápidos de Android.
- Los controles de la barra **no** se quitan con clic derecho. Se reordenan
  arrastrándolos dentro de la barra y se devuelven al centro de control arrastrándolos
  al panel.
- «No molestar» se queda únicamente en la cabecera de notificaciones. Su antiguo
  hueco en el centro de control lo ocupa la **luz nocturna**.
- El **brillo** intenta controlar el monitor de verdad con DDC/CI (`ddcutil`) y, si
  el monitor no responde, cae al shader de Hyprland. La atenuación extra y la luz
  nocturna siempre usan el shader (`decoration:screen_shader`), no una ventana a
  pantalla completa, para no bloquear el puntero.
- En la barra, el **escritorio activo oculta su número** y deja solo los iconos de
  sus apps; los demás escritorios conservan el número, así se sabe dónde se está por
  el que no lo muestra. Las fichas de app pasaron de 20 a 26 px con iconos de 18 px,
  como el ejemplo web.
- Los **controles de la barra se reordenan arrastrándolos** dentro de la propia barra.
  Mientras se arrastra aparece una marca vertical en el hueco de inserción; al soltar,
  el control se coloca en esa posición. Sigue funcionando el arrastre de vuelta al
  centro de control para quitarlos. El orden es de sesión: al reiniciar Quickshell
  vuelve el orden por defecto.
- El punto de acceso Wi-Fi se gestiona con NetworkManager (`nmcli`), con perfil
  propio `shell-hotspot` y SSID/clave editables. Por defecto el SSID visible es el
  nombre de la máquina (`hostname`), no un nombre genérico del shell. La vista
  incluye banda (2.4/5 GHz) y un QR WPA generado con `qrencode`.
- El adaptador Bluetooth también usa el nombre de la máquina por defecto. Su nombre
  se puede cambiar desde el engranaje de su vista (`bluetoothctl system-alias`).
  La vista normal enseña solo los dispositivos vinculados y un botón «+»; las
  opciones del adaptador y la búsqueda de nuevos quedan en segundo plano.
- La lista de Wi-Fi enseña la intensidad con el icono de señal y las bandas de cada
  red (`2.4G`, `5G`, `6G`). Pulsar una banda limita el perfil de NetworkManager a
  esa banda; no se puede apagar la última. `WifiState.qml` obtiene frecuencia,
  seguridad y señal con `nmcli`.
- El modelo de la lista guarda solo los nombres de las redes y se actualiza con
  400 ms de retardo. Así las ráfagas de altas y bajas de puntos de acceso de
  NetworkManager no reconstruyen las filas ni dejan referencias a objetos que
  acaban de destruirse.
- Al pulsar una red protegida, la propia fila se expande y muestra el campo de
  contraseña, un ojo para mostrarla u ocultarla y un botón de check para conectar,
  sin un cuadro aparte. Mientras se escribe, la lista se congela para que no se
  borre el texto. Si NetworkManager rechaza la conexión (contraseña incorrecta,
  tiempo de autenticación agotado o red perdida), la vista Red muestra el motivo
  en lugar de no hacer nada. El campo de contraseña es el mismo componente
  (`WifiPasswordRow.qml`) que usa el formulario de red oculta.
- Solo la red Wi-Fi **conectada** muestra el engranaje de opciones avanzadas
  (QR, reconexión automática, bandas y olvidar). El resto de redes no lo lleva.
- El engranaje general de la vista Red reúne el apagado por inactividad y el
  interruptor **Mostrar redes ocultas**. Al activarlo, las redes que no emiten
  su SSID se mezclan con las visibles y se ordenan por conexión y señal; se
  identifican por su BSSID/MAC. Si una de ellas ya está conectada, se muestra
  con su SSID real, porque el perfil guardado ya lo conoce. Al pulsar una, su
  formulario de SSID y contraseña se abre dentro de la propia fila, como una red
  normal. El botón **+** de la cabecera queda solo para añadir una red oculta a
  mano.
- El centro de control tiene una ficha **DNS** propia. Abre una vista con un
  ajuste **global**: automático o servidores IPv4/IPv6 propios, aplicado a todas
  las conexiones Wi-Fi y Ethernet guardadas (NetworkManager no ofrece un DNS
  único para todo el sistema). La vista muestra qué redes se verán afectadas y
  los cambios se aplican con `nmcli device reapply`, sin cortar el enlace. Lo
  implementan `DnsSettings.qml`, `DnsState.qml` y
  `scripts/network-settings.py`.
- El engranaje general de la vista Red incluye **Proxy por red**: cada conexión
  guardada puede usar sin proxy, automático (PAC) o manual (HTTP, HTTPS, SOCKS y
  excepciones). NetworkManager solo admite `none`/`auto`, así que el modo manual
  se guarda como un PAC generado en el perfil. Si la red está activa, también se
  escribe `~/.config/environment.d/90-shell-proxy.conf` para la próxima sesión.
  Los datos editables se guardan en `~/.config/shell/proxy.json`. Lo implementan
  `ProxySettings.qml`, `ProxyState.qml` y el mismo ayudante.
- El panel de notificaciones tiene un icono de comprobación junto a
  «No molestar». Al pulsarlo ejecuta `scripts/check-deps.sh` y muestra una
  tarjeta con los paquetes que faltan y el comando para instalarlos; la
  tarjeta incluye un botón para copiar la solución. No se comprueba al
  arrancar ni cada vez que se abre un panel. Lo implementan
  `DependencyState.qml`, `scripts/check-deps.sh` y `SidePanel.qml`.
- El icono de recargar de la cabecera fuerza una búsqueda real de redes
  (`nmcli device wifi rescan`); no es decorativo y muestra información al pasar
  el puntero.
- Si hay varias interfaces cableadas (Ethernet y un móvil compartiendo por USB),
  la vista Red muestra una ficha por cada una, con su propio estado y botón de
  conectar/desconectar. Las interfaces cuyo nombre empieza por `usb`, `enx` o
  `rndis` usan el icono USB; el resto, el de Ethernet.
- Volumen y micrófono listan todas las salidas y entradas de PipeWire, permiten
  elegir la predeterminada y ajustar el nivel del micrófono, no solo silenciarlo.
- Los auriculares Bluetooth necesitan `libspa-0.2-bluetooth` para aparecer como
  salida y micrófono; `scripts/network.sh` lo instala y reinicia WirePlumber
  cuando termina. Sin él, BlueZ puede rechazar la conexión con
  `br-connection-profile-unavailable`.
- Los incrementos de volumen, brillo, atenuación y fuerza de luz nocturna son de
  **2%** (rueda de la barra, teclas multimedia y deslizadores); antes eran de 5%.
- La **apariencia** se controla con dos preferencias compartidas: `themeMode`
  (`dark` o `light`) y `accentColor` (`#RRGGBB`). El modo oscuro usa una barra gris
  muy oscura y el acento por defecto es un gris claro; el modo claro reutiliza el
  mismo acento y lo oscurece automáticamente para conservar el contraste. Ambos se
  eligen en Ajustes y se guardan en `settings.conf`.
- Los widgets usan iconos reales del tema Breeze mediante `ShellIcon.qml`, no emojis.
  El color del icono comunica el estado: acento para activo, ámbar para aviso (señal
  débil, batería media), rojo para peligro (mudo, batería baja), cálido para luz
  nocturna y gris para apagado. La campana se tiñe cuando hay avisos sin leer; brillo,
  atenuación y hotspot solo se colorean cuando están ajustados.
- Se añadieron los widgets que faltaban del ejemplo: **Música** (MPRIS), **Procesador**,
  **Gráficos**, **Red**, **VPN** y **Teclado en pantalla**. Música, CPU, GPU y Red se
  colocan en la barra por defecto; todos se pueden arrastrar al centro de control y
  viceversa como el resto. La barra arranca con `music`, `wifi`, `bluetooth`,
  `volume`, `cpu`, `gpu` y `net`.
- Los iconos de **Música, luz nocturna, VPN, modo avión, CPU, atenuación extra, brillo,
  tráfico de red, teclado, energía y las pestañas del reloj** son SVG propios copiados
  del sprite del diseño (`ShellIcons.qml` + `icons/`), con el mismo trazo de 1,8 px;
  los de Wi-Fi usan 2,2 px para que no se vean finos al tamaño de la barra.
  El resto de iconos sigue usando el tema Breeze. La hora de la barra es solo texto,
  como en el diseño; no lleva icono.
- **Bluetooth**: la batería del dispositivo conectado se muestra como porcentaje junto
  al icono (barra y ficha del centro de control) y en la lista de dispositivos, solo
  si se activa **Mostrar porcentaje de batería** en las opciones de Bluetooth. Por
  defecto está desactivado. El icono se pone **rojo con 10 % o menos**, **naranja con
  20 % o menos** y **blanco** por encima. La vinculación usa `bluetoothctl` porque
  Quickshell no registra un agente de BlueZ propio; el panel activa `pairable`,
  escucha, vincula, marca el dispositivo como de confianza y lo conecta. Si falla,
  muestra un aviso y deja reintentar.
- **Ethernet + Wi-Fi**: si hay cable y Wi-Fi conectados a la vez, la barra muestra los
  dos iconos juntos. La vista de Wi-Fi incluye una sección «Ethernet» con la interfaz y
  un botón para **desconectar** el cable (y volver a conectarlo).
- El widget de **tráfico de red** de la barra muestra número, unidad y flechas de
  subida/bajada, como el diseño, en vez de un icono. La ficha «Red» y la cabecera del
  panel usan el icono de Wi-Fi del diseño. El ancho de la píldora sale del contenido
  (con menos relleno) para que no quede más ancha que sus cifras.
- Los **widgets de la barra** (Música, Wi-Fi, Bluetooth, Volumen, CPU, GPU, Red) se
  abren con un clic y se cierran con otro clic en el mismo icono. Ya no hay «×» en la
  cabecera del panel; se cierra con el mismo icono, con la campana o con Escape.
- **Volumen y micrófono** comparten el mismo dibujo en la barra, la ficha del centro
  de control y el OSD, con SVG propios y el mismo trazo que el resto de iconos. El
  volumen tiene variantes de uno, dos y tres arcos, y una tachada al silenciar; el
  micrófono usa `icons/mic.svg` e `icons/mic-off.svg`. El color sigue indicando el
  estado y el texto «Mudo» aparece en la barra al silenciar.
- En **Bluetooth**, el modo «Vincular dispositivo» inicia la búsqueda automáticamente
  al entrar y la detiene al salir o al cancelar. Ya no hay un interruptor de búsqueda
  dentro de ese apartado.
- El **menú de energía** usa los iconos del diseño: bloqueo, reinicio y apagado exactos,
  más un icono de cierre de sesión dibujado con el mismo trazo.
- Música usa `Quickshell.Services.Mpris`; la portada, el título, el progreso y los
  controles salen del reproductor real. Si hay varios reproductores, la vista permite
  elegir uno. Cuando Firefox y `plasma-browser-integration` publican el mismo tema, se
  prefiere el que trae portada y artista, para que la barra no se quede sin carátula.
  La portada de la barra está centrada verticalmente. Los botones que el reproductor no
  soporta quedan desactivados. La posición se avanza localmente cada 500 ms porque
  Firefox no emite cambios de `Position`; se resincroniza al cambiar de pista o al buscar.
- Los datos de CPU, GPU y red son **reales**, no simulados: `stats.py` lee `/proc/stat`,
  `/proc/net/dev`, `/sys/class/hwmon`, `/sys/class/drm` y hace ping al gateway. La
  potencia de la CPU no se muestra porque RAPL no es legible sin privilegios; la de la
  GPU sí (AMD). El desglose de red por aplicación no se muestra: requeriría `nethogs`
  o privilegios.
- VPN usa los perfiles reales de NetworkManager (`vpn` y `wireguard`) mediante `nmcli`.
  No hay servidores de demostración: si no hay perfiles, la vista explica cómo crear
  uno con `nmtui` o importando un `.ovpn`.
- El teclado en pantalla usa **wvkbd** (protocolo de teclado virtual de Wayland). Se
  instala como paquete del sistema y se muestra/oculta desde el centro de control, la
  barra (si se añade) o `qs ipc -c shell call notifications keyboard`.
- Mostrar la temperatura de CPU/GPU junto al icono es opcional (`showTemps`), se
  controla desde la vista de rendimiento y se guarda en `settings.conf`.
- El punto de acceso tiene una vista principal limpia con el **QR y los dispositivos
  conectados**, y un **engranaje** con SSID, clave, banda, red oculta y apagado
  automático. Los clientes se leen de `ip neigh` (IP y MAC) y se refrescan cada 4 s.
- `AutoOffState.qml` apaga el hotspot si nadie se conecta, el Wi-Fi si se queda sin
  conexión y el Bluetooth si no tiene ningún dispositivo conectado durante el tiempo
  configurado (5/10/15/30 min; 15 por defecto en los tres). Esos ajustes se guardan en
  `settings.conf`; el Wi-Fi no se apaga mientras el hotspot está activo ni mientras
  la vista Red está abierta.
- El **modo avión** (`AirplaneState.qml`) apaga Wi-Fi, Bluetooth y el punto de
  acceso, pero se puede volver a encender cualquiera de ellos a mano sin salir del
  modo, como en Android. Al desactivarlo se restauran las radios que estaban
  encendidas antes. Su ficha del centro y su icono de la barra son solo un
  interruptor: no tienen vista de opciones.
- La barra muestra **1..9 escritorios por defecto**. El máximo se cambia desde
  **Ajustes** (1–20) y se guarda en `~/.config/shell/settings.conf`. Cada escritorio
  enseña los iconos de sus apps abiertas; al pulsar un icono se enfoca esa ventana.
  En el escritorio **activo** se oculta el número y solo quedan sus apps; los demás
  conservan el número. Los atajos `SUPER+1..9` siguen siendo los mismos.
- Ajustes es un control más del centro de control, no un bloque fijo: así no ocupa
  espacio cuando no se está usando. Se abre pulsando su nombre y también se puede
  arrastrar a la barra.
- Mostrar los porcentajes de volumen, brillo, atenuación, batería y batería Bluetooth
  es opcional y se controla desde el panel de cada uno; por defecto está desactivado.
  Las vistas avanzadas siempre muestran el valor porque el deslizador lo necesita.
- El lanzador limpia `HL_INITIAL_WORKSPACE_TOKEN` al abrir una app. Quickshell lo
  hereda de Hyprland y podía hacer que las apps se abrieran en el escritorio inicial
  en vez de en el activo.
- Pulsar y soltar la tecla **Super** abre el cajón de apps (`bindr` de Hyprland).
  `SUPER+Espacio` sigue funcionando como alternativa.
- El panel del reloj está anclado a la barra inferior y tiene pestañas de
  **calendario, clima, alarmas y temporizador**. El clima se consulta a `wttr.in`
  (sin clave de API). Las alarmas se guardan en `~/.config/shell/alarms.conf`, se
  comprueban cada segundo y suenan con `paplay` además de avisar con `notify-send`;
  el temporizador también suena al terminar.
- Contraseña de sudo disponible para esta sesión de trabajo. **No se guarda en este documento.**

## 3. Entorno actual (actualizado 2026-11-04)

- Debian GNU/Linux 13 (trixie), kernel/arquitectura amd64.
- GPU: AMD Radeon RX 470/480/570/580 (Ellesmere). No es una VM (`systemd-detect-virt = none`).
- Sesión principal: **Umbriel** (`XDG_CURRENT_DESKTOP=Umbriel`), elegible en
  Noctalia Greeter; SDDM queda como respaldo. Monitor LG `HDMI-A-1` a
  1920×1080@75.
- Umbriel: `0.1.0~1505-g63327b58-1~bpo13+1` desde el repositorio de Noctalia
  (`trixie-backports`). Config: `~/.config/umbriel/config.toml`; valida con
  `umbriel config validate -c ~/.config/umbriel/config.toml`.
  - Barra de título nativa (`mode = "forced"`, 34 px) que **reserva espacio**: el
    contenido empieza debajo, no se superpone.
  - Layout por escritorio: `stacking` (Flotante) y `dwindle` (Mosaico).
  - Autostart de Shell mediante `~/.local/bin/shell-start`.
  - Teclado en español: `[input.keyboard] layout = "es"`.
- Hyprland (respaldo): `0.55.2+ds-1~bpo13+1` desde `trixie-backports`.
  - Config actual: `~/.config/hypr/hyprland.conf` (valida: `config ok`).
  - Teclado configurado en español: `input { kb_layout = es }`.
  - La config vieja de `shell-bar` ya está fuera; arranca `qs -c shell`.
- Quickshell: `0.3.0-1~bpo13+1` desde `trixie-backports`.
  - Binarios: `/usr/bin/qs` y `/usr/bin/quickshell`.
  - Módulos Qt disponibles: QtQuick, Controls, Layouts, Effects, Shapes, etc.
  - Arranca con `QS_ICON_THEME=breeze-dark` (en `exec-once`) para que los iconos
    del shell usen Breeze sin forzar el tema GTK en las apps. La sesión fija
    `QT_QPA_PLATFORMTHEME=kde` para que las apps Qt/KDE sigan el esquema de color.
- Herramientas presentes: `hyprctl`, `grim`, `slurp`, `jq`, `nmcli`, `bluetoothctl`,
  `wpctl`, `upower`, `kitty`, `firefox`, `qrencode`, `python3`, `ping`, `wvkbd`,
  `flock`, `kwriteconfig6` y `plasma-apply-colorscheme`.
  `wvkbd-mobintl` se instaló para el teclado en pantalla; `python3` y `ping` alimentan
  `stats.py` (CPU, GPU y red). `wl-paste` y `wl-copy` se extrajeron del paquete
  `wl-clipboard` a `scripts/bin/` para no depender de una instalación con `sudo`.
- UPower solo expone `DisplayDevice` (este equipo no tiene batería). La barra debe
  ocultar el widget de batería si no hay batería de portátil.
- Red: NetworkManager disponible (`nmcli`).
- Audio: PipeWire + WirePlumber (`wpctl`); para Bluetooth,
  `libspa-0.2-bluetooth`.
- Brillo: el monitor LG `HDMI-A-1` admite **DDC/CI**. Se instaló `ddcutil` y se
  creó `/etc/sudoers.d/shell-ddcutil` para que el usuario pueda leer y escribir el
  brillo sin contraseña (`sudo -n ddcutil ...`). Si el monitor no responde, el shell
  vuelve al shader global de Hyprland. No hay `/sys/class/backlight` ni
  `brightnessctl` porque es un equipo de escritorio con monitor externo.
- `hyprsunset` no está instalado y tampoco hace falta: en Hyprland la luz
  nocturna y la atenuación extra usan su shader; en Umbriel usan la capa
  `DisplayFilter.qml`.
- `nmcli` puede crear puntos de acceso Wi-Fi (probado con el adaptador `wlp5s0`).
  El shell crea el perfil a mano (`connection add` + `connection modify` + `up`) para
  poder fijar `802-11-wireless.hidden` antes de activarlo.

## 4. Fuentes y archivos clave

| Ruta | Qué es |
|---|---|
| `~/Documents/Desktop.html` | Mockup de referencia (541 KB). Barra inferior, paneles, launcher, centro de control, notificaciones, iconos, ventanas, ajustes. |
| `~/Documents/instalar-shell-completo.sh` | Instalador de la Shell vieja (Rust + GTK4 + gtk4-layer-shell). Referencia de funciones y atajos. |
| `~/shell/` | Código viejo de la barra Shell en Rust/GTK4. Respaldo, no se toca. |
| `~/.config/hypr/hyprland.conf` | Config actual de Hyprland. Tiene atajos y autostart de la barra vieja. |
| `~/.config/shell/` | Scripts de la barra vieja (`alternar-autoocultar.sh`, etc.). Referencia. |
| `~/Shell/` | **Este proyecto**: documentación + configuración de Quickshell. |
| `~/Shell/INSTALACION.md` | Guía de instalación limpia: hardware, repos, paquetes, edit, configuración, portales, backups y verificación. |
| `~/Shell/install/` | Archivos de sistema guardados para la reinstalación: scripts de `~/.local/bin`, config de Umbriel, portales, unidad de alarmas, fuentes APT y sudoers. |
| `~/.config/umbriel/config.toml` | Config de la sesión Umbriel: barra nativa, colores, teclado `es`, atajos y autostart de Shell. |
| `~/.local/bin/shell-start` | Arranca `qs -c shell -d` dentro de Umbriel con el tema Qt y el tema de iconos. |
| `~/.local/bin/shell-keyboard-layout` | Cambia `[input.keyboard] layout` y recarga Umbriel. |
| `~/.local/bin/shell-idle` | Arranca `swayidle` con el tiempo de bloqueo elegido y lanza `hyprlock`. |
| `~/.local/bin/shell-umbriel-theme` | Sincroniza los colores de la barra nativa con el modo y el acento de Shell. |
| `~/umbriel-edit/` | Código de Umbriel con el edit de la barra (icono, subtítulo, seis botones). |
| `~/Shell/umbriel-edit.patch` | Parche reproducible del edit sobre Umbriel `b6c4b7d`. |
| `~/Shell/PLAN.md` | Plan por fases de lo que queda por integrar. |
| `/usr/bin/umbriel` | Binario del edit instalado; el original queda en `/usr/bin/umbriel.stock-0.1.0`. |

## 5. Arquitectura

```
Compositor real (Umbriel principal; Hyprland de respaldo)
├── apps reales (kitty, Firefox, gestor de archivos, etc.)
├── Quickshell (shell)
│   ├── CompositorState.qml  contrato común: ventanas, escritorios, foco, acciones
│   │   ├── UmbrielBackend.qml    backend principal (IPC `umbriel msg`)
│   │   └── HyprlandBackend.qml   backend de respaldo (`hyprctl`)
│   ├── CompositorChip.qml  chip de acción reutilizable del diagnóstico
│   ├── Bar.qml            barra inferior
│   ├── Launcher.qml       lanzador de apps
│   ├── SidePanel          notificaciones + centro de control (hecho)
│   ├── OSD (volumen)      hecho
│   ├── LockScreen         hyprlock
│   └── servicios QML      reloj, audio, batería, red, bandeja, MPRIS, notificaciones
└── scripts/helpers        cosas que el compositor o Quickshell no resuelven solos
```

La UI no llama a Hyprland directamente para las ventanas: pide una lista normalizada a
`CompositorState`. Cada backend declara qué puede hacer y la interfaz oculta o adapta
lo que no exista. Los dos backends ejecutan acciones reales: enfocar, cerrar, flotar,
fijar, maximizar, pantalla completa, mover entre escritorios, cambiar el layout/modo
de un escritorio y minimizar/restaurar. La página **Ajustes → Compositor**
(o `qs ipc -c shell call notifications compositor`) enseña el estado real y permite
probar cada acción. El menú contextual de las apps de la barra y el clic de los
escritorios usan el mismo contrato.

Regla: **si es una superficie del escritorio → Quickshell; si es una ventana → el
compositor; si es el contenido de una app → la app.**

## 6. Inventario funcional del mockup

### Ya planeado / en curso (M1)

- [x] Barra inferior flotante, multi-monitor, con margen de 8 px.
- [x] Escritorios 1–9 desde Hyprland; clic para cambiar, con iconos de las apps abiertas.
- [x] Reloj y fecha con `SystemClock`.
- [x] Volumen con PipeWire: mostrar %, clic para silenciar, rueda para ajustar.
- [x] Red con NetworkManager: Wi-Fi activa y SSID.
- [x] Batería con UPower (oculta si no hay batería).
- [x] Bandeja del sistema (StatusNotifier).
- [x] Lanzador con búsqueda de apps, teclado y clic.
- [x] Notificaciones: servidor D-Bus, campana, contador, panel y “No molestar”.
- [x] Menú de energía / sesión (bloquear, cerrar sesión, reiniciar, apagar).
- [x] Calendario al pulsar el reloj (mes, navegación y día actual).
- [x] Atajos globales de Hyprland para lanzador, notificaciones y calendario.

### M2 (paneles y servicios)

- [x] Centro de control básico: Wi-Fi (lista, conectar y contraseña), Bluetooth
      (nombre visible, visibilidad, emparejamiento, búsqueda y dispositivos),
      volumen, micrófono y «No molestar».
- [x] Centro de control avanzado: brillo, luz nocturna, modo avión, hotspot y ajustes.
- [ ] Centro de control avanzado pendiente: VPN y perfiles de energía.
- [x] Panel del reloj: calendario con navegación por meses.
- [x] Clima, alarmas y temporizador del panel del reloj.
- [x] Reproductor MPRIS en la barra (portada, título, controles).
- [x] Brillo real por DDC/CI (`ddcutil`), con respaldo al shader; perfiles de energía
      (`power-profiles-daemon`) siguen pendientes.
- [x] OSD de volumen (con silencio).
- [ ] OSD de brillo: el panel y el widget ya cambian el brillo real, pero falta el aviso
      flotante al usar la rueda.
- [x] Bloqueo de sesión con `hyprlock` y fecha en español.
- [x] Ajustes funcionales del shell: máximo de escritorios y porcentajes por panel.
- [ ] Tema del shell (claro/oscuro, acentos, opacidad, blur).

### M3 (escritorio y ventanas)

- [ ] Iconos del escritorio con cuadrícula, arrastre e intercambio.
- [ ] Cabeceras de ventana flotantes/integradas: overlay que lee `hyprctl clients -j`.
- [x] Mini-iconos de las apps abiertas en cada escritorio (hasta 10 en el activo por defecto, configurable, y solo
      el número en los demás); los avisos por app llevan punto y las tareas externas
      pueden mostrar un anillo de progreso.
- [ ] Tiling/flotante por escritorio, pin, minimizar a `special:minimized`,
      restaurar geometría, mover a escritorio.
- [ ] Super toque (lanzador) vs. mantener 200 ms (modo ventanas).
- [ ] Volumen por ventana/stream.

### Difícil o fuera de alcance

- Contenido de apps reales (navegador, archivos, terminal). Se pueden tematizar, no clonar.
- Progreso por app: no hay API estándar; requiere integraciones concretas.
- “Instalar app web”: es un `.desktop` con `chromium --app=...`; script aparte.
- Blur real detrás de ventanas: lo hace Hyprland, no Quickshell.

## 7. Problemas conocidos / riesgos

1. **Hyprland**: se reinstaló y la config valida. El síntoma exacto del bug no está
   documentado todavía. Si vuelve a pasar, anotar: mensaje, si ocurre al iniciar sesión,
   al abrir una app, al cambiar de workspace, y el log (`Hyprland` desde TTY o
   `journalctl --user -b`).
2. **KWin no soporta `wlr-layer-shell`** para clientes externos. Los paneles de Quickshell
   no se verán en la sesión KDE. Hay que probar en Hyprland.
3. **Doble barra**: resuelto. `~/.config/hypr/hyprland.conf` ya no arranca `shell-bar`;
   ahora usa `exec-once = qs -c shell`. Copia de la config anterior:
   `~/.config/hypr/hyprland.conf.bak-20261103-221009`.
4. **Notificaciones en la prueba anidada**: KDE ya tiene registrado
   `org.freedesktop.Notifications`, así que Quickshell no puede registrarse dentro de la
   sesión KDE (aunque sí lo hará en una sesión Hyprland real). En la prueba anidada el
   panel se puede abrir y maquetar, pero no recibe notificaciones reales.
5. **`Locale` es un tipo nativo de QtQml**. El singleton de fechas se llama `Fechas`
   justamente para no colisionar; si se renombra a `Locale`, los textos desaparecen con
   errores `Property 'longDate' of object QtQml/Locale is not a function`.
6. **Blur y rendimiento**: el mockup ya documenta costuras/parpadeos con capas muy
   desenfocadas. Usar el blur de Hyprland y cachear el wallpaper; evitar `ShaderEffectSource`
   innecesarios.
7. **Overlay de cabeceras**: es la parte más frágil (geometría, gaps, fullscreen, foco,
   input). El mockup ya asume que la cabecera no reserva espacio y solo aparece con Super;
   eso ayuda, pero hay que probarlo mucho.
8. **Progreso por app** y **volumen por ventana exacta**: requieren heurísticas/integraciones.
9. **Bandeja del sistema vacía en Hyprland**: no hay `org.kde.StatusNotifierWatcher`
   (lo aportaba KDE). Quickshell avisa `UnknownObject '/StatusNotifierWatcher'` y no
   aparecen iconos de bandeja. Habrá que arrancar un watcher (o integrarlo) más adelante.
10. **`qs kill -c shell` a veces deja el proceso vivo** y al relanzar quedan dos barras
    (una encima de otra por el `exclusiveZone`). Si pasa: `pkill -x qs` y arrancar una
    sola instancia con `hyprctl dispatch exec "qs -c shell"`.
11. **Arrastre a la barra en varios monitores**: `ControlDrag` usa la geometría de
    `Quickshell.screens[0]` y la barra inferior de esa pantalla. En multimonitor habría
    que elegir la pantalla bajo el cursor.
12. **Controles de la barra y del centro**: viven en memoria; al recargar la config o
    reiniciar el proceso la barra vuelve al orden por defecto (`music`, `wifi`,
    `bluetooth`, `volume`, `cpu`, `gpu`, `net`) y la cuadrícula recupera su orden
    inicial (pendiente guardarlos en disco). El número de filas visibles sí se guarda
    (`centerRows`). Los de la barra no se quitan con clic derecho: se devuelven al
    panel arrastrándolos.
13. **Iconos del tema**: Quickshell fija `QS_ICON_THEME=breeze-dark` para que los
    iconos no dependan del tema GTK ni de que el shell tenga el foco. Las apps
    reciben `breeze` o `breeze-dark` según el modo desde `scripts/shell-system-theme`.
    Si cambia el tema de iconos, algunos nombres pueden dejar de resolver y se usa el
    emoji/inicial de respaldo.
14. **Brillo real por DDC/CI**: funciona si el monitor responde a `ddcutil` y si
    existe la regla `/etc/sudoers.d/shell-ddcutil` (instalada en este equipo). Si el
    monitor no responde, `DisplayState` usa el shader global de Hyprland como
    respaldo. La atenuación extra y la luz nocturna siempre son un filtro global
    (`decoration:screen_shader`): afectan a todos los monitores y también a las
    capturas. Si Quickshell se cierra de golpe con el filtro activo, el shader puede
    quedar aplicado hasta el siguiente arranque, que lo limpia. Si se recarga Hyprland
    (`SUPER+SHIFT+R`), el shader vuelve a vacío aunque la interfaz lo muestre activo;
    basta con volver a tocar el control. Las escrituras DDC tardan unos 0,5 s y se
    agrupan al dejar de mover el deslizador.
15. **Visualización persistente**: `DisplayState` guarda `extraDim`, `extraDimLevel`,
    `nightLight` y `nightStrength` en `~/.config/shell/display.conf`. Los niveles por
    defecto de atenuación extra y luz nocturna son 50 %. El brillo real se sigue
    leyendo del monitor al arrancar y no se guarda. Si Hyprland se recarga, el shader
    se limpia; hay que volver a tocar el control para reaplicarlo.
16. **Punto de acceso**: depende de que el adaptador Wi-Fi soporte modo AP y de que
    NetworkManager autorice al usuario activo. Al activarlo se corta la conexión Wi-Fi
    normal del equipo (la Ethernet sigue funcionando).
17. **Arrastre real con ratón**: el destino se verificó con clics y movimientos
    inyectados, tanto en la barra como en la cuadrícula del centro. El reordenado del
    centro se comprobó en los dos sentidos (Ajustes de la última fila a la primera y
    de vuelta a una fila intermedia), no solo de izquierda a derecha. `ControlDrag`
    recibe la posición global desde el `MouseArea` que arrastra (no sondea `hyprctl`),
    así que el reordenado y el paso al panel funcionan con el puntero. Falta la prueba
    con el ratón físico. En multimonitor se usa `Quickshell.screens[0]`, habría que
    elegir la pantalla bajo el cursor.
18. **Máximo de escritorios**: los atajos de Hyprland solo llegan a `SUPER+9`. Si se
    configuran más de 9, los escritorios extra solo se alcanzan desde la barra.
19. **Iconos por escritorio**: el escritorio activo muestra hasta 10 apps por defecto (configurable; una ficha por
    app, no por ventana) y resume el resto con `+N`; los inactivos solo muestran su
    número, como en el ejemplo web. Pulsar una ficha enfoca esa ventana. Las apps con
    aviso pendiente llevan un punto. Si una app o un escritorio informan progreso, un
    anillo bordea su ficha; los escritorios inactivos resumen el de sus apps.
20. **Apps de instancia única**: el lanzador ya no arrastra el token de escritorio
    inicial, pero si una app ya está abierta en otro escritorio, su propia lógica puede
    enfocar esa ventana en vez de crear una nueva. Forzar una instancia por escritorio
    exigiría opciones específicas de cada app.
21. **Porcentajes**: cada panel (volumen, brillo, atenuación, batería y Bluetooth)
    tiene su propio interruptor y todos empiezan desactivados. El OSD siempre
    enseña el número y las vistas avanzadas también, para poder ajustar el valor.
22. **Clima**: se consulta a `wttr.in` y la ubicación se deduce por IP. Sin conexión
    el panel muestra un error y el botón «Actualizar»; no hay ubicación manual todavía.
23. **Alarmas y temporizador**: las alarmas se guardan en
    `~/.config/shell/alarms.conf` y suenan con `paplay`/`pw-play`; el temporizador
    sigue corriendo aunque el panel esté cerrado y también suena al terminar. Si
    Quickshell no está abierto no hay alarma, porque no hay un demonio aparte. Si el
    archivo se edita a mano, los cambios se leen al arrancar el shell.
24. **Nombre del hotspot y del Bluetooth**: por defecto se usa `hostname`; el SSID,
    la clave, la banda y la ocultación del hotspot se pueden editar en su engranaje,
    pero no se persisten. El nombre Bluetooth se aplica con `bluetoothctl system-alias`
    y puede requerir permisos de polkit.
25. **Pulsar Super**: está registrado con `bindr`; Hyprland sombrea el atajo cuando se
    combina con otra tecla, así que `SUPER+1..9` y demás combinaciones no deberían
    abrir el lanzador. Falta confirmarlo con el teclado físico.
26. **Panel del reloj**: la altura cambia según la pestaña (calendario, clima, alarmas
    o temporizador). Está anclado a la barra inferior, no a la parte alta.
27. **Bandas Wi-Fi**: `nmcli` solo permite fijar `a` (5 GHz) o `bg` (2.4 GHz); la banda
    de 6 GHz se muestra si la red la anuncia, pero no se puede fijar por separado. Las
    bandas de cada red aparecen como chips 2.4G/5G/6G en la lista y también en el
    engranaje. La preferencia de bandas vive en memoria y se reaplica al perfil
    guardado; si el perfil estaba activo, puede hacer falta reconectar para que el
    cambio surta efecto.
28. **QR del hotspot**: necesita `qrencode` instalado. El PNG se guarda en la caché de
    Quickshell y se regenera al cambiar el SSID, la clave o la ocultación; no se
    persisten esos datos entre sesiones.
29. **Audio**: los nombres largos de PipeWire se recortan en la lista. Cambiar de salida
    o entrada usa el destino predeterminado de PipeWire, no mueve los flujos ya abiertos
    de forma individual.
30. **Bluetooth**: la vista normal y el modo «+» están verificados visualmente, pero el
    emparejamiento real con un dispositivo nuevo sigue pendiente de probar. El nombre
    del adaptador se aplica con `bluetoothctl system-alias` y puede requerir polkit.
31. **Clientes del hotspot**: `ip neigh` solo muestra IPv4, no nombres de equipo, y las
    entradas `STALE` pueden seguir apareciendo hasta que caducan. Si un cliente no
    responde a ARP puede no listarse aunque esté asociado a la red.
32. **Apagado automático**: solo actúa mientras Quickshell está abierto. El hotspot se
    apaga si pasan los minutos configurados sin clientes; el Wi-Fi se apaga si pasan
    los minutos sin conexión y el Bluetooth si no tiene ningún dispositivo conectado.
    Por defecto los tres quedan en 15 min. Mientras el hotspot está activo, el contador
    del Wi-Fi se detiene.
33. **Deslizadores y pasos**: el control de volumen anterior no tenía altura efectiva y
    por eso no aceptaba el arrastre; ahora usa `ShellSlider`. La rueda de la barra y las
    teclas multimedia suben/bajan el volumen y el micrófono de 2 en 2; el brillo, la
    atenuación extra y la luz nocturna van de 5 en 5. El arrastre del deslizador usa el
    mismo paso.
34. **Cierre inmediato de paneles**: en Hyprland, mapear un panel con foco de teclado
    `OnDemand` hacía que la barra perdiera el foco del puntero; el siguiente clic en el
    botón que abrió el panel se ignoraba hasta mover el ratón. `PanelFocusGate.qml`
    retrasa 150 ms el foco de teclado, así el clic de cierre llega al instante. Los
    campos de texto siguen funcionando al pulsarlos; solo hay que tener en cuenta que
    durante esos 150 ms el panel aún no acepta teclado.
35. **Menú contextual de apps**: se abre con clic derecho en una ficha del escritorio
    activo. Ofrece enfocar, maximizar/restaurar, flotante/mosaico, mover al escritorio y
    cerrar la ventana o todas las de esa app. Hyprland no tiene minimizar nativo, así
    que no se ofrece. Se implementó con `PanelWindow` + `HyprlandFocusGrab` porque
    `PopupWindow` de Quickshell 0.3 provocaba un segfault al cerrarse. «Maximizar» usa
    `fullscreen 1` para que la barra siga recibiendo clics; la pantalla completa queda
    para los atajos de Hyprland.
36. **Iconos de widgets**: se resuelven con el tema Breeze (`Quickshell.iconPath`) y se
    tiñen con `ColorOverlay`. Si falta un icono se usa un glifo monocromo, nunca un
    emoji. Al teñir, los iconos multicolor (clima, ajustes) se convierten en siluetas de
    un solo color; es intencionado para que el color comunique el estado. Depende de que
    exista un tema de iconos con los nombres usados (Breeze en esta instalación).
    CPU y GPU usan iconos SVG propios (`icons/cpu.svg`, `icons/gpu.svg`) porque los de
    Breeze se convertían en un cuadrado sólido al teñirlos.
37. **Música (MPRIS)**: el reproductor real manda; si una app expone dos interfaces
    MPRIS (por ejemplo Firefox nativo y `plasma-browser-integration`), aparecen las dos
    en el selector y la barra elige la primera que esté sonando. Los botones de pista
    anterior/siguiente solo funcionan si el reproductor los soporta. La posición y el
    volumen dependen de que el reproductor los publique.
38. **CPU, GPU y Red**: los datos son reales y se muestrean cada segundo con
    `stats.py`. El historial y los totales de sesión viven en memoria y empiezan de cero
    al recargar Quickshell. La GPU se lee de las rutas de `amdgpu` (`card0`); en otra
    GPU o en un portátil híbrido puede faltar algún dato y se muestra «—». El desglose
    de tráfico por aplicación no está implementado; requeriría `nethogs` o privilegios.
39. **VPN**: solo muestra perfiles que ya existan en NetworkManager. Conectar puede
    fallar si faltan secretos (clave privada, contraseña) y el error de `nmcli` se
    enseña en la vista. Para crear un perfil hace falta `nmtui` o importar el `.ovpn`;
    el shell no incrusta un editor de VPN.
40. **Teclado en pantalla**: usa `wvkbd`, que es una superficie `wlr-layer-shell`
    anclada abajo. Mientras está visible **cubre la barra**, porque wvkbd no acepta
    márgenes; se oculta desde su propio icono, desde el centro de control o con
    `qs ipc -c shell call notifications keyboard`. El layout es el internacional de
    wvkbd (QWERTY con acentos y capas), no un layout `es` específico. Requiere el
    paquete `wvkbd`.
41. **Vinculación Bluetooth**: el flujo del panel usa `bluetoothctl` y puede tardar
    hasta 30 s si el dispositivo no responde. La primera prueba con el panel agotó el
    tiempo de espera y mostró el aviso; el emparejamiento manual inmediatamente después
    funcionó. Si falla, hay que dejar el dispositivo en modo vinculación y reintentar.
    Los auriculares pueden desconectarse si otro dispositivo (por ejemplo el móvil) los
    reclama; al estar marcados como «trusted» vuelven a conectarse al pulsarlos.
42. **Batería Bluetooth**: el porcentaje solo aparece si BlueZ expone
    `org.bluez.Battery1`. Los umbrales de color (rojo ≤10 %, naranja ≤20 %, blanco
    >20 %) están implementados, pero solo se han visto con la batería al 100 %; falta
    probarlos con una batería realmente baja.
43. **Etiquetas del cable**: la vista de Wi-Fi muestra la interfaz (`enp4s0`) y el
    botón de desconectar/conectar. No muestra la IP del cable porque
    `NetworkDevice.address` de Quickshell devuelve la MAC; se podría añadir con
    `nmcli -g IP4.ADDRESS` si hace falta.
44. **Persistencia de la vinculación Bluetooth**: al apagar y volver a encender el
    adaptador desde el panel, los Galaxy Buds Pro desaparecieron de BlueZ porque su
    emparejamiento no estaba guardado en `/var/lib/bluetooth/E0:E2:58:AB:78:80/<MAC>/info`
    (solo quedaba la caché del nombre). Si vuelve a pasar, hay que poner el dispositivo
    en modo vinculación y volver a emparejarlo. Mientras esté emparejado y en modo
    «trusted» se reconecta al pulsarlo.
45. **Wi-Fi y Bluetooth bajo demanda**: la búsqueda de redes Wi-Fi solo se activa
    mientras la vista de Wi-Fi está abierta; al cerrarla se detiene. Se busca también
    si ya hay una red conectada, para poder ver otras redes, y el icono de recargar
    pide una pasada nueva. El apagado automático del Bluetooth no distingue tipos de
    dispositivo: si no hay ninguno conectado, el adaptador se apaga tras el tiempo
    configurado.
46. **Ajustes por red Wi-Fi**: el QR, la reconexión automática y «Olvidar red» necesitan
    que la red tenga un perfil guardado en NetworkManager. Para redes nuevas el
    engranaje solo muestra el nombre, la seguridad y las bandas disponibles. El QR se
    regenera al abrir la vista y guarda la clave en el archivo temporal de caché.
47. **Búsqueda Wi-Fi**: mientras la vista de Wi-Fi está abierta la radio sigue
    escaneando; al cerrarla o entrar en los ajustes de una red se detiene. El icono de
    recargar pide una pasada nueva, pero la lista puede tardar unos segundos en
    actualizarse. El desplazamiento con rueda se probó con eventos inyectados.
48. **Atajo del micrófono**: se guarda en `settings.conf` y se registra en Hyprland con
    `hyprctl keyword bind` al arrancar el shell. Antes de registrar se quita una bind
    del mismo atajo para no ejecutar el silencio dos veces. El atajo solo existe
    mientras Hyprland y Quickshell estén corriendo; no se escribe en
    `~/.config/hypr/hyprland.conf`. La captura reconoce CTRL, ALT, SHIFT y SUPER y
    teclas de letras, números, F1–F35, flechas y signos.
49. **Tamaño de los iconos**: `centerIconSize` va de 12 a 32 px y se limita al lado de
    la caja (32 px); por defecto son 20 px. `barIconSize` va de 12 a 26 px (22 px por
    defecto) y define también el ancho del botón: cada control mide el icono más 6 px
    (3 px de relleno a cada lado), como el ejemplo web. La altura sigue fija en
    `Theme.itemHeight` (34 px), así que los botones quedan más juntos y su ancho crece
    con el icono. A 20 px miden 26 px de ancho; a 26 px, 32 px. Música conserva su
    ancho por el texto y el tráfico de red añade 8 px a sus cifras. Las fichas con
    cable + Wi-Fi muestran el segundo icono al 82 %.
50. **Barra automática**: con `autoHideBar` activo la barra se desvanece al dejar de
    usarla y vuelve al acercar el puntero al borde inferior. Mientras hay un panel,
    un menú contextual o un arrastre abierto permanece visible. En ese modo no reserva
    espacio (`exclusiveZone: 0`), así que las ventanas pueden ocupar la zona inferior.
    La franja que la revela mide 4 px; si el puntero se queda en ella, la barra no se
    vuelve a ocultar.
51. **Icono del lanzador**: `Distro.qml` lee `/etc/os-release`. En Debian usa el
    emblema de `desktop-base`; en otras distribuciones busca el logotipo habitual en
    el tema de iconos y, si no existe, usa `icons/grid.svg` (cuatro cuadros).
52. **Anillo de progreso**: `ProgressRing.qml` dibuja un trazo de 2 px sobre un
    rectángulo redondeado, empezando arriba y avanzando en sentido horario. Las apps
    usan su color y los escritorios el acento. `ProgressState.qml` lee
    `~/.local/state/shell/progress`, con líneas `clave=valor`; la clave es la clase de
    la app (`firefox`, `kitty`, `dolphin`...) o `ws:N` para un escritorio. El valor
    admite `34`, `34%` o `0.34`. En el escritorio activo los anillos van en cada ficha
    de app; los inactivos resumen el máximo de sus apps y `ws:N` permite bordear la
    píldora completa. `scripts/shell-progress` actualiza el archivo con bloqueo y
    escritura atómica. No hay detección universal: cada tarea debe informar su
    progreso; el shell no adivina el de cualquier app.
53. **Aviso de la campana**: cuando hay notificaciones se muestra un punto en la
    esquina del icono, no la cantidad, igual que en las fichas de app. Con «No
    molestar» el punto usa el color de peligro.
54. **Trazo único de los iconos**: los widgets usan SVG propios con un `stroke-width`
    de 1.5 a 1.8, el mismo estilo del ejemplo web. Se añadieron Wi-Fi (tres niveles),
    Wi-Fi apagado, cable, Bluetooth, campana, campana silenciada, punto de acceso,
    ajustes, batería (vacía, baja, media, buena y llena) y los controles de música
    (anterior, reproducir, pausa, siguiente). CPU, GPU, red, música, luna, sol, avión,
    atenuación, VPN, teclado y energía ya usaban ese trazo; GPU pasó de 1.5 a 1.8.
    El micrófono (`mic.svg` y `mic-off.svg`) y el volumen (`volume-1/2/3.svg` y
    `volume-off.svg`) usan SVG propios con el mismo trazo.
55. **Modo claro y acento**: `Theme.qml` recalcula toda la paleta cuando cambian
    `themeMode` o `accentColor`. El acento elegido se comparte entre modos, pero en
    claro se oscurece si su luminancia supera 0.38 para que los textos e iconos se
    lean; en oscuro se aclara si baja de 0.55. Por eso el mismo gris se ve claro en
    oscuro y grafito en claro. El cambio es inmediato, sin reiniciar. El shell fija
    `QS_ICON_THEME=breeze-dark`; las apps sí cambian entre `breeze` y `breeze-dark`
    con el modo. Los iconos de widget se tiñen, así que no pierden contraste.
56. **Tema en las apps**: `SettingsState.systemTheme` (activado por defecto) llama a
    `scripts/shell-system-theme` al arrancar y cuando cambian el modo o el acento. El
    script aplica:
    - GTK: `color-scheme`, `gtk-theme`, `icon-theme` y `accent-color` con
      `gsettings`; actualiza `settings.ini` de GTK 3 y 4; y escribe un bloque
      `SHELL-THEME` en sus `gtk.css` con el acento exacto.
    - KDE: escribe `ColorScheme` e `Icons` en `kdeglobals` y ejecuta
      `plasma-apply-colorscheme --accent-color` con `BreezeDark` o `BreezeLight`.
    - El bloque de GTK quita el `@import 'colors.css'` que genera
      `kde-config-gtk-style`, porque esa paleta puede quedarse con el modo anterior;
      el tema Breeze/Breeze-Dark ya aporta las bases correctas.
    - Antes de tocar nada guarda copias en `~/.config/shell/backups/` (solo la primera
      vez): `kdeglobals`, `gtk-3.0/{settings.ini,gtk.css}` y
      `gtk-4.0/{settings.ini,gtk.css}`.
    - Las apps GTK suelen actualizarse en caliente; las de KDE pueden necesitar
      reiniciarse porque fuera de una sesión Plasma no reciben el aviso de cambio.
    - Se puede desactivar con el interruptor **Tema en las apps** de Ajustes.
57. **Distribución del teclado**: `SettingsState.keyboardLayout` (por defecto `es`)
    se aplica en caliente con `hyprctl keyword input:kb_layout`, así que cambia todos
    los teclados conectados sin reiniciar. Se guarda en `settings.conf` y se vuelve a
    aplicar al arrancar el shell. Hay 12 distribuciones en la vista **Teclado** y un
    botón **Cambiar** en Ajustes. El `hyprland.conf` sigue con `es`; si se elige otra,
    el cambio efectivo llega cuando Shell arranca.
58. **Portapapeles**: Quickshell expone `clipboardText`, pero en Wayland se queda
    vacío si ninguna ventana de Quickshell tiene el foco, así que no sirve para
    vigilar lo que copian otras apps. Se incluyeron `wl-paste` y `wl-copy` de
    `wl-clipboard` en `scripts/bin/` (GPLv3, ver `wl-clipboard.copyright`). Un único
    `wl-paste --watch` (protegido con `flock`) llama a `scripts/shell-clipboard-add`,
    que guarda solo texto, sin duplicados y con un máximo de 50 entradas en
    `~/.local/state/shell/clipboard.json` (permisos 600). `ClipboardState.qml` vigila
    ese JSON con `FileView`; al pulsar una entrada, `scripts/shell-clipboard-copy` la
    copia con `wl-copy`. La ficha **Portapapeles** y su vista permiten borrar una
    entrada o todo el historial. El vigilante sobrevive a las recargas de Quickshell
    para no perder copias y el `flock` evita instancias duplicadas.
59. **Minimizar en Hyprland**: no hay minimizar nativo. Se mueve la ventana a
    `special:minimized` y se guarda su escritorio de origen en memoria. La ficha de la
    ventana sigue en la píldora de ese escritorio, atenuada, y al pulsarla se restaura.
    También se puede restaurar desde **Ajustes → Compositor** o con
    `compositorAction restore <dirección>`. Si Quickshell se recarga, se pierde el
    origen: la ficha desaparece hasta reiniciar la ventana o restaurarla desde el
    diagnóstico, que la devuelve al escritorio enfocado.
60. **Maximizar una ventana flotante fijada**: Hyprland no la maximiza mientras está
    fijada (`pin`); el dispatcher responde `ok` pero el estado no cambia. En flotante
    sin fijar sí funciona. El diagnóstico muestra el estado real, no solo la respuesta.
61. **Layout por escritorio**: `keyword workspace N,layout:...` cambia el layout en
    caliente, pero no se guarda en `hyprland.conf`. Tras reiniciar Hyprland vuelve el
    layout de la configuración. La persistencia llegará con los modos por escritorio.
62. **Acciones del compositor con el puntero**: verificadas con `ydotool` sobre un
    Umbriel anidado. Se probaron los seis botones de la barra nativa, el menú
    contextual de la ficha (clic derecho) y su cierre al pulsar fuera. En Hyprland
    siguen verificadas por IPC.

## 8. Cómo ejecutar y probar

### Instalación (ya hecha)

```bash
# Compositor principal, desde el repositorio de Noctalia
sudo apt install -t trixie-backports umbriel
# Respaldo y shell
sudo apt install -t trixie-backports hyprland quickshell
sudo apt install qrencode
```

### Ejecutar el shell

La sesión **Umbriel** está disponible en Noctalia Greeter y es la principal.
`~/.config/umbriel/config.toml` lanza `~/.local/bin/shell-start`, que arranca
`qs -c shell -d` con el tema Qt y el tema de iconos. Hyprland ya no se mantiene.

```bash
# El symlink ya existe: ~/.config/quickshell/shell -> ~/Shell
# Desde una sesión Umbriel:
QS_ICON_THEME=breeze-dark qs -c shell

# Alternativa sin symlink:
QS_ICON_THEME=breeze-dark qs -p ~/Shell
```

### Recargar

Quickshell recarga solo al guardar los `.qml`. Para reiniciar a mano:

```bash
qs kill -c shell   # o: pkill -f 'qs -c shell'
```

### Logs

```bash
qs list --all                                  # instancias vivas
qs log -c shell                                 # logs de Shell
qs ipc -c shell --any-display call launcher toggle
qs ipc -c shell --any-display call notifications toggle
qs ipc -c shell --any-display call calendar toggle
```

`--any-display` hace falta cuando el shell corre en otro compositor (por ejemplo en la
prueba anidada) pero `qs` se ejecuta desde la sesión KDE.

### Prueba aislada (sin cerrar la sesión principal)

Para iterar sobre Umbriel sin reiniciar la sesión se arranca un Umbriel anidado
dentro de la sesión actual y se lanza una copia de Shell con su propio socket:

```bash
# Config de prueba sin autostart (el Shell real ya corre en la sesión padre)
python3 - <<'EOF'
src = open('/home/username/.config/umbriel/config.toml').read()
open('/tmp/opencode/umbriel-test.toml','w').write(
    src.replace('autostart = ["/home/username/.local/bin/shell-start"]', 'autostart = []'))
EOF
umbriel -c /tmp/opencode/umbriel-test.toml -s kitty &

# Copia con ruta propia para que el IPC no choque con la instancia real
cp -a ~/Shell /tmp/opencode/shell-copy
ln -sfn /tmp/opencode/shell-copy ~/.config/quickshell/shell-copy
WAYLAND_DISPLAY=wayland-0 \
UMBRIEL_SOCKET=/run/user/1000/umbriel-wayland-0.sock \
SHELL_COMPOSITOR=umbriel \
QS_ICON_THEME=breeze-dark qs -c shell-copy -d
```

`--any-display` hace falta para hablar con la copia desde la sesión padre.
Las capturas se hacen con `grim -g "<x>,<y> <w>x<h>"` usando la geometría que
devuelve `hyprctl -j clients` para la ventana `wlroots`.

### Atajos configurados (Umbriel)

| Atajo | Acción |
|---|---|
| `Mod` (toque) | Abrir/cerrar el lanzador |
| `Mod + Espacio` | Alternativa para el lanzador |
| `Mod + Tab` | Fijar/ocultar los controles de ventana |
| `Mod + Shift + W` | Alternar Flotante/Mosaico en el escritorio activo |
| `Mod + N` | Abrir/cerrar notificaciones y centro de control |
| `Mod + Shift + N` | Alternar «No molestar» |
| `Mod + C` | Abrir/cerrar calendario |
| `Mod + V` | Portapapeles |
| `Mod + Shift + M` | Silenciar/activar micrófono |
| `Mod + Escape` | Cerrar la sesión (con confirmación) |
| `Mod + Shift + L` | Bloquear sesión (`hyprlock`) |
| `Mod + Return` | Terminal (kitty) |
| `Mod + Q` | Cerrar ventana activa |
| `Mod + T` | Flotante |
| `Mod + P` | Fijar |
| `Mod + M` | Maximizar |
| `Mod + F` | Pantalla completa |
| `Mod + 1..9` | Ir al escritorio 1..9 |
| `Mod + Shift + 1..9` | Mover ventana al escritorio |
| `XF86AudioRaise/Lower/Mute` | Volumen y silencio (con OSD) |
| `XF86MonBrightnessUp/Down` | Brillo real de 5 en 5 (con OSD) |

En Umbriel no existe «mantener Super»: el bind de modificador suelto se dispara
al soltar. El respaldo Hyprland conserva `SUPER` mantenido, `SUPER + Tab` y el
resto de atajos de `~/.config/hypr/hyprland.conf`.

### IPC útil

```bash
# Apariencia
qs ipc -c shell call appearance toggle
qs ipc -c shell call appearance mode light|dark
qs ipc -c shell call appearance accent '#c9b8f5'

# Teclado y portapapeles
qs ipc -c shell call notifications keyboardSettings
qs ipc -c shell call notifications keyboardLayout us
qs ipc -c shell call notifications clipboard
qs ipc -c shell call notifications clipboardCopy 0
qs ipc -c shell call notifications clipboardRemove 0
qs ipc -c shell call notifications clipboardClear

# Compositor: diagnóstico y acciones
qs ipc -c shell call notifications compositor
qs ipc -c shell call notifications compositorAction float 0xDIRECCION
qs ipc -c shell call notifications compositorAction minimize 0xDIRECCION
qs ipc -c shell call notifications compositorAction close 0xDIRECCION
qs ipc -c shell call notifications compositorAction move 0xDIRECCION 2
qs ipc -c shell call notifications compositorAction layout 2 master
qs ipc -c shell call notifications compositorAction workspace 2

# Modo de ventanas y Super
qs ipc -c shell call notifications windowModes
qs ipc -c shell call windows status
qs ipc -c shell call windows choose floating|mosaic
qs ipc -c shell call windows mode 2 mosaic
qs ipc -c shell call windows defaultMode floating
qs ipc -c shell call windows titlebar auto|always|never
qs ipc -c shell call windows toggleFocused
qs ipc -c shell call windows pinned
qs ipc -c shell call windows superPress
qs ipc -c shell call windows superRelease
qs ipc -c shell call windows moveWindow 0xDIRECCION 400 300
```

## 9. Estado actual

- Hyprland reinstalado y config validada (`config ok`): **sí**.
- Quickshell instalado (`0.3.0`): **sí**.
- Symlink de configuración: `~/.config/quickshell/shell -> ~/Shell`.
- `~/.config/hypr/hyprland.conf`: limpio, sin la barra vieja, con
  `env = QT_QPA_PLATFORMTHEME,kde`, `exec-once = env QS_ICON_THEME=breeze-dark qs -c shell`
  y atajos de Shell.
- Barra, lanzador, notificaciones, calendario, menú de energía y bloqueo: **funcionando
  y verificados en la sesión Hyprland real**.
- Panel del reloj: **calendario, clima, alarmas y temporizador** verificados con
  capturas; el clima real se consultó desde `wttr.in`. El calendario permite elegir
  día y volver a hoy; las alarmas persisten en `alarms.conf` y una alarma de prueba
  sonó y apareció como notificación; el temporizador acepta minutos a medida.
- Bluetooth: vista normal limpia con dispositivos vinculados, botón «+» para buscar y
  vincular, y engranaje con nombre visible, «visible para otros» y «emparejable».
  El engranaje, el modo «+» (que ya busca solo) y «Cancelar» se probaron con clics
  inyectados. La vinculación real se probó con unos Galaxy Buds Pro (ver más abajo).
- Wi-Fi: lista con icono de señal, seguridad y botones de banda por red; el cambio de
  banda se aplica al perfil de NetworkManager. Verificado el escaneo y la lógica de
  bandas; el cambio de banda de un perfil se probó con `shell-hotspot` y los botones
  responden a clics reales (inyectados con `ydotool`).
- Hotspot y Bluetooth usan el nombre de la máquina (`Desktop`) como nombre visible
  por defecto.
- **Tema en las apps**: activo por defecto. Se verificó con Firefox y Dolphin en
  claro y oscuro; KDE necesita reiniciar la app para aplicar el cambio. Las copias de
  seguridad de GTK/KDE están en `~/.config/shell/backups/`.
- **Teclado**: la distribución se cambia desde la vista **Teclado** o desde Ajustes;
  se aplica en caliente con `hyprctl` y se guarda en `settings.conf`. Probado
  `es -> us -> es`.
- **Portapapeles**: historial de textos con vigilante único, vista propia y borrado
  individual/total. Probado con textos externos, recarga de Quickshell, copia desde el
  historial y vaciado.
- Hotspot: vista principal con QR WPA y lista de dispositivos conectados; el
  engranaje contiene SSID, clave, banda 2.4/5 GHz, red oculta y apagado automático.
  `nmcli` aceptó la banda `bg` y `802-11-wireless.hidden yes` en pruebas reales; la
  lista de clientes se comprobó con una entrada de vecino simulada. El QR se genera
  con `qrencode` en la caché de Quickshell.
- Apagado automático: **verificado** con 1 minuto tanto en el hotspot (se apagó sin
  clientes) como en el Wi-Fi (la radio pasó a `disabled` sin conexión). Los valores
  normales son 5 y 10 minutos y se guardan en `settings.conf`.
- Volumen y micrófono: listas de todas las salidas/entradas de PipeWire, selección de
  la predeterminada y nivel de micrófono. Cambio de salida y niveles **verificados**
  con `pactl`.
- Deslizador de volumen: **verificado arrastrando con clics inyectados** (de 56% a 8%)
  y la rueda/teclas multimedia usan pasos del 2%.
- Ajustes es un control más de la cuadrícula; al abrirlo muestra el número de
  escritorios y otras preferencias. Ya no hay bloque de preferencias ni barra de
  volumen fija debajo del centro de control.
- Pulsar Super está registrado con `bindr`; la configuración valida `config ok` y el
  atajo aparece en `hyprctl binds`. Falta la prueba con teclado físico.
- Notificaciones agrupadas con icono real, contador con chevron y texto completo al
  pulsar: **verificado**.
- Arrastre de controles **en ambos sentidos** (panel → barra y barra → panel) con
  exclusión mutua: **verificado** con clics inyectados. La posición global llega del
  `MouseArea` que arrastra, no de `hyprctl`. También se **reordena dentro de la barra**:
  soltar un control sobre otro hueco cambia su posición y muestra una marca de
  inserción. Falta probarlo con el ratón físico.
- **Brillo real**: con `ddcutil` se comprobó que el monitor LG acepta DDC/CI. El
  deslizador se arrastró de 100 % a 51 % y `getvcp 10` devolvió 51; al reiniciar
  Quickshell se leyó 51 % del monitor. La atenuación extra y la luz nocturna siguen
  usando el shader de Hyprland.
- **Escritorio activo**: se oculta su número y quedan solo los iconos de sus apps; los
  demás números siguen visibles. Las fichas pasaron a 26 px con iconos de 18 px.
  **Verificado** con captura.
- Punto de acceso Wi-Fi: **verificado** de extremo a extremo (`shell-hotspot` se activa
  y se apaga; la Wi-Fi normal vuelve a quedar desconectada).
- Documentación: **este archivo**.
- **Widgets nuevos**: Música, Procesador, Gráficos, Red, VPN y Bluetooth. La barra
  arranca con música, Wi-Fi, Bluetooth, volumen, CPU, GPU y Red; todos se pueden mover
  al centro de control. Verificados visualmente y con datos reales.
- **Música**: con Firefox reproduciendo una pista real se comprobó la portada, el
  título, el artista, el progreso y los controles. El botón de reproducir/pausar se
  probó con un clic inyectado y el estado cambió en MPRIS. El selector de reproductor
  aparece cuando hay más de uno.
- **CPU/GPU/Red**: `stats.py` lee uso, temperatura, frecuencia, potencia y VRAM de la
  GPU, y tráfico/latencia/interfaz de la red. Los valores se contrastaron con
  `/proc/stat`, `/sys/class/hwmon`, `/sys/class/drm` y el ping al gateway. El historial
  y los picos se reinician desde la propia vista. `showTemps` se guardó y releyó desde
  `settings.conf`.
- **VPN**: la vista vacía explica cómo crear un perfil; se probó con un perfil
  WireGuard temporal (`shell-test`) que apareció en la lista y se borró después. No se
  probó una conexión real porque no hay perfiles configurados.
- **Teclado en pantalla**: `wvkbd` se instaló y se verificó mostrarlo y ocultarlo desde
  IPC y desde la cuadrícula. Falta probar la escritura en un campo de texto real. Mientras
  está visible cubre la barra (limitación de wvkbd).
- **Bluetooth real**: se emparejaron unos Galaxy Buds Pro con `bluetoothctl`; quedaron
  vinculados, de confianza y conectados. El panel muestra «Conectado · 100 %», la barra
  muestra el icono con «100 %» y el dispositivo aparece como sink de PipeWire. Se
  probó desconectar y reconectar pulsando la fila. El primer intento desde el panel
  agotó el tiempo y mostró el aviso; el emparejamiento manual funcionó. Se subió el
  límite a 30 s. Falta probar los colores rojo/naranja con una batería baja real.
- **Ethernet + Wi-Fi**: con `enp4s0` y `wlp5s0` conectados a la vez, la barra muestra
  los dos iconos juntos. La vista de Wi-Fi muestra «Ethernet conectado» y el botón
  «Desconectar»; se probó a desconectar y reconectar el cable, y la barra volvió a
  mostrar el icono de cable con el de Wi-Fi.
- **Iconos**: los widgets pedidos usan los SVG exactos del diseño (música, luna, escudo,
  avión, sol, atenuación, red, teclado, energía, bloqueo, reinicio y pestañas del reloj);
  cierre de sesión usa un SVG propio con el mismo trazo. CPU y GPU siguen con SVG
  propios teñidos por estado; el resto usa Breeze. No quedan emojis en los QML.
- **Abrir/cerrar widgets con el mismo clic**: verificado con clics inyectados en los
  iconos de Volumen y Música: el primer clic abre su vista y el segundo la cierra. La
  «×» de la cabecera del panel se eliminó; la campana sigue alternando el panel.
- **Música**: la barra vuelve a mostrar portada y artista. Se corrigió la selección
  cuando Firefox expone dos reproductores (se prefiere `plasma-browser-integration`,
  que trae carátula) y se centró verticalmente la portada de 22 px.
- **Volumen y micrófono**: la barra, la ficha del centro de control y el OSD usan el
  mismo dibujo. El volumen cambia entre uno, dos y tres arcos y la variante tachada;
  el micrófono usa `mic.svg` y `mic-off.svg`. Todos son SVG propios y se ven igual
  en cualquier tema.
- **Tráfico de red**: la píldora de la barra se ajusta al contenido (sin ancho fijo) y
  usa menos relleno; ya no queda más ancha que el número, la unidad y las flechas.
- **Bluetooth (búsqueda)**: se eliminó el interruptor de búsqueda del apartado
  «Vincular dispositivo». Al entrar se activa `discovering`, y «Cancelar» o salir de la
  vista lo apagan. Probado con clics inyectados (`Discovering: yes` → `no`).
- **Menú de energía**: bloqueo, cierre de sesión, reinicio y apagado usan SVG del
  diseño o del mismo estilo; verificado con captura.
- **Compositor (fase 2)**: `HyprlandBackend.qml` ya ejecuta acciones reales sobre
  ventanas y escritorios. Probado con una ventana `kitty` desechable: flotar, fijar,
  maximizar/restaurar, pantalla completa, minimizar a `special:minimized`, restaurar
  al escritorio original, mover entre escritorios, enfocar una minimizada, cambiar
  `dwindle`/`master` en un escritorio y cerrar. El diagnóstico permite probar todo
  con chips visibles; el menú contextual de la barra y el clic de escritorios usan el
  mismo contrato. `closewindow` de Hyprland no cerraba con dirección y se sustituyó
  por `killwindow`.
- **Fichas por ventana y minimizadas visibles**: la píldora de escritorio ya no agrupa
  por aplicación. Cada ventana tiene su propia ficha, así que dos terminales muestran
  dos iconos y el menú contextual actúa sobre la ventana concreta. Las minimizadas se
  quedan en su escritorio de origen con la ficha atenuada y se restauran al pulsarlas.
  Probado con dos `kitty` en el mismo escritorio: aparecen las dos fichas, minimizar
  una deja su icono al 40 % de opacidad y restaurarla lo devuelve a opacidad completa.
- **Siguiente paso**: probar con ratón físico el arrastre de la barra de título, los
  clics de los controles de ventana y el modo fijado; persistir el orden de la barra y
  del centro; y probar el backend de Umbriel en una sesión real. Quedan para después
  los efectos (blur/shaders), el orden persistente de la barra, los auriculares fuera
  de BlueZ, los colores de batería baja, la escritura con teclado en pantalla y la
  apariencia.

### Archivos del proyecto

| Archivo | Función |
|---|---|
| `shell.qml` | Entrada; instancia barra y paneles. |
| `CompositorState.qml` | Contrato común con el compositor: detección, backend intercambiable, ventanas, escritorios, foco, capacidades y acciones. |
| `HyprlandBackend.qml` | Backend real de Hyprland: normaliza ventanas y escritorios, declara capacidades y ejecuta enfocar, cerrar, flotar, fijar, maximizar, pantalla completa, mover, minimizar/restaurar, cambiar escritorio y layout. Completa `floating`, `pinned` y geometría con `hyprctl -j clients`. |
| `UmbrielBackend.qml` | Segundo backend del contrato: consulta `umbriel windows --json` y `umbriel workspaces --json`, y ejecuta acciones con `umbriel msg`. Sin probar en una sesión Umbriel real. |
| `WorkspaceModeState.qml` | Modo por escritorio: «flotante» suelta las ventanas existentes y las nuevas; «mosaico» las vuelve a mosaicar. Se guarda en `SettingsState` y actúa solo a través de `CompositorState`. |
| `SuperState.qml` | Gesto de Super: toque corto abre el lanzador, mantener 220 ms muestra los controles, y el modo se puede fijar sin mantener la tecla. |
| `WindowChrome.qml` | Barra de título y controles por ventana con `PanelWindow`: icono, título, fijar, flotante/mosaico, mover de escritorio, maximizar, minimizar y cerrar. Arrastra con `moveWindowTo`; la máscara solo cubre la barra. |
| `WindowModeBar.qml` | Barra flotante del modo ventanas (ya no se instancia): el cambio de modo vive ahora en la píldora del escritorio activo. |
| `WelcomeMode.qml` | Elección inicial entre «Flotante / Como Windows» y «Mosaico», con la barra de título opcional. |
| `WindowLook.qml` | Icono, nombre, color y pantalla compartidos por la barra de título, el overlay y la barra de minimizadas. |
| `ChromeButton.qml` | Botón compacto reutilizable de los controles de ventana. |
| `CompositorChip.qml` | Chip reutilizable de las acciones del diagnóstico; acento cuando está activo y rojo para lo destructivo. |
| `Bar.qml` | Barra inferior: escritorios, reloj, controles dinámicos, batería, bandeja, campana, energía, marca de inserción al reordenar y ocultación automática con franja de 4 px para revelarla. |
| `Distro.qml` | Distribución leída de `/etc/os-release`; elige el logotipo del lanzador y cae a `icons/grid.svg` cuando no hay uno disponible. |
| `WorkspacePill.qml` | Indicador de escritorio: el activo muestra hasta 10 fichas de ventanas (configurable en Ajustes; icono de 22 px por defecto) y oculta su número; los demás solo el número. Hay una ficha por ventana, aunque sean de la misma app, y las minimizadas siguen visibles atenuadas en su escritorio de origen. Al pulsar una ficha enfoca (o restaura) esa ventana; con clic derecho abre su menú contextual. Los clics de ventana y escritorio pasan por `CompositorState`. |
| `AppContextMenu.qml` | Menú contextual de una ventana: enfocar, maximizar/restaurar, minimizar/restaurar, flotante/mosaico, mover al escritorio y cerrar esa ventana. Las acciones pasan por `CompositorState`. |
| `AppMenuItem.qml` | Fila reutilizable del menú contextual, con icono del tema o glifo de respaldo. |
| `ShellIcon.qml` | Icono de widget del tema Breeze con color de estado mediante `ColorOverlay`; sustituye a los emojis. |
| `SettingsState.qml` | Preferencias persistentes: modo claro/oscuro, color de acento, tema en las apps, distribución del teclado, máximo de escritorios, filas visibles y tamaños de iconos del centro y de la barra, porcentajes por panel (volumen, brillo, atenuación, batería y Bluetooth), temperatura en la barra, atajo del micrófono, ocultación automática de la barra, apagados automáticos, modo avión, redes ocultas, modo por defecto y por escritorio, y barra de título (`auto`/`always`/`never`). |
| `HostInfo.qml` | Nombre de la máquina, usado por el hotspot y el Bluetooth. |
| `WeatherState.qml` | Clima actual y previsión desde `wttr.in`, sin clave de API. |
| `ClockTab.qml` | Pestaña reutilizable del panel del reloj. |
| `Launcher.qml` | Lanzador de apps con búsqueda y teclado. |
| `SidePanel.qml` | Panel único pegado a la barra: en modo completo, notificaciones arriba y centro de control de alto fijo abajo; en modo rápido (controles de la barra), solo la vista avanzada del control, sin notificaciones. |
| `QuickPanelState.qml` | Estado del panel rápido: vista activa, ancla bajo el control pulsado y cierre al abrir otro panel. |
| `PanelFocusGate.qml` | Retrasa 150 ms el foco de teclado de los paneles para que el clic de cierre llegue a la barra sin mover el ratón. |
| `NotificationList.qml` | Avisos agrupados por app, icono real, contador y chevron a la derecha, y texto completo al pulsar. El borrado individual está oculto por ahora; queda «Limpiar todo». |
| `ControlCenterContent.qml` | Cuadrícula fija de dos columnas, ajustes por red Wi-Fi (QR, reconexión, olvidar) y vistas avanzadas de Wi-Fi, Bluetooth, volumen, micrófono, luz nocturna, brillo, atenuación extra, punto de acceso, música, rendimiento, red, VPN, teclado, portapapeles, ajustes, modo de ventanas y diagnóstico del compositor. Ajustes incluye tema, acento, tema en las apps, distribución del teclado, tamaños, modo por defecto, barra de título y acceso al compositor. |
| `MusicState.qml` | Reproductor MPRIS activo, selección de reproductor y controles (play/pausa, pista, posición, volumen). |
| `MusicView.qml` | Vista de Música: portada, progreso, controles y selector de reproductores. |
| `BarMusic.qml` | Reproductor compacto de la barra; muestra título/artista y cambia a controles al pasar el ratón. |
| `SystemStats.qml` | Estado de CPU, GPU y red: muestras, historial, picos, totales y formato de unidades. |
| `stats.py` | Muestreador real de `/proc/stat`, `/proc/net/dev`, `hwmon`, `drm` y latencia al gateway. |
| `PerfView.qml` | Vista de Procesador/Gráficos: uso, temperatura, frecuencia, potencia, VRAM, historial y núcleos. |
| `NetView.qml` | Vista de Red: descarga/subida, sesión, picos, latencia, interfaz e IP. |
| `HistoryBars.qml`, `StatCell.qml` | Gráfico de barras reutilizable y celda de dato de las vistas de rendimiento/red. |
| `VpnState.qml` | Perfiles VPN/WireGuard de NetworkManager y conexión/desconexión con `nmcli`. |
| `VpnView.qml` | Vista de VPN con la lista real de perfiles. |
| `KeyboardState.qml` | Teclado en pantalla con `wvkbd`; estado, disponibilidad y proceso. |
| `icons/cpu.svg`, `icons/gpu.svg` | Iconos propios de chip y tarjeta gráfica para teñir por estado. |
| `ShellIcons.qml` | Rutas de los iconos SVG copiados del diseño (`music`, `moon`, `shield`, `plane`, `sun`, `dim`, `net`, `keyboard`, `clipboard`, `power`, `calendar`, `cloud`, `alarm`, `timer`, `lock`, `restart`, `logout`). |
| `LevelIcon.qml` | Icono de nivel para volumen y micrófono. El volumen usa `icons/volume-1/2/3.svg` y `volume-off.svg`; el micrófono, `icons/mic.svg` e `icons/mic-off.svg`. |
| `icons/music.svg`, `icons/moon.svg`, `icons/shield.svg`, `icons/plane.svg`, `icons/sun.svg`, `icons/dim.svg`, `icons/net.svg`, `icons/keyboard.svg`, `icons/clipboard.svg`, `icons/power.svg`, `icons/calendar.svg`, `icons/cloud.svg`, `icons/alarm.svg`, `icons/timer.svg`, `icons/lock.svg`, `icons/restart.svg`, `icons/logout.svg` | Iconos exactos del sprite del diseño (o del mismo trazo), teñidos con `ShellIcon`. |
| `icons/mic.svg`, `icons/mic-off.svg` | Micrófono normal y silenciado con trazo propio, para que la barra, el centro de control y el OSD no dependan del tema. |
| `icons/volume-1.svg`, `icons/volume-2.svg`, `icons/volume-3.svg`, `icons/volume-off.svg` | Volumen con uno, dos o tres arcos y variante tachada, con el mismo trazo que los demás iconos. |
| `icons/wifi-1.svg`, `icons/wifi-2.svg`, `icons/wifi-3.svg`, `icons/wifi-none.svg`, `icons/wifi-off.svg` | Señal Wi-Fi por niveles y variantes sin señal o apagada, con trazo de 2,2 px; se usan en la barra y en la lista de redes. |
| `icons/check.svg`, `icons/eye.svg`, `icons/eye-off.svg`, `icons/plus.svg`, `icons/usb.svg` | Confirmar la contraseña de una red, mostrarla u ocultarla dentro de la propia fila, abrir el formulario de red oculta y reconocer una interfaz USB. |
| `WifiPasswordRow.qml` | Campo de contraseña compartido por las redes normales y el formulario de red oculta: campo redondeado, ojo, check y cancelar. |
| `icons/grid.svg` | Cuadrícula de cuatro cuadros usada como logotipo de respaldo del lanzador. |
| `BarControl.qml` | Icono de un control del centro de control colocado en la barra; alterna su vista al pulsarlo, incluye batería Bluetooth, los dos iconos de cable + Wi-Fi, el tráfico de red numérico y los iconos de nivel. El botón mide el icono más 6 px de relleno, así que `barIconSize` cambia también su ancho. |
| `ProgressRing.qml` | Anillo de progreso de 2 px sobre un rectángulo redondeado; se dibuja con Canvas desde el borde superior en sentido horario. |
| `ProgressState.qml` | Lee tareas de `~/.local/state/shell/progress`, las normaliza a 0..1 y las asocia a clases de app o a escritorios (`ws:N`). |
| `scripts/shell-progress` | CLI para fijar, borrar y listar el progreso de apps y escritorios con escritura atómica. |
| `ClipboardState.qml` | Historial de textos: vigila `~/.local/state/shell/clipboard.json` con `FileView`, copia con `wl-copy`, reordena, borra entradas y vacía el historial. |
| `scripts/shell-clipboard-add` | Recibe el texto de `wl-paste --watch`, elimina duplicados y guarda las 50 entradas más recientes con permisos 600. |
| `scripts/shell-clipboard-copy` | Copia al portapapeles la entrada del índice indicado y la mueve al principio. |
| `scripts/shell-clipboard-watch` | Arranca un único `wl-paste --watch` protegido con `flock`; si ya hay otro, sale sin error. |
| `scripts/bin/wl-paste`, `scripts/bin/wl-copy` | Binarios de `wl-clipboard` 2.2.1 extraídos del paquete Debian; no requieren instalación con `sudo`. GPLv3 en `scripts/bin/wl-clipboard.copyright`. |
| `BarState.qml` | Lista y orden de controles fijos de la barra (`music`, `wifi`, `bluetooth`, `volume`, `cpu`, `gpu`, `net` por defecto), orden propio de la cuadrícula del centro (incluye teclado y portapapeles), controles que quedan en cada sitio y `move()`/`moveCenter()` para reordenar. |
| `ControlDrag.qml` | Arrastre de controles en ambos sentidos, reordenación en vivo del centro con hueco de destino, reordenación en la barra y detección del puntero/panel/barra con coordenadas que envía el `MouseArea`. |
| `PanelScrollState.qml` | Canal para desplazar el centro de control cuando la rueda no está ajustando el valor de una ficha. |
| `DisplayState.qml` | Brillo real por DDC/CI (`ddcutil`) con respaldo al shader; atenuación extra y luz nocturna por shader de Hyprland, con sus niveles guardados en `display.conf`. |
| `HotspotState.qml` | Punto de acceso Wi-Fi con NetworkManager (`nmcli`), perfil manual con banda, red oculta y QR WPA; clientes vía `ip neigh`. |
| `AutoOffState.qml` | Apagado por inactividad del hotspot, del Wi-Fi y del Bluetooth según los minutos configurados. |
| `AirplaneState.qml` | Modo avión explícito: apaga Wi-Fi, Bluetooth y hotspot, permite reactivar radios a mano y restaura las que estaban encendidas al salir. |
| `WifiState.qml` | Bandas, seguridad y señal de las redes vía `nmcli`; perfil, QR compartible y reconexión automática de cada red; preferencias de banda por SSID y conexión manual a redes ocultas (`hidden yes`). |
| `EthernetState.qml` | Diagnóstico por interfaz cableada: muestra si la controla NetworkManager, ifupdown o dhcpcd. Mantiene una etiqueta por nombre para las listas con varias Ethernet. |
| `scripts/wifi-profile.py` | Lee el perfil de una red, genera el QR WPA, cambia `connection.autoconnect` y olvida la red desde NetworkManager. |
| `ShellSlider.qml` | Deslizador compacto de las vistas avanzadas, con pasos del 2%. |
| `CalendarPanel.qml` | Panel del reloj pegado a la barra: calendario, clima, alarmas y temporizador. |
| `PowerMenu.qml` | Menú de energía en su propia capa. |
| `CcItem.qml`, `ShellSwitch.qml` | Ítem compacto (con icono del tema o icono de nivel), rueda para ajustar el control, reordenación dentro de la cuadrícula e interruptor reutilizables. |
| `Audio.qml` | Estado compartido de PipeWire: salidas, entradas, predeterminadas, volumen y micrófono. |
| `Osd.qml` | OSD sobre la barra para volumen, micrófono, brillo, atenuación extra y luz nocturna. |
| `Theme.qml` | Colores, medidas y colores de estado. Deriva toda la paleta de `themeMode` y `accentColor`: superficies y textos cambian entre oscuro y claro, y el acento se aclara u oscurece según el fondo. |
| `scripts/shell-system-theme` | Propaga modo y acento a GTK y KDE: `gsettings`, `settings.ini` y `gtk.css` de GTK 3/4, `kdeglobals` con `kwriteconfig6` y, si existe, `plasma-apply-colorscheme`. Guarda copias de seguridad la primera vez. |
| `Fechas.qml` | Nombres de meses/días en español. |
| `LauncherState.qml`, `CalendarState.qml`, `PowerState.qml`, `OsdState.qml` | Estado de los paneles. |
| `NotificationState.qml` | Estado del panel y de su vista (`panelView`), `NotificationServer` de D-Bus, hora de llegada y agrupación por app. |
| `Pill.qml` | Contenedor de widgets de la barra, con relleno horizontal configurable y envío de la posición al arrastrar. |
| `scripts/test-nested.sh` | Prueba aislada con Hyprland anidado y capturas. |
| `~/.config/hypr/hyprlock.conf` | Pantalla de bloqueo. |
| `~/.config/hypr/fecha-shell.sh` | Fecha en español para hyprlock. |

## 10. Preguntas abiertas

- ~~¿Dónde debe aparecer una ventana minimizada para poder restaurarla?~~ Resuelto: la
  píldora del escritorio conserva la ficha atenuada y la barra de modo ventanas añade
  una lista de minimizadas con su icono para restaurarlas durante Super.
- ~~¿El modo inicial debe ser «Como Windows» (flotante) o «Mosaico»?~~ Resuelto: la
  pantalla de bienvenida pregunta una vez y recomienda **Flotante / Como Windows**.
- ~~¿Dónde conviene poner el selector de modo por escritorio?~~ Resuelto: en **Ajustes
  → Modo de ventanas**, en la barra del overlay de Super y con `Super+Shift+W` para el
  escritorio activo.
- ~~¿La barra de título nativa debe empezar en Automática?~~ Resuelto: `Automática` por
  defecto; `Siempre` para ventanas flotantes y `Nunca` deja solo los controles de Super.
- ¿Instalamos Umbriel en una sesión aparte (`shell-umbriel`) para probar el segundo
  backend sin tocar la sesión diaria de Hyprland? El backend ya existe, pero no se ha
  probado en una sesión Umbriel real.
- ¿Qué cambios concretos quieres hacer al diseño? (lista de “esto sí / esto no”).
- ¿La barra se queda abajo o quieres arriba/abajo configurable desde el inicio?
- ¿Los escritorios deben ser fijos (1..N) o dinámicos según se usen?
- La interfaz está en español por defecto (`Fechas.qml`). ¿La quieres también en inglés
  o con selector de idioma?
- ¿Se persisten los controles de la barra, su orden y las opciones de visualización
  (brillo, luz nocturna, etc.) o se quedan como estado de sesión?
- El teclado en pantalla de `wvkbd` cubre la barra mientras está visible. ¿Basta con
  ocultarlo desde el centro de control o quieres intentar dockearlo encima de la barra
  con otra solución?
- ¿Hace falta desglose de tráfico por aplicación (requiere `nethogs`/privilegios) o
  basta con el total de la interfaz activa?

## 11. Registro de cambios

### 2026-11-03

- Hyprland reinstalado desde `trixie-backports`; `Hyprland --verify-config` → `config ok`.
- Quickshell `0.3.0` instalado y configurado como `qs -c shell`.
- Config de Hyprland limpiada: fuera los dos `exec-once` de `shell-bar`, dentro
  `exec-once = qs -c shell`, atajos de lanzador/notificaciones/calendario/bloqueo y
  blur activado.
- Barra funcional: escritorios 1–10, reloj en español, volumen PipeWire, red
  (Ethernet/Wi-Fi), batería condicional, bandeja SNI (oculta iconos rotos), campana,
  menú de energía.
- Lanzador funcional con 57 apps, búsqueda, teclado y cierre con Esc.
- Notificaciones: servidor D-Bus, panel, contador, limpiar, «No molestar».
- Calendario mensual en español con navegación.
- Pantalla de bloqueo `hyprlock` con hora y fecha en español; `SUPER+L` y menú de energía.
- Menú de energía en una capa propia (la barra de 40 px recortaría cualquier menú
  anclado encima).
- La barra reserva `barHeight + edge` (48 px) y las ventanas ya no quedan debajo.
- **Validado en la sesión Hyprland real** (1920×1080, monitor LG): barra, notificaciones
  reales con `notify-send`, «No molestar», limpiar, lanzador, calendario y menú de energía.
- OSD de volumen y silencio compartido con la barra (`Audio.qml`, `Osd.qml`), con
  teclas multimedia.
- Panel lateral unificado: la campana (y `SUPER+N`) abre notificaciones y centro
  de control como dos tarjetas redondeadas independientes, con fondo y borde
  propios, unidas solo por un hueco de 8 px. Con la barra arriba, el centro de
  control va primero y las notificaciones debajo; con la barra abajo se
  invierte. Los controles de la barra abren esa misma superficie en modo rápido,
  solo con su vista avanzada y sin notificaciones. En Ajustes del shell,
  «Notificaciones y control juntos» permite separarlos en dos iconos de barra
  (campana y cuadrícula).
- Corregido tras revisión: se eliminó el icono ⚙ y el panel separado de centro de
  control; ahora ambos apartados viven en `SidePanel.qml`.
- Panel pegado a la barra (abajo a la derecha) y centro de control compacto en
  cuadrícula 2×3: Wi-Fi, Bluetooth, Volumen, Micrófono, No molestar y Modo avión,
  más slider de volumen. Las opciones avanzadas se abren al pulsar el nombre del
  control y se vuelven con `‹`; el modo avión es la excepción y solo alterna.
- Teclado de Hyprland cambiado a español (`kb_layout = es`).
- Notificaciones con el icono real de la app y agrupadas por aplicación: el grupo
  muestra el aviso más reciente y su contador; al pulsarlo se despliegan los demás.
  El área de notificaciones crece hasta 360 px y el panel hasta 900 px.
- Quickshell se lanzaba con `QT_QPA_PLATFORMTHEME=gtk3` para que Qt resolviera los
  iconos del tema `breeze-dark` (sin eso solo usaba hicolor y faltaban casi todos).
  Desde el 2026-11-04 usa `QS_ICON_THEME=breeze-dark`, que solo afecta a los iconos
  del shell y no al tema de las apps.
- Script `scripts/test-nested.sh` con capturas automáticas y limpieza segura de la
  instancia anidada (PIDs reales, sin `pkill` por nombre de comando).

### 2026-11-04

- El contador de cada grupo lleva el chevron de desplegar dentro de la misma burbuja,
  junto al icono de la app. Al desplegar se listan todos los avisos del grupo.
- Los avisos largos se pueden abrir con un clic: el título y el cuerpo se ajustan y
  muestran el texto completo; el chevron solo aparece si el texto está recortado.
- Los controles del centro de control se pueden arrastrar a la barra y viceversa. Un
  control solo existe en un sitio: al soltarlo en la barra desaparece de la cuadrícula
  y al devolverlo al panel desaparece de la barra. Se eliminó el clic derecho para
  quitar controles. La barra arranca con `music`, `wifi`, `bluetooth`, `volume`, `cpu`,
  `gpu` y `net`.
- «No molestar» y «Limpiar» del panel y los iconos de la barra usan iconos del tema o
  SVG propios del diseño; el estado de la vista avanzada vive en
  `NotificationState.panelView`.
- «No molestar» sale del centro de control (sigue en la cabecera de notificaciones) y
  su hueco lo ocupa la luz nocturna.
- Nuevos controles: brillo, atenuación extra y punto de acceso Wi-Fi. Brillo y
  atenuación usan un shader global de Hyprland; la luz nocturna añade un tono cálido
  regulable. El punto de acceso usa `nmcli` con el perfil `shell-hotspot`.
- Los iconos del centro de control pasan a usar el tema `breeze-dark`, con emoji de
  respaldo. Se añadió `ShellSlider.qml` para los deslizadores de las vistas.
- La burbuja con el número de avisos y el chevron de expandir se movió al lado derecho
  de la cabecera del grupo. Se ocultó por ahora el borrado individual (la «×»); el
  botón de «Limpiar todo» sigue en la cabecera del panel.
- La barra muestra 1..9 escritorios por defecto y el máximo es configurable desde
  **Ajustes**. `WorkspacePill.qml` enseña las apps abiertas del escritorio activo y
  permite enfocar una ventana pulsando su icono.
- `SettingsState.qml` guarda el modo claro/oscuro, el color de acento, el máximo de
  escritorios, los tamaños de iconos del centro y de la barra, la ocultación
  automática de la barra y los porcentajes de cada panel en
  `~/.config/shell/settings.conf`.
- El lanzador limpia `HL_INITIAL_WORKSPACE_TOKEN` al abrir apps; se probó abriendo Ark
  desde el escritorio 2 y la ventana apareció en el 2.
- **Ajustes** pasa a ser un control más de la cuadrícula (icono `preferences-system`),
  no un bloque fijo. Se eliminaron la barra de volumen compacta y el bloque de
  preferencias que había debajo del centro de control.
- El número del escritorio activo se oculta; en su lugar solo se ven los iconos de sus
  apps. Los escritorios inactivos conservan el número. Si el activo no tiene ventanas,
  queda un punto discreto.
- **Pulsar y soltar Super** abre el cajón de apps mediante `bindr` en Hyprland;
  `SUPER+Espacio` se mantiene.
- **Bluetooth**: nombre visible editable (por defecto el de la máquina), interruptores
  de visible para otros, emparejable y búsqueda, lista de dispositivos detectados y
  acciones de emparejar/conectar/olvidar.
- **Nombre de la máquina**: `HostInfo.qml` lee `hostname`; el hotspot usa `Desktop`
  como SSID por defecto y el Bluetooth lo usa como alias.
- **Panel del reloj**: ahora está anclado a la barra inferior y añade pestañas de
  clima, alarmas y temporizador. El clima usa `wttr.in`; las alarmas y el temporizador
  avisan con `notify-send`. La altura se adapta a la pestaña activa.
- **Wi-Fi**: la lista muestra icono de intensidad, seguridad y botones de banda por
  red. Las bandas activas se aplican al perfil guardado con
  `802-11-wireless.band`; siempre queda al menos una encendida.
- **Bluetooth**: la vista normal queda limpia con los dispositivos vinculados y un
  botón «+» para vincular. El engranaje abre nombre visible, «visible para otros» y
  «emparejable». El modo «+» enciende la búsqueda y lista solo los dispositivos sin
  vincular, con acción de vincular.
- **Punto de acceso**: añadidas banda 2.4/5 GHz y tarjeta QR WPA que se regenera al
  cambiar SSID o clave. `qrencode` genera el PNG en la caché de Quickshell.
- **Volumen y micrófono**: listas de todas las salidas y entradas de PipeWire, con la
  predeterminada marcada; el micrófono tiene control de nivel además del silencio.
- **Audio.qml**: enumera nodos físicos de salida/entrada, cambia el destino
  predeterminado con `Pipewire.preferredDefaultAudioSink/Source` y mantiene todos los
  nodos vivos con `PwObjectTracker`.
- **Punto de acceso**: la vista principal deja solo el QR y los dispositivos
  conectados. El engranaje reúne red, clave, banda, «Ocultar red» y el apagado
  automático. La lista de clientes se lee de `ip neigh` y se refresca cada 4 s.
- **Wi-Fi**: engranaje con apagado automático si el equipo se queda sin conexión;
  la espera se elige entre 5, 10, 15 y 30 minutos. La cuenta no corre mientras la
  vista Red está abierta.
- **Apagado automático**: nuevo `AutoOffState.qml`, creado desde `SidePanel.qml`.
  Apaga el hotspot sin clientes y el Wi-Fi sin conexión; no toca el Wi-Fi mientras el
  hotspot está activo. Los valores se guardan en `settings.conf`.
- **Pasos de 2%**: rueda de la barra, teclas multimedia (`hyprland.conf`) y
  deslizadores. El deslizador de volumen pasa a `ShellSlider`, que tiene altura real y
  acepta el arrastre; antes el `Slider` tenía altura implícita cero.
- **Iconos del escritorio**: se había perdido la clase de las ventanas porque
  `HyprlandToplevel.lastIpcObject` llega vacío en Quickshell 0.3. Ahora la clase se lee
  de `toplevel.wayland.appId`, con `lastIpcObject` como respaldo. `WorkspacePill.qml`
  copia el ejemplo web: hasta 10 fichas de color por app (configurable), `+N` para el resto, punto de
  aviso y atenuación si la ventana está minimizada. El clic enfoca la ventana; Hyprland
  necesita la dirección con prefijo `0x`, que Quickshell no incluye.
- **Cierre rápido de paneles**: abrir el panel de notificaciones, el del reloj o el de
  energía hacía que la barra perdiera el foco del puntero hasta mover el ratón, así que
  el segundo clic en el mismo botón se ignoraba. Se añadió `PanelFocusGate.qml`, que
  mantiene el panel sin foco de teclado durante 150 ms (lo justo para que el nuevo
  surface se mapee) y después lo activa. Verificado con clics inyectados: los tres
  paneles se cierran al instante sin mover el ratón y los campos de texto siguen
  aceptando teclado.
- **Menú contextual de apps**: clic derecho en una ficha del escritorio activo abre un
  menú estilo KDE/Windows con enfocar, maximizar/restaurar, flotante/mosaico, mover al
  escritorio y cerrar la ventana o todas las de la app. Un clic fuera o Escape lo
  cierran. Se usa `PanelWindow` + `HyprlandFocusGrab` porque `PopupWindow` de
  Quickshell 0.3 segfaulteaba al cerrarse. Verificado con clics inyectados: maximizar y
  restaurar, flotante, mover al escritorio 2, cerrar una ventana y cerrar dos ventanas
  de la misma app, sin crashes nuevos.
- **Iconos reales y colores de estado**: nuevo `ShellIcon.qml`, que carga el icono del
  tema Breeze y lo tiñe con `ColorOverlay`. Se sustituyeron los emojis de la barra
  (campana, energía y batería), del panel de notificaciones (No molestar, limpiar y
  estado vacío), del centro de control, del OSD de volumen, de las pestañas y el clima,
  del menú de energía y del menú contextual. Ahora el color indica el estado: acento
  para activo, ámbar para aviso, rojo para peligro, cálido para luz nocturna y gris para
  apagado. También se añadieron los iconos de clima de Breeze y los del menú de energía.
- **Música (MPRIS)**: nuevo `MusicState.qml` sobre `Quickshell.Services.Mpris`, con
  reproductor compacto en la barra (`BarMusic.qml`) y vista completa (`MusicView.qml`)
  con portada, título, artista, progreso, controles y selector de reproductores. La
  barra cambia de título/artista a controles al pasar el ratón. Verificado con una pista
  real de Firefox: el botón de pausa cambió el estado en MPRIS.
- **Rendimiento y red reales**: nuevo `stats.py` + `SystemStats.qml`, que muestrean CPU
  (`/proc/stat`, `coretemp`), GPU (`gpu_busy_percent`, `amdgpu`, `pp_dpm_sclk`,
  `mem_info_vram_*`) y red (`/proc/net/dev`, ruta predeterminada, ping al gateway).
  Nuevas vistas `PerfView.qml` (Procesador/Gráficos) y `NetView.qml` (Red) con uso,
  temperatura, frecuencia, potencia, VRAM, historial, picos, sesión, latencia, interfaz
  e IP. `showTemps` se guarda en `settings.conf`.
- **VPN real**: `VpnState.qml` lista los perfiles `vpn`/`wireguard` de NetworkManager y
  los conecta/desconecta con `nmcli`; `VpnView.qml` muestra la lista o explica cómo
  crear un perfil. Se probó con un perfil WireGuard temporal y se borró después.
- **Teclado en pantalla**: `KeyboardState.qml` arranca y detiene `wvkbd` (instalado con
  apt) y se controla desde la cuadrícula, la barra o IPC. Mientras está visible cubre la
  barra; es una limitación de wvkbd, que no acepta márgenes.
- **Iconos CPU/GPU propios**: se añadieron `icons/cpu.svg` e `icons/gpu.svg` porque los
  iconos de Breeze se convertían en un cuadrado sólido al teñirlos. El teclado pasó a
  `input-keyboard-symbolic` por el mismo motivo.
- **Barra por defecto (primera versión)**: pasa a `music`, `wifi`, `volume`, `cpu`,
  `gpu`, `net`. Después se añadió Bluetooth; todos los controles nuevos se pueden
  arrastrar al centro de control y viceversa.
- **Iconos del diseño**: se añadieron `ShellIcons.qml` y los SVG `music`, `moon`,
  `shield`, `plane`, `sun`, `dim`, `net`, `keyboard`, `power`, `calendar`, `cloud`,
  `alarm` y `timer`, copiados del sprite de `Desktop.html`. Música usa una nota; luz
  nocturna, VPN, modo avión, CPU, atenuación extra, brillo, tráfico de red, teclado y
  energía usan la forma exacta del diseño. Las pestañas del reloj también. La hora de
  la barra sigue siendo solo texto, como en el diseño.
- **Batería Bluetooth**: el control de la barra y la ficha del centro de control
  muestran el porcentaje del dispositivo conectado si se activa la opción en el panel
  de Bluetooth; por defecto está desactivada. El icono se tiñe de rojo con ≤10 %,
  naranja con ≤20 % y blanco por encima. La barra incluye Bluetooth por defecto.
- **Vinculación Bluetooth**: el panel dejó de usar `BluetoothDevice.pair()` y ahora
  ejecuta `bluetoothctl` (que registra un agente de BlueZ), activa `pairable`, marca el
  dispositivo como de confianza y lo conecta. Se añadió un mensaje de error y un estado
  de «vinculando». Se probó con unos Galaxy Buds Pro: quedaron vinculados, de confianza
  y conectados, con batería visible; el primer intento del panel agotó el tiempo y el
  emparejamiento manual funcionó, así que el límite se subió a 30 s.
- **Ethernet + Wi-Fi**: la barra muestra ambos iconos si las dos conexiones están
  activas. La vista de Wi-Fi añadió una sección «Ethernet» con la interfaz y un botón
  para desconectar y volver a conectar el cable. Verificado desconectando y
  reconectando `enp4s0` sin perder el Wi-Fi.
- **Tráfico de red**: el widget de la barra ahora usa número, unidad y flechas de
  subida/bajada como el diseño, en lugar de un icono; la ficha y el panel de Red usan
  el icono de Wi-Fi del diseño.
- **Tema de iconos**: los reinicios manuales de Quickshell deben conservar
  `QS_ICON_THEME=breeze-dark` (ya está en `exec-once` de Hyprland). Sin esa variable,
  Qt puede usar `hicolor` y los iconos de Breeze aparecen como glifos de respaldo.
  `QT_QPA_PLATFORMTHEME` se reserva para las apps (`kde`).
- **Abrir y cerrar widgets con el mismo clic**: los controles de la barra usan
  `QuickPanelState`; si su vista ya está abierta, el clic cierra el panel; si no, la
  abre en modo rápido, sin notificaciones. La campana abre el panel completo con
  notificaciones y centro de control. Escape cierra ambos.
- **Música sin carátula**: Firefox publica un MPRIS nativo sin `artUrl` y otro de
  `plasma-browser-integration` con carátula y artista. `MusicState.player` ahora
  prefiere al que tiene metadatos, `artist` normaliza `trackArtist`/`trackArtists` y la
  portada de la barra se centra verticalmente. Verificado con un vídeo de YouTube:
  aparecen la miniatura y «Daarick».
- **Tráfico de red compacto**: la píldora ya no tiene un ancho fijo de 46 px; el número,
  la unidad y las flechas definen el ancho, y `Pill.horizontalPadding` permite reducir
  el relleno solo en este widget.
- **Búsqueda Bluetooth**: se quitó el interruptor de búsqueda del apartado «Vincular
  dispositivo». La búsqueda arranca al pulsar «+» y se detiene con «Cancelar» o al salir.
- **Iconos de energía**: bloqueo y reinicio usan los SVG del diseño; cierre de sesión usa
  un SVG propio con el mismo trazo; apagado ya usaba el del diseño.
- **Iconos de nivel**: nuevos `LevelIcon.qml` e `icons/volume*-1/2/3.svg` y
  `icons/mic*-1/2/3.svg`. Volumen y micrófono muestran tres arcos que se encienden al
  superar 33 % y 66 %; los apagados quedan al 18 % de opacidad. También se usan en la
  ficha del centro de control.
- **Estado de las pruebas**: tras apagar y encender el adaptador Bluetooth desde el
  panel, los Galaxy Buds Pro desaparecieron de BlueZ (el emparejamiento no estaba
  persistido en `/var/lib/bluetooth/.../<MAC>/info`). Hay que volver a ponerlos en modo
  vinculación para emparejarlos. `ydotool` se instaló solo para inyectar clics y se
  eliminó al terminar; `/dev/uinput` volvió a `crw------- root input`.
- **Iconos de apps más grandes**: las fichas del escritorio activo pasan de 20 a 26 px
  con iconos de 18 px y la píldora sube a 34 px de alto, como el ejemplo web.
- **Número del escritorio activo oculto**: el escritorio donde se está muestra solo sus
  iconos; los demás conservan el número. Así el escritorio actual se reconoce por el
  que no enseña número. Verificado con captura.
- **Brillo real del monitor**: se instaló `ddcutil` y se creó
  `/etc/sudoers.d/shell-ddcutil` (`username ALL=(root) NOPASSWD: /usr/bin/ddcutil`).
  `DisplayState.qml` lee el brillo al arrancar, escribe los cambios con
  `sudo -n ddcutil setvcp 10` (agrupados para no lanzar un proceso por cada paso) y
  usa el shader solo para la atenuación extra y la luz nocturna. Probado de 100 % a
  51 % y viceversa, con lectura correcta al reiniciar. Si el monitor no responde,
  vuelve al shader como antes.
- **Reordenar widgets de la barra**: arrastrar un control dentro de la barra muestra una
  marca vertical de inserción y, al soltar, `BarState.move()` lo coloca en esa posición.
  El arrastre al panel sigue quitándolo de la barra. Verificado con clics inyectados
  (volumen al principio y al final). El orden no se guarda en disco, así que al
  reiniciar vuelve el orden por defecto.
- **Arrastre sin `hyprctl`**: `ControlDrag` recibe la posición global del `MouseArea`
  que está arrastrando. El proceso `hyprctl cursorpos` anterior arrancaba tarde y dejaba
  `overBar` en falso; así el reordenado funciona en cuanto se mueve el puntero.
- **Pruebas**: `ydotool` se instaló de nuevo solo para inyectar clics y se eliminó al
  terminar; `/dev/uinput` volvió a `crw------- root input`.
- **Brillo desde 0**: el mínimo baja de 5 % a 0 %, tanto en el deslizador como en
  `DisplayState`. Probado con `brightnessDown` hasta 0 y `getvcp 10` devolviendo 0;
  después se restauró a 100 %.
- **Pasos de 5 %**: la rueda, los atajos y los deslizadores de brillo, atenuación
  extra y luz nocturna avanzan de 5 en 5. Volumen y micrófono siguen en pasos de 2 %.
  Verificado con `brightnessDown` (100 → 95) y `getvcp 10`.
- **OSD de brillo, atenuación y luz nocturna**: `OsdState` y `Osd.qml` ahora muestran
  el icono, la barra y el porcentaje de los cinco controles. Se dispara desde los
  setters de `DisplayState`, así funciona con la rueda, el deslizador y los atajos.
  El porcentaje se muestra siempre en el OSD, aunque ese panel tenga el porcentaje
  desactivado en la barra.
- **Atajos de brillo**: `SUPER` no cambia; se añadieron las teclas
  `XF86MonBrightnessUp/Down` y los métodos IPC `brightnessUp`, `brightnessDown`,
  `nightToggle` y `extraDimToggle`. No abren el panel, solo muestran el OSD.
- **Rueda en el centro de control**: las fichas de `CcItem` aceptan la rueda. Volumen y
  micrófono se ajustan de 2 en 2; brillo, atenuación y luz nocturna de 5 en 5. La barra
  usa los mismos pasos y el micrófono ya se puede ajustar con la rueda.
- **Reordenar el centro de control**: `BarState.centerOrder` guarda el orden de la
  cuadrícula y `moveCenter()` lo cambia. Al arrastrar una ficha, las demás se recolocan
  por filas y columnas y la celda de destino se resalta. Verificado arrastrando Brillo
  a la primera posición; también se comprobó que sigue funcionando el paso centro →
  barra y barra → centro (VPN).
- **Wi-Fi bajo demanda**: `wifiDevice.scannerEnabled` se activa al abrir la vista de
  Wi-Fi, aunque ya haya una red conectada, y se apaga al cerrarla o al entrar en los
  ajustes de una red. `WifiState.requestScan()` pide además una pasada nueva con
  `nmcli`; el icono de recargar de la cabecera hace lo mismo. Se mantiene el icono
  giratorio y el texto «Buscando redes…» / «Buscando otras redes…».
- **Ajustes por red Wi-Fi**: cada red tiene un engranaje. La vista muestra el QR para
  compartirla, la reconexión automática (`connection.autoconnect`), las bandas y
  «Olvidar red» (con confirmación en el mismo botón). El QR y el perfil se leen de
  NetworkManager con `scripts/wifi-profile.py`; si la red no tiene perfil guardado,
  solo se muestran los datos disponibles.
- **Panel de tamaño fijo**: el centro de control ocupa siempre dos columnas y las
  filas visibles configuradas (5 por defecto, 2–8). Las fichas sobrantes y las vistas
  avanzadas se desplazan dentro del mismo alto; la barra lateral ya no cambia de
  tamaño al abrir una opción. Ajuste nuevo `centerRows` en `settings.conf`.
- **Reordenar el centro**: al arrastrar una ficha se reordena en vivo, de izquierda a
  derecha, y la ficha arrastrada se convierte en un hueco con borde morado. Las demás
  se desplazan como quedarán al soltar. Si el arrastre termina fuera del panel se
  recupera el orden original. Verificado con una simulación de arrastre (Ajustes al
  primer hueco) y sin bucles de binding.
- **Rueda en listas y cuadrícula**: las fichas sin valor que ajustar y las filas de
  Wi-Fi pasan la rueda al desplazamiento del panel; en las vistas avanzadas una capa
  transparente recoge la rueda sin bloquear los clics. Probado desplazando la lista
  Wi-Fi y la cuadrícula con 4 filas visibles.
- **Iconos más grandes y arcos abiertos**: las fichas del centro usan cajas de 32 px
  con iconos de 20 px; en la barra el tamaño es configurable (22 px por defecto) y
  solo cambia el dibujo, no la píldora. Los arcos de volumen y micrófono pasan de
  180° a unos 110°, con trazo de 2 px, para que no parezcan cerrados.
- **Sin instrucciones**: se quitaron los textos explicativos de Wi-Fi, Bluetooth,
  punto de acceso, audio, brillo, atenuación, VPN, alarmas, música y ajustes. Se
  conservan solo etiquetas, estados y los avisos contextuales de arrastre.
- **Pruebas**: `ydotool` se instaló de nuevo solo para inyectar clics y se eliminó al
  terminar; `/dev/uinput` volvió a `crw------- root input`. El brillo se restauró a
  100 % (`getvcp 10` = 100).
- **Apagado del Bluetooth**: `SettingsState` añade `btAutoOff` y `btMinutes`;
  `AutoOffState` apaga el adaptador si no hay ningún dispositivo conectado durante el
  tiempo indicado (salvo mientras se está buscando). La vista avanzada de Bluetooth
  tiene el interruptor y los botones 5/10/15/30 min. Por defecto los tres apagados
  automáticos (hotspot, Wi-Fi y Bluetooth) quedan en 15 minutos.
- **Pruebas**: `ydotool` se instaló de nuevo solo para inyectar clics y se eliminó al
  terminar; `/dev/uinput` volvió a `crw------- root input`.
- **Reordenar el centro en ambos sentidos**: `moveCenter()` ahora traduce el destino
  contando solo las fichas visibles y reconstruye sus posiciones dentro de
  `centerOrder`, sin que los controles que están en la barra ocupen huecos. El destino
  se calcula con la posición real del puntero dentro de la cuadrícula, así que subir
  y bajar funciona igual que moverse a izquierda o derecha. Probado con una
  simulación: Ajustes de la última fila a la primera y después a una fila intermedia,
  con el hueco morado siguiendo al puntero.
- **Wi-Fi más limpio**: las redes vuelven a mostrar sus chips 2.4G/5G/6G en la lista;
  el engranaje conserva la misma configuración de bandas. Se quitó la marca «✓» de la
  red conectada y el texto de calidad de señal: el estado se ve por el color y por el
  icono de señal.
- **Temperaturas apagadas por defecto**: `showTemps` arranca en `0`; se puede activar
  desde las opciones de rendimiento. `settings.conf` se actualizó a `showTemps=0`.
- **Atenuación y luz nocturna persistentes**: `DisplayState` guarda sus valores en
  `~/.config/shell/display.conf`. Al activarlas por primera vez usan 50 % y, si se
  ajustan, se recuperan al reiniciar el shell. Probado activando ambas al 50 %,
  reiniciando Quickshell y comprobando que seguían activas y con el mismo nivel.
- **Atajo del micrófono**: la vista de micrófono tiene un botón de atajo con icono de
  teclado. Al pulsarlo captura una combinación (CTRL/ALT/SHIFT/SUPER + tecla) y la
  registra en Hyprland para ejecutar `notifications micToggle`. Probado con
  CTRL+ALT+M: `wpctl` pasó a `[MUTED]` y volvió a activo en la segunda pulsación. El
  atajo se guarda en `settings.conf` y se vuelve a registrar al arrancar el shell.
- **Tamaño de iconos configurable**: las fichas del centro usan 20 px por defecto
  dentro de una caja de 32 px. En Ajustes hay un control de 12 a 32 px que nunca deja
  el icono mayor que la caja. La barra tiene su propio control de 12 a 26 px (22 px
  por defecto) que ahora cambia el ancho del botón junto con el dibujo. Probado a 26
  px y devuelto a 20 px; el centro se dejó en 20 px.
- **Reloj como el ejemplo web**: hora grande a 22 px, día de la semana en versalitas
  alineado a la derecha, y bloque lateral con día, mes y año separados por una línea.
  Verificado con captura; «MIÉRCOLES» ya se muestra completo.
- **Logotipo del lanzador**: el botón que antes mostraba «A» usa ahora el logotipo de
  la distribución. En Debian se ve el emblema de `desktop-base`; si la distro no tiene
  un icono reconocible, `Distro.qml` cae en `icons/grid.svg`, una cuadrícula de cuatro
  cuadros. Verificado en Debian 13 con el emblema nítido a 22 px.
- **Ocultación automática de la barra**: ajuste `autoHideBar` en **Ajustes**,
  desactivado por defecto. Con la barra oculta, una franja de 4 px en el borde
  inferior la revela al pasar el puntero; se vuelve a ocultar tras un segundo si el
  puntero no está sobre ella. Los paneles, menús y arrastres la mantienen visible.
  Probado ocultando y revelando con el puntero, abriendo el panel desde el teclado
  (IPC) con la barra oculta y comprobando que reaparece alineada.
- **Pruebas de la barra automática**: con `autoHideBar=1` se comprobó que la barra
  desaparece al alejar el puntero, reaparece al tocar la franja inferior, permanece
  visible mientras el puntero sigue en esa franja (más de 3 s) y se oculta al salir.
  Al abrir el panel de notificaciones desde IPC con la barra oculta, la barra
  reaparece y el panel queda alineado.
- **Proporción de los botones de la barra**: los controles ya no usan una caja fija de
  28 px. Ahora miden el icono más 6 px de relleno, con la misma altura de 34 px, como
  el ejemplo web. A 20 px de icono el botón mide 26 px; a 26 px mide 32 px. Al ser más
  estrechos quedan más juntos y el ancho escala con `barIconSize`. La música conserva
  su ancho por el texto y se redujo de 152 a 130 px para mantener la proporción del
  mockup.
- **Trazo unificado**: todos los iconos de los widgets usan SVG propios con
  `stroke-width` 1.8, el grosor del ejemplo. Se añadieron Wi-Fi (tres niveles),
  Wi-Fi apagado, cable, Bluetooth, campana, campana silenciada, punto de acceso,
  ajustes, batería y los controles de música; GPU pasó de 1.5 a 1.8. También se aplicó
  al centro de control. Verificado con capturas de la barra a 20 y 26 px y del centro
  abierto.
- **Volumen y micrófono como el OSD**: se abandonaron los SVG propios de tres arcos y
  `LevelIcon.qml` pasó a usar las variantes de Breeze (`audio-volume-low/medium/high/
  muted` y `microphone-sensitivity-*`). Así el OSD, la barra y el centro comparten
  exactamente el mismo dibujo y el nivel se sigue viendo. Probado con 20 %, 62 %, 95 %
  y silenciado en la barra y el OSD. Es la única excepción al trazo 1.8.
- **Reloj más funcional**: el calendario permite elegir cualquier día, también de los
  meses vecinos, con un botón «Hoy» para volver. Las alarmas se guardan en
  `~/.config/shell/alarms.conf`, se comprueban cada segundo, suenan con
  `alarm-clock-elapsed.oga` y avisan; se probó una alarma a la hora actual y apareció
  en el panel con el sonido. El temporizador acepta minutos a medida en el campo
  «Otro» y suena con `complete.oga` al terminar.
- **Campana sin contador**: se quitó el número de notificaciones. Ahora se muestra un
  punto en la esquina del icono cuando hay avisos, igual que en las fichas de app; con
  «No molestar» el punto es rojo. Verificado con `notify-send` y con «Limpiar todo».
- **Anillo de progreso**: `ProgressRing.qml` bordea las fichas de app y los
  escritorios con un trazo que avanza en sentido horario. Las apps toman el progreso
  de `ProgressState`, que lee `~/.local/state/shell/progress`; `scripts/shell-progress`
  permite escribir tareas (`set firefox 34`, `set ws:2 60`, `clear`, `clear-all`).
  Verificado con Firefox al 50 %, kitty al 62 % y el escritorio 2 al 30 %, y con el
  archivo borrado para comprobar que los anillos desaparecen. El anillo de una app
  usa su color; el del escritorio usa el acento.
- **Apariencia**: se añadieron modo **oscuro/claro** y **acento configurable** en
  Ajustes. El oscuro usa barra gris muy oscura; por defecto el acento es gris
  (`#b8bec7`). El tema claro reutiliza ese mismo acento y lo oscurece solo para
  mantener el contraste. Se probaron ambos modos, varios acentos y la persistencia
  tras reiniciar Quickshell. También se expuso `appearance` por IPC
  (`qs ipc -c shell call appearance toggle|mode|accent`) para cambiarlo desde un
  atajo o un script. Quedan pendientes la opacidad y el desenfoque real.
- **Tema en las apps**: se añadió `scripts/shell-system-theme` y el interruptor
  **Tema en las apps**. El modo y el acento efectivo se aplican a GTK
  (`gsettings`, `settings.ini`, `gtk.css` de GTK 3/4) y a KDE (`kdeglobals`,
  `plasma-apply-colorscheme`). Se verificó con Firefox en claro y en oscuro y con
  Dolphin en ambos modos tras reiniciarlo. Las apps de KDE abiertas no cambian en
  caliente fuera de Plasma; las de GTK sí suelen hacerlo.
- **Distribución del teclado**: la ficha **Teclado** ahora abre una vista con 12
  distribuciones y el interruptor del teclado en pantalla. `SettingsState` aplica el
  cambio con `hyprctl keyword input:kb_layout`, lo guarda en `settings.conf` y lo
  reaplica al arrancar. Probado `es -> us -> es` en los teclados reales.
- **Portapapeles**: se añadió historial de textos con `wl-paste`/`wl-copy` incluidos
  en `scripts/bin/`, un vigilante único con `flock`, el JSON local con permisos 600 y
  la vista **Portapapeles**. Se probó copiando desde otra app GTK y desde la
  terminal, recargando Quickshell, copiando una entrada, borrando una y vaciando todo.
  Solo guarda texto, no imágenes.
- **Arranque**: `exec-once` pasó de `QT_QPA_PLATFORMTHEME=gtk3 qs -c shell` a
  `QS_ICON_THEME=breeze-dark qs -c shell`; la sesión fija
  `QT_QPA_PLATFORMTHEME=kde` para que las apps Qt/KDE no hereden el tema GTK.
- **Estado final**: una sola instancia de `qs`, un `stats.py` y un vigilante del
  portapapeles; sin errores QML; brillo en 100 %; preferencias actuales del usuario
  `barIconSize=20`, `centerIconSize=20`, `autoHideBar=1`, `themeMode=dark`,
  `accentColor=#b8bec7`, `systemTheme=1` y `keyboardLayout=es`; volumen al 18 % sin
  silencio; alarmas de ejemplo en `~/.config/shell/alarms.conf` desactivadas; historial
  del portapapeles vacío; sin tareas de progreso de prueba en
  `~/.local/state/shell/progress`; `/dev/uinput` sigue en `crw------- root input` y
  solo quedan capturas de prueba en `/tmp`.

### 2026-11-04 · Abstracción de compositor (fase 1)

- Nuevo **`CompositorState.qml`**: contrato común con `id`, `name`, `available`,
  `readOnly`, `capabilities`, `windows`, `workspaces`, `focusedWindow`,
  `focusedWorkspace` y contadores. Detecta el compositor por
  `XDG_CURRENT_DESKTOP` primero y luego por `UMBRIEL_SOCKET` /
  `HYPRLAND_INSTANCE_SIGNATURE`, para no confundir una sesión anidada con las
  variables heredadas del padre. `SHELL_COMPOSITOR=hyprland|umbriel|...` fuerza un
  backend al probar. El backend se crea en caliente con `Qt.createComponent`; añadir un
  compositor será añadir un archivo y una línea en `backendFile()`.
- Nuevo **`HyprlandBackend.qml`** en **solo lectura**: normaliza las ventanas de
  `Hyprland.toplevels` (título, app, escritorio, monitor, foco, flotante, minimizada,
  maximizada, pantalla completa, pin, geometría, PID) y los escritorios de
  `Hyprland.workspaces` (layout real `tiledLayout`, número de ventanas, foco).
  Declara capacidades honestas: `superHold`, `perWorkspaceLayout`, `windowGeometry`,
  `blur`, `moveToWorkspace`, `floatingToggle`, `pin`, `fullscreen`, `focus` y `close`
  disponibles; `nativeTitlebar`, `nativeMinimize` y `snapZones` todavía no.
- Nuevo **diagnóstico en Ajustes → Compositor** y por IPC
  (`qs ipc -c shell call notifications compositor`). Muestra compositor detectado,
  conexión, enfoque actual, escritorios con su layout, ventanas con su estado y
  geometría, y una lista de capacidades con ✓/—. Se refresca cada segundo solo
  mientras la vista está abierta.
- Las firmas de acción (`focusWindow`, `closeWindow`, `toggleFloating`,
  `toggleFullscreen`, `togglePinned`, `minimizeWindow`, `restoreWindow`,
  `moveToWorkspace`, `setWorkspaceLayout`) ya existen en el contrato, pero en esta
  fase devuelven `false` sin tocar el sistema. Se implementaron en la fase 2
  (sección siguiente).
- Verificado en la sesión Hyprland real: detecta `Hyprland`, `available=true`,
  3 ventanas y 2 escritorios, con el título de Firefox enfocado, los layouts
  `dwindle`, y las capacidades correctas. Sin errores QML tras recargar.

### 2026-11-04 · Acciones del compositor (fase 2)

- **`HyprlandBackend.qml` deja de ser de solo lectura** y ejecuta acciones reales:
  `focusWindow`, `closeWindow`, `toggleFloating`, `toggleMaximized`,
  `toggleFullscreen`, `togglePinned`, `minimizeWindow`, `restoreWindow`,
  `moveToWorkspace`, `focusWorkspace` y `setWorkspaceLayout`. Cada acción guarda
  `lastAction` y `lastActionOk` para el diagnóstico.
- **Cerrar**: `closewindow address:` de Hyprland 0.55 no cerraba la ventana aunque
  devolviera `ok`; se cambió a `killwindow address:`, que sí la cierra. El menú
  contextual de la barra también pasa por el contrato y ya cierra bien.
- **Pantalla completa y maximizar**: el dispatcher `fullscreen` no acepta una ventana
  objetivo, así que el backend enfoca primero y luego usa `fullscreen 0` (pantalla
  completa real) o `fullscreen 1` (maximizado). Comprobado que alternan 0 → 2 → 0 y
  0 → 1 → 0.
- **Minimizar sin soporte nativo**: se mueve la ventana a `special:minimized` y se
  recuerda su escritorio de origen para restaurarla. `focusWindow` sobre una ventana
  minimizada la restaura y la enfoca. Si Quickshell se recarga, el mapa de orígenes se
  pierde y la restauración cae al escritorio enfocado.
- **Layout por escritorio**: `Hyprland.dispatch()` antepone `dispatch `, así que no
  sirve para `keyword`; se usa `Quickshell.execDetached(["hyprctl", "keyword",
  "workspace", "N,layout:master"])`. Verificado `dwindle ↔ master` en el escritorio 2.
  El cambio es de sesión: no se escribe todavía en la configuración de Hyprland.
- **Diagnóstico con acciones**: cada escritorio muestra chips `Dwindle`/`Master`, y
  cada ventana chips `Enfocar`, `Flotar`/`Mosaico`, `Fijar`/`Soltar`,
  `Minimizar`/`Restaurar`, `Maximizar`/`Restaurar`, `Pantalla`/`Salir` y `Cerrar`. El
  resumen muestra la última acción y su resultado, y la insignia pasa a
  `CONTROL TOTAL`.
- **Nuevo `CompositorChip.qml`**: chip reutilizable con acento si la acción está
  activa y rojo para las destructivas.
- **Menú contextual real**: maximizar/restaurar, minimizar/restaurar, flotante,
  mover y cerrar usan `CompositorState`; se añadió la fila de minimizar. Los clics de
  ventana y de escritorio de `WorkspacePill` también usan el contrato.
- **IPC**: `qs ipc -c shell call notifications compositorAction <acción> <objetivo>
  [valor]`, por ejemplo `float 0x...`, `minimize 0x...`, `move 0x... 2`,
  `layout 2 master` o `workspace 2`.
- **Verificado con una ventana `kitty` desechable**: flotar, fijar/soltar,
  maximizar/restaurar, pantalla completa/salir, minimizar a `-98 special:minimized`,
  restaurar al escritorio 1, mover a 2 y volver, enfocar una minimizada y cerrar. Sin
  errores QML y con una sola instancia de `qs`.

### 2026-11-04 · Fichas por ventana y minimizadas visibles

- **La píldora ya no agrupa por aplicación.** `WorkspacePill.qml` crea una ficha por
  ventana usando `CompositorState.windowsForWorkspace()`. Dos `kitty` en el mismo
  escritorio muestran dos iconos; cada ficha abre el menú contextual de su ventana y
  ejecuta enfocar, minimizar, maximizar, flotar, mover o cerrar sobre ella. El menú ya
  no ofrece «Cerrar las N ventanas»: cada ficha controla solo su ventana.
- **Las minimizadas conservan su icono.** `HyprlandBackend.qml` añade
  `originWorkspaceId` y `originWorkspaceName` a cada ventana minimizada.
  `CompositorState.windowsForWorkspace()` incluye las ventanas en
  `special:minimized` cuando su escritorio de origen coincide. La ficha se queda
  atenuada al 40 %, y al pulsarla `focusWindow` restaura la ventana y la enfoca.
- **Relectura inmediata.** Minimizar, restaurar y mover una minimizada incrementan
  `revision` después de tocar el mapa de orígenes, para que la barra se actualice sin
  esperar al siguiente evento de Hyprland.
- **Verificado con dos `kitty` en el escritorio 1**: aparecen las dos fichas; al
  minimizar una, su icono permanece atenuado junto a la otra; al restaurarla vuelve a
  opacidad completa. Sin errores QML y con una sola instancia de `qs`.
- **Límite**: el mapa de orígenes vive en memoria. Si Quickshell se recarga mientras
  hay una ventana minimizada, su ficha desaparece hasta restaurarla desde **Ajustes →
  Compositor**; entonces vuelve al escritorio enfocado.

### 2026-11-04 · Fase 3: Super, modos y barra de título

- **Super mantenido.** Hyprland registra `bind` para pulsar `Super_L`/`Super_R` y
  `bindr` para soltar. `SuperState` espera 220 ms: un toque corto abre el lanzador y
  mantenerlo activa el modo ventanas. `Super+Tab` fija el modo sin mantener la tecla y
  `Super+Shift+W` alterna el escritorio activo entre Flotante y Mosaico. Verificado por
  IPC: a los 80 ms el overlay sigue oculto, a los 380 ms está visible, y al soltar se
  cierra sin abrir el lanzador; el toque corto sí abre el lanzador.
- **Controles de ventana por ventana.** `WindowChrome.qml` crea una `PanelWindow` por
  ventana con icono real, título, app y escritorio, y botones de fijar, flotante,
  mover a escritorio, maximizar, minimizar y cerrar. La máscara de entrada solo cubre
  la barra de 34 px y el selector de escritorios; el resto de la ventana sigue
  interactivo. El arrastre usa `movewindowpixel exact` a través de
  `CompositorState.moveWindowTo()`; verificado moviendo una `kitty` a 400,300.
- **Modo en el escritorio.** Al mantener Super, la píldora del escritorio
  activo atenúa sus fichas y muestra encima el icono del modo actual. Al
  pulsarlo cambia entre Flotante y Mosaico; la antigua barra de modo ya no se
  abre. Las fichas minimizadas se restauran al pulsarlas.
- **Modos por escritorio.** `WorkspaceModeState.qml` guarda el modo por defecto y las
  excepciones en `settings.conf` (`workspaceModeDefault`, `workspaceModes`,
  `workspaceModeChosen`). Flotante suelta las ventanas existentes y las nuevas;
  mosaico las vuelve a mosaicar. Verificado en el escritorio 2 (`mosaic`) y de vuelta
  a `floating`; una `kitty` nueva se abrió flotante en un escritorio flotante y otra
  se abrió en mosaico en un escritorio mosaico.
- **Primera elección.** `WelcomeMode.qml` pregunta una sola vez entre «Flotante /
  Como Windows» (recomendado) y «Mosaico», y deja elegir la barra de título. Probado
  visualmente con captura: el modal centra las dos tarjetas y el botón de elección.
- **Barra de título.** `Automática` la muestra al mantener Super, `Siempre` la deja
  fija en ventanas flotantes y `Nunca` deja solo los controles de Super. Es una barra
  de Shell, no un plugin del compositor: cubre los primeros 32 px de la ventana, igual
  que la cabecera flotante del mockup. Verificado en las tres opciones; no se probó
  todavía con ratón físico.
- **Backend de Umbriel.** `UmbrielBackend.qml` usa el IPC documentado
  (`umbriel windows --json`, `umbriel workspaces --json`, `umbriel msg ...`) y declara
  capacidades equivalentes. Se validó que compila y se detecta con
  `SHELL_COMPOSITOR=umbriel`, pero no hay una sesión Umbriel instalada para probar
  acciones reales.
- **Corrección de datos de Hyprland.** `lastIpcObject` no actualizaba `floating`,
  `pinned` ni la geometría. El backend ahora completa cada ventana con una lectura
  periódica de `hyprctl -j clients`; sin esto, cambiar a flotante volvía a mosaicar las
  ventanas por error.
- **Límites**: el arrastre y los clics de los controles no se probaron con ratón
  físico; la barra de título ocupa contenido en vez de reservar espacio (no hay
  `hyprbars`); el mapa de minimizadas sigue viviendo en memoria; el modo por escritorio
  no se escribe en `hyprland.conf`, solo se aplica en caliente.
- **Solo el escritorio activo dibuja controles.** `WindowChrome.qml` compara el
  escritorio de la ventana con el enfocado (o deja pasar las fijadas). Sin esto, la
  barra de título de una ventana en otro escritorio aparecía encima del activo.
- **Arranque sin carreras.** `CompositorState.windowDataReady` espera a la primera
  lectura de `hyprctl -j clients` antes de aplicar los modos; así una ventana que ya
  era flotante no se vuelve a mosaicar al iniciar el shell. Verificado reiniciando
  `qs` con ventanas flotantes: siguen flotantes.

### 2026-11-04 · Migración a Umbriel y barra de título nativa

- **Motivo.** La barra de título de Shell era una superficie encima de la ventana:
  tapaba los primeros píxeles del contenido. El requisito es que la decoración
  reserve su propio espacio, como en el mockup. Se cambia el foco a Umbriel y se
  conserva Hyprland como respaldo en SDDM.
- **Instalación real.** Repositorio oficial de Noctalia para Debian:
  `nickh-archive-keyring`, `noctalia-trixie.sources` y
  `apt install -t trixie-backports umbriel`. Instala `umbriel 0.1.0~1505` y sube
  15 librerías (libdrm, libinput, libwayland, libdisplay-info) a versiones
  compatibles. Se guardó el estado previo de paquetes en
  `/tmp/opencode/paquetes-antes.txt`.
- **Sesión.** `/usr/share/wayland-sessions/umbriel.desktop` (`Exec=start-umbriel`)
  aparece en SDDM. `start-umbriel` usa el servicio de usuario `umbriel.service`;
  Umbriel lanza `~/.local/bin/shell-start`, que exporta el tema Qt y el tema de
  iconos y ejecuta `qs -c shell -d`. También se instaló
  `xdg-desktop-portal-umbriel` y su entrada de portal.
- **Barra nativa verificada.** `[appearance.title_bar]` con `mode = "forced"` y
  34 px dibuja título a la izquierda y minimizar/maximizar/cerrar a la derecha.
  La captura del Umbriel anidado confirma que el contenido empieza **debajo** de
  la barra. Los colores siguen la paleta de Shell.
- **Backend de Umbriel corregido.** `umbriel windows --json` y
  `umbriel workspaces --json` devuelven un array directo, no `{ "ok": [...] }`.
  También se aceptan las dos formas. Los identificadores de escritorio son
  `WL-1:1`; el backend usa el campo `index` y, como respaldo, el sufijo `:N`.
- **Acciones verificadas por IPC** en el Umbriel anidado: enfocar, cerrar, flotar,
  maximizar, pantalla completa, fijar, mover a escritorio (silencioso), cambiar
  layout del escritorio, mover a scratchpad y restaurar.
- **Minimizar en mosaico.** `window-minimize` solo acepta ventanas flotantes. Para
  las mosaicadas, Shell las enfoca y las mueve al scratchpad por defecto; al
  restaurar, las enfoca y las devuelve a su escritorio de origen. Se guarda el
  escritorio de origen en memoria hasta que la ventana vuelve.
- **Modos por escritorio nativos.** `CompositorState.setWorkspaceMode()` traduce
  `floating` → `stacking` y `mosaic` → `dwindle`. Umbriel solo aplica
  `workspace-set-layout` al escritorio activo, así que `WorkspaceModeState` aplica
  el modo al entrar en cada escritorio (`watchFocused()`). Verificado:
  `windows mode 1 floating` deja `stacking` y `windows mode 1 mosaic` deja
  `dwindle`, con las ventanas pasando de flotantes a mosaicadas.
- **Sin doble decoración.** Con `nativeTitlebar: true`, `WindowChrome.qml` no crea
  ninguna superficie y el centro de control y el modal de bienvenida ocultan los
  ajustes de barra propia. La barra de Shell y la nativa conviven.
- **Ventanas nuevas.** `scanNewWindows()` se desactiva cuando el compositor tiene
  layouts nativos (`autoFloatNewWindows: false`); el layout del escritorio decide.
- **Teclado.** Umbriel no tiene una acción para fijar un layout concreto, solo
  `keyboard-layout-next`. `~/.local/bin/shell-keyboard-layout` edita
  `[input.keyboard] layout` en la config y ejecuta `umbriel msg config-reload`;
  `SettingsState.applyKeyboardLayout()` pasa por `CompositorState`, que usa
  `hyprctl` en Hyprland y el ayudante en Umbriel.
- **Atajos.** Umbriel detecta un bind de modificador suelto al soltar, así que no
  existe el gesto de «mantener Super» de Hyprland. Se usa `Mod` (toque) para el
  lanzador, `Mod+Espacio` como alternativa, `Mod+Tab` para fijar los controles de
  ventana y `Mod+Shift+W` para alternar Flotante/Mosaico. El resto de atajos
  (ventanas, escritorios, volumen, brillo, micrófono) están en la tabla
  `[keybinds]` de la config de Umbriel.
- **Límites actuales.** Falta probar la sesión real desde SDDM, el ratón físico y
  el arranque automático fuera del entorno anidado. El botón de minimizar de la
  barra nativa no aparece en ventanas mosaicadas; Shell ofrece esa ruta desde la
  ficha de la app. El mapa de minimizadas sigue en memoria. La barra nativa
  estándar no muestra icono de app, subtítulo ni los seis botones del mockup:
  eso requiere el edit del decorado.

### 2026-11-04 · Edit del decorado nativo (icono, subtítulo y seis botones)

- **Qué se modificó.** Sobre Umbriel `b6c4b7d` se parcheó el decorado del
  servidor (`src/scene/ssd_frame.*`, `ssd_frame_geometry.*`,
  `title_bar_icon.cpp`, `src/input/cursor.cpp`, `src/view/view_chrome.cpp`):
  - `TitleBarButton` pasa de 3 a 6 valores: `Minimize`, `Maximize`, `Close`,
    `Pin`, `Float`, `Move`. La config acepta
    `buttons = ["float", "pin", "move", "minimize", "maximize", "close"]`.
  - Dibujo de los glifos nuevos con Cairo, en el mismo estilo de trazo que los
    originales.
  - Acciones: `float` alterna flotante; `pin` fija; `move` abre la vista
    general de Umbriel (`overview-open`).
  - **Minimizar en mosaico.** El botón ya no se oculta en ventanas mosaicadas:
    si Umbriel no puede minimizar de forma nativa, la ventana se mueve al
    scratchpad por defecto. Se restaura con `window-focus` +
    `window-restore-from-scratchpad`, igual que desde Shell.
  - **Subtítulo** a la derecha del título, en la misma línea, con
    `app_id · escritorio`, como el `.win-sub` del mockup.
  - **Icono real de la app**: `.desktop` → `Icon=` → tema de iconos
    (`breeze-dark`, `breeze`, `hicolor`, `Adwaita`, …) → `gdk-pixbuf` →
    buffer de Cairo. Soporta SVG y PNG y las dos disposiciones de tema
    (`<tema>/48x48/apps` y `<tema>/apps/48`).
  - Altura de barra subida a 36 px (el mockup usa 36 px en la cabecera
    integrada) y glifos siempre visibles.
- **Dependencias de compilación** instaladas con `apt`: `cmake`, `meson`,
  `ninja-build`, `libwlroots-0.20-dev`, `libwayland-dev`, `libdrm-dev`,
  `libinput-dev`, `libxkbcommon-dev`, `libpixman-1-dev`, `libpixman-1-0`,
  `libcairo2-dev`, `libpango1.0-dev`, `libtomlplusplus-dev`, `libjemalloc-dev`,
  `libliftoff-dev`, `libdisplay-info-dev`, `liblcms2-dev`, `libsystemd-dev`,
  `libxcb*`, `libeis-dev`, `wayland-protocols`, `libseat-dev`, `libudev-dev`,
  `nlohmann-json3-dev`, `libgdk-pixbuf-2.0-dev`.
- **Compilar e instalar.**
  ```sh
  cd ~/umbriel-edit
  meson setup build --prefix=/usr --buildtype=release
  ninja -C build
  sudo cp build/umbriel /usr/bin/umbriel   # el original está en umbriel.stock-0.1.0
  ```
- **Verificado con ratón virtual** (`ydotool` + Umbriel anidado): clic en
  flotar, fijar, mover (abre la vista general) y minimizar una ventana
  mosaicada (se va al scratchpad y vuelve a su escritorio). El icono se probó
  con `kitty` y `KCalc`; el subtítulo cambia con la app y el escritorio.
- **Adaptaciones de Shell al backend.** Las píldoras de escritorio leían
  `Hyprland.workspaces` directamente; ahora usan `CompositorState.workspaces`, así
  los iconos de las ventanas aparecen también en Umbriel. El menú contextual de las
  fichas ya no depende de `HyprlandFocusGrab`: en Umbriel ocupa la pantalla con un
  fondo transparente que cierra al pulsar fuera, y la tarjeta se coloca en la
  posición calculada. Se añadió la capacidad `hyprlandFocusGrab` para elegir el
  camino. Verificado con clic derecho real: el menú abre y cierra al pulsar fuera.
- **Tema de la barra nativa.** `~/.local/bin/shell-umbriel-theme` reescribe
  `[colors]`, `[colors.border]` y `[colors.title_bar]` con los colores del modo
  claro/oscuro y el acento de Shell, y ejecuta `umbriel msg config-reload`.
  `SettingsState.requestShellTheme()` lo llama al arrancar y al cambiar de modo o
  acento (con 220 ms de retardo). Verificado en Umbriel anidado: el modo claro
  deja la barra clara con texto oscuro y el oscuro la devuelve a gris muy oscuro.
- **Límites del edit.**
  - `move` abre la vista general, no un menú de escritorios; mover a un
    escritorio concreto sigue en el menú contextual de la ficha de Shell.
  - No hay botón de volumen por ventana (el mockup lo tiene para apps web).
  - La lista de temas de iconos es fija; si un icono vive en otro tema, no se
    encuentra.
  - `apt upgrade` puede sobrescribir `/usr/bin/umbriel`. Tras actualizar el
    paquete hay que recompilar el edit o restaurar el binario original.
  - El edit está sobre `main` de Umbriel, no sobre la etiqueta exacta del
    paquete; al actualizar Umbriel habrá que rebasar el parche.

### 2026-11-04 · Menú contextual anclado a la barra

- **Síntoma.** En la sesión real de Umbriel, al hacer clic derecho en el icono
  de una app de la barra, el menú aparecía en la esquina superior izquierda,
  sobre la barra de título de la ventana, en vez de salir de la barra.
- **Causa.** En Umbriel el menú necesita un panel a pantalla completa para
  capturar el clic exterior (`HyprlandFocusGrab` no existe). El cálculo de
  `menuLeft`/`menuTop` usaba `implicitWidth`/`implicitHeight` del panel, que en
  ese modo son el tamaño de la pantalla (1920×1080). Al restar esas medidas, el
  anclaje se recortaba al margen superior izquierdo.
- **Arreglo.** `AppContextMenu.qml` calcula la posición con el tamaño real de la
  tarjeta (`cardWidth` 244, `cardHeight` según el contenido), la centra sobre el
  icono y la abre hacia arriba desde la barra, limitada a los márgenes de la
  pantalla. El panel sigue ocupando la pantalla solo para cerrar al pulsar
  fuera.
- **Verificado** en la sesión real de Umbriel con captura: el menú sale justo
  encima de la barra, centrado en el icono.

### 2026-11-04 · Iconos del mockup, tamaño real y puente X11

- **Iconos de la barra nativa.** `title_bar_icon.cpp` se reescribió para usar
  exactamente los trazos del sprite del mockup (`i-mode-float`, `i-pin`,
  `i-move`, `i-minus`, `i-max`, `i-close`) sobre un lienzo de 24×24 con trazo
  1,8. Los botones pasan a 26 px en la barra de 36 px, con 2 px de separación y
  el símbolo a 13 px (la mitad), como el CSS del diseño. Antes eran botones de
  18 px con 8 px de separación y símbolos de 18 px.
- **Ventana «Wayland to X Recording bridge».** Es
  `xwaylandvideobridge`, el puente que permite a apps X11 (Discord, Zoom)
  capturar pantalla en Wayland. Umbriel lo mostraba como una ventana normal.
  Se añadió una regla de ventana que lo guarda en el scratchpad:
  `[[window_rule]] match.app_id = "^xwaylandvideobridge$"` con
  `default_scratchpad = "default"`. Sigue funcionando en segundo plano y se
  puede sacar con el atajo del scratchpad. La ventana que ya estaba abierta se
  movió al scratchpad por IPC.
- **Plan.** Se creó `PLAN.md` con el estado real, las fases A–E y las
  decisiones pendientes (estilo de botones, volumen por ventana, bloqueo
  automático, iconos de escritorio y mantenimiento del edit).
- **Parche.** `umbriel-edit.patch` se regeneró como diff completo desde
  `b6c4b7d` e incluye los dos commits del edit. El binario instalado es
  `3ec9f65cc368`. Los cambios de iconos y tamaños requieren reiniciar la
  sesión (el compositor no puede recargar su propio binario).

### 2026-11-04 · Estilo del mockup y bloqueo automático

- **Botones nativos.** `updateColors()` ya no pinta fondos de color permanentes:
  en reposo son transparentes y solo aparece un tinte al pasar el ratón (9 %
  blanco en oscuro y negro en claro; cerrar usa 16 % de su rojo). Los glifos
  descansan en `text_unfocused` y pasan a `text` al pasar; cerrar pasa a su
  rojo. Esto coincide con `.wc`, `.wc:hover` y `.wc.close:hover` del mockup.
- **Medidas.** Icono de app a 20 px, título `sans 11` y subtítulo un punto por
  debajo, como la cabecera integrada del diseño.
- **Bloqueo.** `swayidle` se instaló desde Debian; Umbriel expone
  `ext_idle_notifier_v1`. `~/.local/bin/shell-idle` detiene la instancia
  anterior, arranca `swayidle` con el tiempo pedido y ejecuta `hyprlock`
  (también antes de suspender). `SettingsState.lockMinutes` (0–120, por defecto
  5) se guarda en `settings.conf` y se aplica al arrancar y al cambiarlo.
- **Interfaz.** Nueva fila «Bloqueo automático» en Ajustes con chips Nunca, 1,
  5, 10, 15 y 30 minutos. También hay IPC
  `qs ipc -c shell call notifications lockTimeout 10`.
- **Verificado.** `lockTimeout 1` deja `swayidle timeout 60`; volver a 5 deja
  `timeout 300`. En Umbriel anidado, `hyprlock` dibuja la pantalla de bloqueo
  con la hora y la fecha en español y se desbloquea con la contraseña real
  (PAM autenticó y la sesión volvió sola).
- **Decisión.** No se implementa volumen por ventana; se usa el widget de
  música y el volumen global. Los iconos de escritorio quedan para más
  adelante.

### 2026-11-04 · Gesto de Super con estado real del compositor

- **Umbriel ya lo sabía.** El compositor usa el estado de Mod mientras está
  pulsado para arrastrar ventanas y cambiar el cursor. Ahora también lo publica
  por IPC con el evento `modifiers`, que trae `mod`, la máscara `modifiers` y
  `tap`.
- **`tap` sin falsos positivos.** Umbriel marca el gesto como limpio solo si
  Mod se pulsó sin otros modificadores y no se pulsó ninguna otra tecla ni el
  ratón después. Al soltar, Shell abre el lanzador únicamente si el gesto sigue
  siendo limpio. `Super+Return`, `Super+1` y compañía no abren el lanzador.
- **Shell se suscribe** a `umbriel subscribe modifiers` desde `UmbrielBackend`
  y traduce el evento a `SuperState.press()` / `release(tap)`. Al mantener
  Super, la píldora del escritorio activo muestra el cambio de modo; si la
  barra está en autoocultar, también se revela. `Mod+Tab` sigue fijando los
  controles como alternativa.
- **Sin doble lanzador.** El bind suelto `"Mod"` de Umbriel llama ahora a
  `windows superTap`. Si el backend ya recibió el evento `modifiers`, ese
  respaldo no hace nada; en una sesión antigua sin el evento, sigue abriendo el
  lanzador como antes. `Mod+Space` no cambia.
- **Robustez.** Si desaparece el teclado que mantenía Mod (por ejemplo, un
  teclado virtual que se desconecta), el compositor emite el estado nuevo para
  que el overlay no se quede pegado. También hay reintentos limitados si Shell
  arranca antes de que exista el socket del compositor.
- **Hoja de atajos.** `show_cheatsheet = false`; se abre a demanda con
  `Mod+F1`. Así el escritorio no arranca con una capa de teclas encima.
- **Verificado.** En Umbriel, mantener Super muestra el icono de modo sobre la
  píldora del escritorio activo, con las apps atenuadas, y al soltar
  desaparece. El binario instalado es `5cd031a8023c`.
- **Pendiente.** La prueba con el teclado físico y la sesión real requieren
  cerrar sesión para que el compositor nuevo (evento `modifiers`) esté activo.

### 2026-11-04 · Cierre al pulsar fuera, menús y modo en el escritorio

- **Cierre exterior.** Una capa transparente en la capa superior del shell,
  `shell-outside-close`, se mapea mientras hay un panel, el calendario, el menú
  de energía o el menú de una app abiertos. Su máscara deja libre la franja de
  la barra, así que un clic fuera cierra lo abierto y un clic en otro widget
  abre su panel en el mismo gesto. Verificado con Umbriel real.
- **Menú de apps.** `AppContextMenu` dejó de ser una capa a pantalla completa:
  ahora es solo la tarjeta. Un clic derecho en otra ficha de la barra cambia el
  menú a esa app sin cerrar el anterior; el mismo clic derecho en la misma
  ficha lo cierra. En Hyprland se conserva `HyprlandFocusGrab` como respaldo.
- **Modo en el escritorio activo.** `WorkspacePill` atenúa sus fichas mientras
  `SuperState.active` y dibuja encima un botón con el icono del modo actual
  (`mode-float` / `mode-tile`). Al pulsarlo, `WorkspaceModeState` cambia el
  escritorio entre Flotante y Mosaico. `WindowModeBar` ya no se instancia.
- **Minimizadas.** Pulsar la ficha atenuada de una ventana minimizada la
  restaura, en lugar de solo enfocarla.
- **Verificado.** Con el ratón virtual absoluto: el calendario se abre desde el
  reloj, un clic fuera lo cierra, el menú de apps cambia entre dos ventanas con
  un solo clic derecho y el botón de modo cambia `workspaceModes` y el layout
  nativo de Umbriel (`stacking` ↔ `dwindle`). `autoHideBar` se dejó como estaba.

### 2026-11-04 · Desanclar en el escritorio activo, indicadores y selector «Mover»

- **Desanclaje como el mockup.** `View::setPinned(false)` toma el escritorio
  activo del mismo grupo en el momento de desanclar, no el que tenía la ventana
  al fijarla. Reparenta la vista a ese escritorio y, si su layout no es
  `Stacking`, la vuelve a enganchar al mosaico con `setFloating(false)`. Si el
  escritorio activo es flotante, la ventana sigue flotante. Es el equivalente
  de `w.ws = activeWs` y el `if (modeOf(activeWs) !== 'floating')` del mockup.
- **Indicadores activos.** `SsdFrame` guarda si la ventana está fijada,
  flotante o maximizada. El botón correspondiente usa el mismo estado que
  `.wc.active`: relleno de acento al 13 % (20 % al pasar el ratón) y glifo de
  acento. «Cerrar» sigue usando su rojo. Los cambios de estado refrescan los
  colores aunque no haya movimiento de ratón.
- **Visibilidad de botones.** Se aplican las reglas exactas del ejemplo web:
  «Flotar» se oculta cuando el escritorio entero es `Stacking`; «Fijar» se
  oculta cuando la ventana está en el mosaico. Una ventana suelta dentro de un
  escritorio en mosaico muestra los dos.
- **Botón «Mover».** Ya no abre la vista general. Umbriel emite el evento
  `move_menu` (nuevo bit de suscripción, nombre incluido en
  `umbriel subscribe`), con `window`, `x`, `y` y un `serial` que evita que el
  filtro de eventos duplicados descarte dos aperturas iguales. Shell lo escucha
  en `UmbrielBackend` y `MoveMenuState` abre `WorkspacePicker`: tarjeta de
  46 px con los escritorios 1–9, el actual resaltado con el acento y el mismo
  tamaño de fila y número que el mockup. Elegir otro escritorio desancla si
  hace falta y llama a `CompositorState.moveToWorkspace`; elegir el actual solo
  cierra. Escape, un clic fuera y el cierre de paneles lo ocultan.
- **Atajo y scripts.** `umbriel move-menu <id>` emite el mismo evento. Sirve
  para probar sin ratón y para que el usuario pueda asignarle una tecla.
- **Verificación.** En Umbriel anidado: fijar en el escritorio 1, cambiar al
  2 y desanclar deja la ventana en el 2 y `floating:false`; en un escritorio
  `Stacking` sigue flotante. Capturas de los estados mosaico, fijada y
  maximizada con el indicador de acento. El selector se abrió por IPC, se
  revisó la tarjeta con el 1 resaltado y se cerró con Escape. No se pudo
  validar el clic dentro del anidado: el puntero del host no llega a los
  clientes del Umbriel anidado (los clientes reciben teclado pero no
  `wl_pointer`), así que el movimiento se validó por la misma cadena de
  `CompositorState` ya probada. En la sesión real el clic usa el ratón normal.
- **Instalado.** `/usr/bin/umbriel` es ahora `06e801aa2375`. La sesión abierta
  sigue con el proceso anterior hasta cerrar sesión; el respaldo de stock está
  en `/usr/bin/umbriel.stock-0.1.0`.
- **Nota de mantenimiento.** `umbriel config-replace` borra los overrides de
  layout de los escritorios. Tras usarlo para una prueba, hay que volver a
  aplicar los modos con `qs ipc -c shell call windows mode <n> <modo>` o
  reiniciar Shell. Esta vez se restauró la configuración real y se reaplicaron
  los nueve modos.

### 2026-11-05 · Fichas minimizadas y restauración exacta

- **La ficha ya no desaparece.** Al minimizar una ventana mosaicada, Umbriel
  la aparca en el scratchpad y su `workspace` queda vacío; antes Shell perdía el
  escritorio de origen y la ficha se iba de la barra. Ahora Umbriel publica
  `scratchpad_return_index` y `scratchpad_return_name` en `windows --json`, y
  Shell usa ese destino como origen. Como respaldo guarda el último escritorio
  real visto para cada ventana, así también funciona con binarios anteriores.
  La ficha se queda en la barra al 40 % de opacidad (85 % al pasar el ratón,
  como el mockup).
- **Restauración sin revelar el resto.** El camino anterior enfocaba la ventana
  y después ejecutaba `window-restore-from-scratchpad`. Enfocar muestra el
  scratchpad entero: al restaurar una ventana, las demás quedaban visibles
  sobre el escritorio con `workspace` vacío y no se podían usar como ventanas
  normales. El nuevo comando `umbriel restore-window <id>` devuelve directamente
  la ventana elegida a su escritorio guardado, sin sumar al resto del pad.
  También desminimiza las ventanas flotantes nativas.
- **Todo usa el mismo camino.** La barra, el centro de control y «Enfocar»
  sobre una minimizada llaman a `restore-window`; si el compositor aún no tiene
  el comando, Shell cae al camino anterior. En el backend, toda ventana del
  scratchpad cuenta como minimizada, incluso si el compositor la está mostrando
  temporalmente, para que se pueda restaurar y la ficha siga atenuada.
- **Verificación.** En Umbriel anidado con dos kitty en el escritorio 1: una
  minimizada al scratchpad y otra minimizada de forma nativa. Las dos siguen en
  la barra atenuadas, con origen 1. Restaurar la primera deja la segunda oculta
  y en su sitio; restaurar la segunda devuelve las dos a la normalidad. También
  se reprodujo el estado roto (scratchpad visible) y `restore-window` lo
  deshizo sin dejar ventanas sueltas.
- **Instalado.** `/usr/bin/umbriel` es ahora `f0d803b0e1e2`. La sesión abierta
  sigue con el proceso anterior hasta cerrar sesión; el respaldo de stock está
  en `/usr/bin/umbriel.stock-0.1.0`. El parche del edit incluye ahora 21
  archivos.

### 2026-11-05 · La ventana restaurada vuelve a dibujarse

- **Síntoma.** Al minimizar, la ficha se atenuaba pero al pulsarla la ventana
  no aparecía; desde el centro de control pasaba lo mismo: la ficha recuperaba
  su color pero la ventana seguía sin verse. `windows --json` decía
  `visible=true`, así que el estado lógico era correcto y el fallo era de
  dibujo.
- **Causa.** Ocultar el scratchpad no solo quita la ventana de la escena:
  primero la desvanece a opacidad 0 y después apaga su nodo, y solo mostrarlo
  revierte ambas cosas. El camino anterior enfocaba la ventana (mostraba el
  pad) antes de restaurarla, así que nunca se veía el problema. El nuevo
  `restore-window` devuelve la ventana sin mostrar el pad y dejaba el
  desvanecido y el nodo apagado: la ventana estaba en su sitio, invisible.
- **Arreglo.** `ScratchpadManager::restoreView` cancela el desvanecido
  (`cancelFadeAnimation`), la saca de la lista de ocultándose y vuelve a
  habilitar su nodo cuando el escritorio de destino está activo.
  `applyVisibility` no bastaba porque se salta las ventanas que ya constan
  como «en el escritorio activo», que es justo el estado de una minimizada.
- **Verificación.** En Umbriel anidado: minimizar una ventana mosaicada al
  scratchpad y restaurarla con `restore-window` la devuelve visible y
  enfocada, sin revelar la otra; una flotante minimizada de forma nativa
  también vuelve visible. Antes del arreglo solo se veía su icono de barra.
- **Sesión abierta.** Las ventanas que ya estaban en ese estado se
  recuperaron en caliente con el camino antiguo (enfocar, mover al
  scratchpad, enfocar para mostrarlo y restaurar), sin cerrar sesión.
- **Instalado.** `/usr/bin/umbriel` es ahora `cb8c75ec5f21`; el parche del
  edit sigue con 21 archivos. Para que el compositor en marcha use el arreglo
  hay que cerrar sesión y volver a entrar.

### 2026-11-05 · Cromo nativo con Mod, iconos de escritorio y volumen por app

- **Punto de partida.** El usuario descartó el lanzador en cuadrícula y el
  resto de ideas, y pidió tres cosas: iconos/carpetas en el escritorio como
  Windows, volumen por ventana y, como prioridad, barra oculta con las opciones
  visibles al mantener Mod. También dejó claro que los controles de ventana
  deben ser nativos del compositor, no capas de Shell.
- **Cromo superpuesto en Umbriel.** Nueva clave
  `[appearance.title_bar] overlay = true`. `View::titleBarChromeHeight()` mide
  el cromo y `View::titleBarHeight()` devuelve 0 cuando es superpuesto, así
  que el layout no reserva espacio. La geometría de `SsdFrame` lleva
  `titleBarOverlay`; el fondo, botones, icono y etiquetas se dibujan en
  `y = 0..h` en vez de `y = -h..0`. La barra se crea en `m_attachmentTree`
  para quedar sobre la superficie del cliente, y el hit test traduce la franja
  interior. `Server::refreshModTapState()` recorre las vistas y muestra u
  oculta la barra según `keyboardModifiers() & modKey()`.
- **Verificación del cromo.** En Umbriel anidado, sin Alt la ventana no tenía
  barra y el contenido llegaba al borde; con `wtype -M alt -s 2500 x`
  manteniendo Alt apareció la barra con icono, título, subtítulo y seis
  botones, sin mover el contenido; al soltar desapareció. Con `overlay =
  false` se comprobó que la barra normal sigue encima y el contenido empieza
  debajo. El primer intento de captura salía sin barra porque `wtype -M alt`
  suelto termina y destruye el teclado virtual; hay que mantenerlo con `-s`.
- **Iconos del escritorio.** `DesktopState.qml` usa `FolderListModel` sobre
  `~/Desktop`; `DesktopIcons.qml` crea una `PanelWindow` en
  `WlrLayer.Bottom` por pantalla, con `GridView` de arriba abajo. Las carpetas
  usan el icono del tema, las imágenes se ven como miniatura, y los
  `.desktop` se resuelven con `DesktopEntries.byId(fileName)` para tomar
  nombre e icono reales. Un clic selecciona y doble clic abre; también hay
  `qs ipc -c shell call desktop open <índice>` para probar. Verificado con
  carpetas, una imagen, un texto y Firefox ESR; abrir una carpeta lanzó
  Dolphin en esa ruta.
- **Volumen por aplicación.** `Audio.qml` expone `streams` (nodos
  `isStream` con audio) y los mantiene vivos en el `PwObjectTracker`. El centro
  de control → Volumen muestra «APLICACIONES CON AUDIO» con nombre, título del
  flujo, silencio y deslizador por nodo. Probado con Firefox reproduciendo un
  vídeo: apareció su flujo al 100 %. Queda pendiente el arrastre con ratón
  físico y, si se quiere, un botón nativo de volumen en la barra de título.
- **Instalado.** `/usr/bin/umbriel` es ahora `7d8c7aa0e5c2` y el parche del
  edit tiene 27 archivos. La sesión abierta sigue con el binario anterior y
  muestra un aviso de clave desconocida hasta cerrar sesión; el aviso
  desaparece con el binario nuevo.

### 2026-11-05 · Dos estilos de barra y fondo de pantalla

- **Petición.** El usuario quiere que «Barra de ventanas» tenga solo dos
  opciones, Flotante e Integrado, como la maqueta, y poder poner un fondo de
  pantalla.
- **Ajuste.** `SettingsState.windowChrome` (`floating`/`integrated`) se guarda
  en `settings.conf`. Se eliminaron los antiguos Automática/Siempre/Nunca de la
  interfaz; `nativeTitlebar` queda solo como respaldo para backends sin cromo
  nativo (Hyprland), donde flotante→auto e integrado→always.
- **Aplicación en Umbriel.** `scripts/shell-window-chrome` escribe
  `[appearance.title_bar] overlay` en `~/.config/umbriel/config.toml` sin tocar
  el resto del archivo, con inserción segura si falta la sección o la clave, y
  lanza `umbriel msg config-reload`. `SettingsState.applyWindowChrome()` lo
  ejecuta al arrancar y al cambiar el ajuste. Flotante = `overlay = true`;
  integrado = `overlay = false`.
- **Geometría al alternar.** `View::refreshConfigChrome()` compara el modo
  anterior del `SsdFrame` con el nuevo y marca `markArrange()` cuando cambia,
  porque la altura reservada cambia aunque la altura del cromo no. Además la
  barra vuelve al árbol de contenido (`chromeParent`), que funciona en ambos
  modos: en flotante se eleva sobre el cliente; en integrado queda encima del
  contenido. Se probó alternar en caliente en Umbriel anidado: flotante sin
  Alt sin barra, con Alt barra superpuesta; integrado con barra siempre visible
  y contenido debajo.
- **Fondo de pantalla.** `Wallpaper.qml` crea una `PanelWindow` por pantalla en
  `WlrLayer.Background`, con `Image` en `PreserveAspectCrop`. Ajustes muestra
  miniatura, «Elegir» y «Quitar»; el selector usa `kdialog` y cae a `zenity`
  (`scripts/shell-wallpaper-pick`). La ruta se guarda como `wallpaperPath` y se
  puede fijar por IPC. Verificado con la imagen 1920×1080 del sistema y con
  una ruta con espacios; quitarla devuelve el fondo del compositor.
- **Pruebas.** En la sesión real se comprobó la capa de fondo, el selector
  KDE y el guardado. En Umbriel anidado se comprobó el cambio de estilo con
  `UMBRIEL_CONFIG` apuntando a la copia de prueba y capturas con `grim`.
- **Instalado.** `/usr/bin/umbriel` = `fdf05109f9de`; el edit tiene 7 commits
  sobre `b6c4b7d` y el parche 27 archivos. Sigue haciendo falta cerrar sesión
  para estrenar el compositor nuevo.
- **Nota de desarrollo.** Quickshell recarga el QML en cada guardado, así que
  los estados intermedios pueden dejar un `ReferenceError` en el log (por
  ejemplo, una función que usa un `Process` que aún no se había añadido). Hay
  que comprobar el log después del último guardado, no durante la edición.

### 2026-11-05 · Píldoras separadas en flotante y barra sin botones

- **Flotante como el mockup.** La barra nativa de Umbriel deja de ser una
  franja a ancho completo en modo flotante: ahora dibuja dos píldoras, la del
  título (icono real + nombre) a la izquierda y la de los botones a la derecha,
  con margen de 7 px y radio de 10. El subtítulo se oculta en flotante. La
  franja dibujada mide `height + 2 * 7` para que las píldoras no las recorte la
  esquina de la ventana; `titleBarHeight()` sigue devolviendo 0, así que no
  reserva espacio ni mueve el contenido. Integrado conserva la franja completa.
- **Geometría y entrada.** `titleBarControls()` centraliza el cálculo de la
  píldora de botones y del desplazamiento horizontal que necesitan para quedar
  dentro del margen. El hit test usa el mismo desplazamiento; antes se dibujaban
  los botones 6 px a la izquierda de su zona clicable. Los rectángulos de borde
  y relleno se dibujan por separado y se copian también en las miniaturas.
- **Cambio de estilo en caliente.** `View::titleBarChromeHeight()` incluye los
  márgenes solo en flotante (36 → 50), pero lo reservado sigue siendo 0.
  `View::resizeFloatingForTitleBar()` ajusta el contenido de las ventanas
  flotantes al alternar: al pasar a integrado encoge 36 px y baja 36 px para
  que el marco exterior no se mueva; al volver a flotante hace lo contrario.
  Antes la barra integrada quedaba fuera de la pantalla en una ventana flotante
  hasta reiniciar.
- **Icono de mover.** El botón que abre el selector de escritorio dibuja `#`
  (dos verticales levemente inclinadas y dos horizontales), como el
  `.wc-glyph` del ejemplo web, en lugar de la cruz de flechas. La barra de
  respaldo de Shell (`WindowChrome.qml`) usa el mismo `#`.
- **Barra de tareas.** `Pill.qml` ya no pinta `Theme.accentSoft` cuando el
  widget está activo; solo usa `Theme.hover` al pasar el ratón. Los iconos
  siguen comunicando el estado con su color, igual que el botón de energía.
  `WorkspacePill.qml` también deja el fondo transparente en reposo; el
  escritorio activo se reconoce por las fichas de sus apps.
- **Verificado.** En Umbriel anidado: flotante con Alt muestra las dos
  píldoras y el `#`; integrado muestra la franja y el subtítulo; alternar en
  caliente en ambos sentidos mantiene el marco exterior y actualiza el tamaño
  del contenido. En la sesión real se comprobó que los widgets de la barra
  quedan sobre el fondo de la barra.

### 2026-11-05 · Filtro de pantalla nativo y barra uniforme

- **Luz nocturna y atenuación extra.** El problema era doble: `DisplayFilter`
  es una capa `Top` que no cubre la barra/paneles de Shell (otra capa `Top`), y
  la luz nocturna superponía un naranja translúcido que levantaba el negro y
  lavaba el contraste. Umbriel ahora tiene `[display]` (`brightness`,
  `extra_dim`, `warm`) y un shader de salida `screen.shell_display` en
  `EffectRegistry`, aplicado por `Output::applyOutputEffects` después de todas
  las superficies. `DisplayState.qml` escribe esos valores con
  `scripts/shell-display-filter` y recarga; la capa QML queda como respaldo para
  otros compositores.
- **Shader.** El tinte cálido multiplica por `vec3(1, 1-0.16*warm,
  1-0.36*warm)` y el brillo/atenuación multiplica por
  `brightness * (1-extraDim)`. El negro se queda negro. El efecto se excluye de
  las capturas por defecto (`in_capture = false`), que es lo deseable para una
  captura de pantalla.
- **Pruebas.** En Umbriel anidado, `warm=0.60` y `extra_dim=0.35` bajaron el
  blanco de `0.867` a `(0.565, 0.510, 0.443)`; con valores neutros volvió a
  `0.867`. Cambiar valores en caliente no recompila el shader (una sola línea
  `Compiling screen shader`). Para verlo en `grim` hay que poner
  `effects.in_capture = true`.
- **Escritorio vacío.** `WorkspacePill` muestra el número también cuando el
  escritorio activo no tiene apps, para que no parezca un fallo.
- **Acento uniforme.** `Theme.accentFaded` (mismo tono con menos opacidad) y
  `BarControl`/`Bar.qml`/`SystemStats.qml` usan el acento en todos los iconos
  de estado; solo quedan los colores semánticos de peligro/aviso.


### 2026-11-05 · Cerrar sesión y escritorio activo

- **Cerrar sesión no hacía nada en Umbriel.** `PowerMenu` ejecutaba
  `hyprctl dispatch exit` para todos los compositores. Ahora llama a
  `CompositorState.sessionQuit()` y `CompositorState.lockScreen()`, que cada
  backend resuelve: Hyprland con `hyprctl dispatch exit` y Umbriel con
  `umbriel msg session-quit skip-confirmation`. Comprobado en Umbriel anidado:
  el proceso termina y su socket desaparece.
- **Escritorio activo.** Umbriel mantiene creado un escritorio «siguiente»
  vacío. Como `exists` era cierto para cualquier escritorio listado, su número
  también salía en el acento y parecía que el foco estaba en otro sitio. Ahora
  solo el escritorio actual usa `Theme.accent`; el resto, `Theme.accentFaded`.
  La ficha actual lleva el fondo `Theme.hover` de forma permanente, así se sabe
  dónde estamos aunque no haya ninguna app abierta.

### 2026-11-05 · Modo ventanas sin interacción

- **El contenido no debe responder con Mod pulsado.** Al mantener Mod,
  `Server::refreshModTapState` activa `Cursor::setModInputShield`: se desactiva
  el `pointer-lock` o confinamiento activo y se limpia el foco del puntero. El
  cliente recibe `pointer-unlocked` y `leave`; el movimiento relativo deja de
  enviarse, y botones, rueda y toque sobre el contenido se descartan. Las capas
  de la barra y el cromo nativo siguen recibiendo entrada, y Mod+clic
  izquierdo/derecho continúa moviendo o redimensionando.
- **Velo visual.** Cada vista crea `m_modShade`, un rectángulo negro al 28 %
  dentro de su árbol de contenido, encima del cliente y debajo del cromo. Se
  activa con Mod, se ajusta al tamaño y radio del contenido y no se aplica a
  las píldoras de título ni a la barra.
- **Prueba.** En Umbriel anidado, `seat-log-client` con `pointer-lock` recibió
  `pointer-unlocked` y `leave` al mantener Alt, no recibió `relative-motion`
  durante el gesto y volvió a `pointer-enter` + `pointer-locked` al soltar. La
  captura mostró el contenido atenuado y el cromo intacto.
- **Pendiente.** Instalar `build/umbriel` (`06c369e96482`) en `/usr/bin/umbriel`
  y cerrar sesión; el binario en marcha sigue siendo `fdf05109f9de`.

### 2026-11-05 · Retardo del gesto Mod y ajustes de barra

- **Toque corto contra mantener.** El aislamiento del contenido se activaba en
  el mismo instante en que se pulsaba Mod. Ahora `Server::refreshModTapState`
  arma un temporizador de 320 ms (`kModHoldDelayMs`) y solo entonces llama a
  `setModHoldActive`, que enciende a la vez el escudo, el velo y las píldoras
  nativas. Al soltar antes de tiempo se cancela sin efectos. Shell usa el mismo
  retardo en `SuperState.holdDelay` para que su overlay no parpadee en un
  toque.
- **Prueba del retardo.** En Umbriel anidado, con una kitty de fondo claro y
  `wtype -M alt -s 1200 -m alt`: captura a 150 ms con brillo 0,914 (sin velo) y
  a 600 ms con 0,659 (28 % negro); al soltar vuelve a 0,914. Un toque de 100 ms
  se queda en 0,914 en todas las capturas.
- **Barra en los cuatro bordes.** `SettingsState.barPosition` (`abajo` por
  defecto) se guarda en `settings.conf` y se elige en Ajustes → «Posición de
  la barra»: abajo, arriba, izquierda o derecha. En los laterales la barra se
  dibuja en vertical con el mismo árbol de widgets apilado: logo y
  escritorios arriba, reloj compacto en el centro y controles/estado abajo. Los
  escritorios pasan a mostrar solo su número y la música solo la portada para
  caber en 44 px. `Bar.qml` mueve anclas, márgenes, máscara, franja de
  revelado y reserva de espacio; `Pill.qml` y `ControlDrag.qml` recalculan el
  borde de la barra, y calendario, energía, bandeja, batería, panel lateral,
  panel rápido, OSD, barra del modo ventanas y menú de apps eligen su ancla
  según el lado. Con la barra lateral, el panel rápido se abre al lado y a la
  altura del control pulsado.
- **Música ajustable.** `Pill.qml` admite `preferredWidth` y `BarMusic.qml` lo
  usa para respetar `musicWidth`. Mientras `SuperState.active`, un asa en el
  borde derecho estira la píldora entre 140 y 420 px; doble clic la devuelve al
  ancho automático. Verificado a 300 px en la sesión real.
- **Instalación.** `/usr/bin/umbriel` quedó actualizado a `69fe1a58a28d` con
  `sudo`; el drop-in de systemd se retiró. Falta cerrar sesión para que el
  proceso en marcha cargue ese binario.

### 2026-11-05 · Retardo ajustable, música y reloj

- **Retardo de Mod configurable.** `[input] mod_hold_delay_ms` sustituye a la
  constante de 320 ms. Umbriel lo lee en cada evento de modificadores; Shell lo
  expone en Ajustes → «Retardo al mantener Super» (pasos de 50 ms), lo guarda
  como `superHoldMs` y `scripts/shell-mod-hold` lo escribe en la configuración
  del compositor y recarga. Verificado en anidado: con 600 ms, una pulsación de
  1,6 s no atenúa a los 300 ms y sí a los 900 ms; un toque de 200 ms no atenúa.
  Con 200 ms recargados en caliente, 350 ms ya atenúan.
- **Música estable al mantener Super.** El widget se estiraba mal por tres
  motivos: el bloque de texto medía desde `root.width` y realimentaba el ancho
  de la píldora; el asa de estirado entraba en la fila de contenido por el
  `default property alias` de `Pill.qml`; y el `Loader` de la barra conservaba
  el ancho del primer montaje. Ahora el texto se mide desde `musicWidth`, el
  asa usa `parent: root` y el `Loader` publica `Layout.preferredWidth/Height`
  del elemento cargado. 140 y 300 px se aplican en vivo sin mover el texto.
- **Reloj.** El lado izquierdo queda en dos líneas: hora arriba y día de la
  semana abajo. El derecho vuelve a tres filas: número del día arriba, mes en
  medio y año abajo, con poco aire entre ellas. La barra pasa de 40 a 44 px
  para dar más margen vertical. Verificado abajo y arriba, con calendario y
  panel lateral recolocados.
- **Prueba.** `build/umbriel config validate` confirma el valor por defecto
  (320), el válido (550) y el recorte (10 → 50). La compilación de pruebas no
  se pudo completar en este entorno porque falta `xcb-xtest`; el binario normal
  compila sin avisos nuevos. El commit quedó en `0f9951fa5f30`, instalado en
  `/usr/bin/umbriel`; la sesión en marcha todavía es `69fe1a58a28d`.

### 2026-11-05 · Tamaño y cascada de ventanas flotantes

- **Tamaño por defecto al salir de mosaico.** `View::floatingRestoreSize` ya
  no devuelve el tamaño del mosaico cuando la ventana nunca ha flotado: usa
  `[layout.stacking] default_width_fraction` y `default_height_fraction`
  (0,6 por defecto) sobre el área útil. Un tamaño recordado, incluido el de una
  ventana redimensionada, se conserva. Antes, flotar la única ventana de un
  escritorio la dejaba a pantalla completa.
- **Cascada.** `cascadeFloatingPlacement` reúne los marcos de las ventanas
  flotantes visibles y desplaza la nueva en diagonal hasta que deja de tapar a
  otra. `cascade_step` fija la separación mínima; 0 la deduce de la barra de
  título, nunca por debajo de 32 px. Al cambiar un escritorio entero de mosaico
  a flotante se ignora la posición recordada y las ventanas entran en cascada;
  las que ya flotaban se quedan donde estaban. Verificado en anidado: tres
  ventanas quedan en 189,99 / 221,131 / 253,163.
- **Ajustes.** Dos filas nuevas en el centro de control: «Tamaño de ventanas
  flotantes» (40–80 %, pasos de 5) y «Separación en cascada» (Auto o 8–96 px,
  pasos de 8). Se guardan como `floatingSizePercent` y `floatingCascade` en
  `settings.conf`; `scripts/shell-floating-defaults` escribe la configuración
  de Umbriel y recarga. `umbriel config validate` acepta los valores y recorta
  los fuera de rango (0,05 → 0,1; 500 → 200).
- **Prueba.** 0,6 en una salida de 946×496 da 568×298 y centra la ventana;
  0,5 con cascada de 48 da 473×248. Binario `af15084668f2` instalado en
  `/usr/bin/umbriel`; la sesión en marcha sigue con `69fe1a58a28d`.

### 2026-11-05 · Disposición de mosaico y redimensionado con el borde

- **Memoria por modo.** `Workspace` guarda una captura del layout al salir de
  cada modo de mosaico y la restaura al volver. Dwindle conserva el árbol y sus
  ratios; master, sus áreas y filas; scrolling, sus columnas y anchos. Se
  implementa con `rememberTilingLayout`, `restoreRememberedLayout` y
  `forgetViewInRememberedLayouts`, llamados desde `applyLayoutConfig` y
  `removeView`. Las ventanas abiertas durante la estancia en Flotante se
  insertan después; las cerradas dejan un hueco que el layout colapsa.
- **Borde redimensionable.** `Cursor::tiledBorderTarget` busca la ventana de
  mosaico más cercana cuyo borde esté a 10 px o menos del puntero, incluso si
  el puntero está en el hueco entre dos ventanas, y `beginResize` ajusta el
  reparto. `hoverResizeEdges` usa la misma franja y muestra el cursor de
  redimensionar. Un arrastre con Super en el centro sigue moviendo la ventana;
  Mod+clic derecho mantiene el comportamiento anterior.
- **Prueba.** En anidado (1280×720, mod = Alt): dwindle de 630 a 800 deja
  796/456; desde el hueco (810) a 600 deja 586/666; master de 703 a 900 deja
  886/366; el arrastre central sigue intercambiando ventanas. Cuatro ventanas
  dwindle vuelven idénticas tras pasar por stacking, y master también.
- **Configuración restaurada.** `shell-mod-hold` y `shell-floating-defaults`
  compartían el temporal `$cfg.shell-tmp`; dos ejecuciones simultáneas podían
  mover un archivo a medio escribir y dejar `config.toml` en 13 líneas. Se
  restauró la copia completa, hay respaldo en
  `Shell/umbriel-config-backup.toml` y ambos scripts usan ahora
  `flock` sobre `config.toml.shell-lock` y un `mktemp` único. Binario
  `8d1317f9205c` instalado en `/usr/bin/umbriel`; la sesión en marcha sigue con
  `69fe1a58a28d`.
- **Recaída y cierre del problema (2026-11-06).** El archivo volvió a quedar en
  18 líneas y perdió `[general] autostart`; Umbriel arrancaba pero el shell no,
  y el escritorio quedaba negro. Faltaban por proteger
  `shell-window-chrome`, `shell-display-filter`, `shell-keyboard-layout` y
  `shell-umbriel-theme`, que escribían en el sitio o con el temporal compartido.
  Los cuatro usan ahora `flock` sobre `config.toml.shell-lock` y escritura
  atómica con `mktemp`; se probó con seis procesos concurrentes y el archivo
  conserva sus 188 líneas, todas las secciones y `autostart`. La configuración
  se restauró desde `install/config/umbriel-config.toml` y se validó con
  `umbriel config validate`. El archivo truncado queda en
  `~/.config/umbriel/config.toml.truncado-20261106`.

### 2026-11-05 · Barra con Super y hueco por ventana

- **La barra responde con Mod pulsado.** `Cursor::processButton` interceptaba
  cualquier clic izquierdo con Mod antes de mirar si había un panel debajo. La
  condición exige ahora `layer == nullptr`: sobre una ventana se sigue
  moviendo o redimensionando, y sobre la barra o una capa superpuesta el clic
  llega a la interfaz. Esto arregla el botón de modo de la píldora y los chips
  Flotante/Mosaico de la barra de ventanas.
- **Hueco por ventana al flotar.** `Workspace::rememberViewTileSlot` guarda una
  captura del layout al flotar una ventana y `restoreViewTileSlot` la
  reconstruye al mosaicarla, siempre que las demás ventanas del recuerdo sigan
  mosaicadas y no haya ninguna nueva. Se usa desde `View::setFloating` y
  `Workspace::layoutAttach`; el recuerdo se borra en `removeView`, así que no
  viaja a otro escritorio ni sobrevive al cierre. Durante un cambio de modo se
  desactiva con `m_switchingLayoutMode` para no competir con la memoria por
  modo de A14.
- **Prueba.** En Umbriel anidado con Shell real aislada: pulsar el botón de modo
  con Alt pulsado cambia a stacking y vuelve a dwindle con geometría idéntica.
  Flotar y devolver `dos` en dwindle la deja otra vez en 645,9; `cuatro` en
  master vuelve a 708,9; `tres` en scrolling vuelve a 9,9. Con una ventana
  nueva abierta mientras la otra flota, la devolución inserta al final sin
  romper el mosaico. Binario `ae213c10e053` instalado en `/usr/bin/umbriel`.

### 2026-11-05 · Cursor fuera de los bordes y hueco al fijar

- **Cursor.** `updateInteractiveCursor` salía sin limpiar el cursor propio
  cuando no había vista bajo el puntero, y `refreshPointerContents` se saltaba
  las zonas sin superficie (barra, escritorio). El resultado era una flecha de
  redimensionar pegada tras salir del borde. Ahora recibe un indicador de panel,
  restaura el cursor cuando no hay borde y se recalcula también sobre huecos y
  paneles. La ruta de movimiento con el escudo de Mod usa el mismo indicador.
- **Fijar y hueco.** `adoptPinnedViews` movía la ventana al escritorio activo y
  `removeView` borraba su recuerdo. Ahora el recuerdo se conserva con
  `preserveViewSlot` mientras la ventana está fijada, y se borra en todos los
  escritorios al desanclar o acoplar en otro (`Server::forgetViewTileSlots`).
  Cerrar una ventana limpia también los recuerdos de otras ventanas que la
  citaban, evitando punteros muertos.
- **Prueba.** En Umbriel anidado (946×1002): borde x=468 → cursor horizontal,
  centro → mano, barra → mano/flecha, sin arrastrar la forma anterior.
  Fijar `dos`, cambiar de escritorio y volver, y desanclar la devuelve a
  478,9. Fijar una ventana ya flotante y hacer dos idas y vueltas también
  recupera su hueco. Desanclar en el segundo escritorio y volver inserta `dos`
  abajo (478,476), señal de que el recuerdo se borró. Cerrar `tres` mientras
  `dos` flota no rompe el mosaico. Binario `43e5f7496f04` instalado en
  `/usr/bin/umbriel` (sha256 `9aac59e71aaefd97…`).

### 2026-11-05 · Apertura en cascada de apps nuevas en Flotante

- **Qué cambió.** `View::placeInUsableArea` recibe `openingPlacement`, que el
  mapeo inicial pasa a `true`. Si la ventana se abre en un escritorio stacking,
  no es transitoria, no es utilidad pasiva de Xwayland, no está maximizada ni a
  pantalla completa y ninguna regla le fija tamaño, toma el tamaño por defecto
  de `[layout.stacking]` (`default_width_fraction` × `default_height_fraction`)
  y se coloca con la misma cascada que usa el cambio Mosaico→Flotante.
- **Por qué.** Hasta ahora la cascada solo movía la ventana: el tamaño seguía
  siendo el que pedía la app, así que una app nueva podía nacer enorme y tapar
  el escritorio. El cambio iguala la apertura con la transición de modo.
- **Límites.** Solo se aplica la primera vez (mientras `m_floating.size()` está
  vacío); un tamaño de regla o recordado gana. Diálogos y ventanas transitorias
  conservan su tamaño; las reglas de posición se respetan y solo cambian el
  origen. Una ventana abierta en mosaico sigue entrando como baldosa normal.
- **Prueba.** En Umbriel anidado (946×436 útil): dos apps nuevas en el
  escritorio 2 en Flotante quedaron en 568×262 en 189,87 y 221,119, idénticos
  a los huecos de cambiar el escritorio 1 de Mosaico a Flotante. La regla de
  tamaño 300×200 se respetó; la regla solo de posición mantuvo 568×262 en
  40,60. Abrir en un escritorio en mosaico siguió mosaicando.
- **Deuda.** Las comprobaciones de `tests/harness/checks` que esperan el tamaño
  del cliente al abrir en stacking quedan desfasadas; el harness no se ejecuta
  en este flujo. Binario `a4b9b8fdd314` instalado (sha256
  `98591e442ac8b635…`); falta cerrar sesión.

### 2026-11-05 · A5 (fichas minimizadas) y C1 (orden persistente)

- **A5 · Causa real.** Las fichas minimizadas desaparecían de la barra al
  reiniciar Shell, aunque la ventana siguiera en el scratchpad y se pudiera
  restaurar desde Ajustes. Umbriel publicaba `scratchpad_return_index` en base
  0: la ventana del escritorio 1 devolvía `0`, que Shell interpretaba como «sin
  origen», y la del escritorio 2 devolvía `1`, un escritorio antes. Además, el
  índice 0 se usaba como centinela de «sin retorno».
- **Arreglo.** `ScratchpadManager::returnWorkspaceIndexFor` distingue la
  ausencia por el nombre vacío, no por el índice, y el IPC publica
  `scratchpad_return_index` en base 1, igual que `workspaces`. Shell resuelve
  primero `scratchpad_return_name` a índice con `workspaceIndexByName`, así
  también funciona con binarios antiguos. Documentado en `docs/user/ipc.md`.
- **Descartado como curiosidad.** Recordar la geometría de cada app entre
  sesiones. No se implementa: choca con el tamaño por defecto de A20 y con las
  reglas de ventana de Umbriel. No hay `windows.json`.
- **C1 · Orden persistente.** `BarState` expone `defaultControls`,
  `defaultCenterOrder`, `restore()` y `resetLayout()`. `SettingsState` escribe
  `barControls=` y `centerOrder=` en `settings.conf` y los restaura al
  arrancar; Ajustes añade «Orden de los controles → Restablecer».
- **Plataforma.** Hyprland queda descartado. Solo Umbriel sobre Debian; el
  backend antiguo se conserva como legado hasta la instalación limpia.
- **Binario.** `2ae0007635ec` instalado en `/usr/bin/umbriel` (sha256
  `8d606fce6a5b8c35…`); falta cerrar sesión para estrenarlo.

### 2026-11-05 · Bandeja, color de fondo y vista general

- **B4 · Bandeja.** Los iconos de bandeja se agrupan en `TrayPanel.qml`, un
  desplegable que se abre con el chevron de `Bar.qml` y se coloca sobre ese
  botón. `TrayState` guarda si está abierto y el ancla horizontal. El panel
  cierra al pulsar fuera (la capa `outsideCatcher` de la barra), con Escape, al
  abrir otro panel, al ocultarse la barra o al quedarse sin iconos.
  Quickshell entrega `SystemTrayItem.icon` como fuente de imagen
  (`image://icon/...`), no como nombre del tema. La barra lo trataba como
  nombre, `hasThemeIcon()` devolvía falso y no se veía ningún icono. Ahora usa
  la fuente tal cual. Dentro del panel, clic izquierdo activa (o abre el menú si
  la app solo tiene menú), derecho abre el menú, central lanza la acción
  secundaria y la rueda reenvía el paso. Los menús usan
  `SystemTrayItem.display()` y necesitan `//@ pragma UseQApplication` en
  `shell.qml`; sin el pragma, Quickshell avisa de que no puede mostrar menús de
  plataforma. Verificado en anidado y en real con KDE Connect.
- **Puente XWayland.** `xwaylandvideobridge` permite que las apps X11 capturen
  la pantalla por PipeWire. Abre una ventana-herramienta que no debe verse; la
  regla de scratchpad la ocultaba al lanzarla a mano, pero tras el arranque de
  la sesión aparecía en el escritorio. Se desactivó con
  `~/.config/autostart/org.kde.xwaylandvideobridge.desktop` (`Hidden=true`) y
  se cerró el proceso. El paquete sigue instalado por si hace falta compartir
  pantalla desde una app X11.
- **C3 · Brillo.** `DisplayState.setBrightness()` ya aplica el paso del 5 % y
  muestra el OSD; verificado por IPC en anidado. Falta la tecla física.
- **C4 · Fondo por color.** `SettingsState.wallpaperColor` guarda `#RRGGBB` en
  `settings.conf` como `wallpaperColor=`. Elegir color quita la imagen; quitar
  la imagen vuelve al color. Ajustes añade seis muestras y un campo propio.
  `shell-system-theme` se verificó con GTK 3/4 (`gtk.css`) y KDE
  (`kdeglobals`, `BreezeDark`, mismo acento).
- **D3 · Vista general.** `Mod+Tab` pasa a `overview-toggle` y los controles de
  Shell a `Mod+Shift+Tab`. `UmbrielBackend` se suscribe al evento `overview` y
  `CompositorState.overviewOpen` permite que `shell.qml` cierre lanzador,
  notificaciones, calendario, energía, selector de movimiento y controles de
  ventana. Verificado en anidado con Alt+Tab y en real con Super+Tab.
- **C3 · Brillo bidireccional.** `ddcutil` no emite avisos, así que
  `DisplayState` relee `getvcp 10` cada 3 s cuando hay brillo por hardware y
  actualiza `brightness` sin escribir de vuelta ni mostrar OSD. Si el shell está
  escribiendo o detectando, la lectura se salta. Verificado en real: cambio
  externo a 40 adoptado y siguiente paso del shell a 35.
- **A21 · Cambiar la barra de ventanas no deshace el mosaico.** La recarga de
  `[appearance.title_bar]` borraba el override de `workspace-set-layout` porque
  `refreshLayouts()` siempre llamaba a `clearLayoutModeOverride()`. Ahora
  `ConfigEffects.reassertLayoutModes` solo se activa con cambios que deciden el
  modo (`[layout] mode`, reglas o inventario de escritorios); los cambios
  cosméticos conservan el override y solo rehacen la disposición. Verificado en
  anidado con dwindle: Flotante→Integrado→Flotante mantiene el mosaico.
  Binario `d3f5effaad771b37…` instalado; falta cerrar sesión.
- **D1 · Soltar archivos en el escritorio.** `DesktopIcons.qml` gana un
  `DropArea` que llama a `scripts/shell-desktop-drop`. El script mueve los
  archivos de la misma unidad y copia los de otra, con sufijo « (1)» para no
  sobrescribir. Probado con un HOME temporal; el arrastre real desde Dolphin
  queda pendiente.
- **C2 · VPN completa.** `VpnView` gana importación de `.ovpn` mediante
  `scripts/shell-vpn-pick` y `nmcli connection import`, y un editor por perfil
  (nombre y arranque automático) con borrado en dos pasos. `VpnState` refresca
  la lista cada 5 s y expone IPC (`vpn list/importFile/save/remove`). El
  complemento `network-manager-openvpn` es obligatorio; no venía instalado.
- **C2 · Perfiles de energía.** `PowerProfilesState` lee `powerprofilesctl` y
  Ajustes pinta las fichas Rendimiento/Equilibrado/Ahorro; el IPC del menú de
  energía gana `profile` y `status`. Verificado en real.
- **C5 · Clima manual y alarmas fuera del shell.** `SettingsState.weatherPlace`
  decide la URL de wttr.in; `scripts/shell-alarms` corre como servicio de
  usuario, evita duplicar avisos mientras `qs` vive y usa KDialog/Zenity si no
  hay servidor de notificaciones. El temporizador guarda su `deadline` en
  `timer.conf`, lo termina el demonio con el shell cerrado y el panel lo
  restaura al volver.
- **D1 fase 2 aparcada.** El usuario prefiere dejar los iconos del escritorio
  para el final; no se sigue con recolocación ni posiciones persistentes hasta
  terminar el resto.
- **B2 · Bloquear solo sin reproducción.** `Bar.qml` añade un `IdleInhibitor`
  ligado a la superficie de la barra y a `MusicState.playing`; mientras suena
  música o vídeo por MPRIS no se emite inactividad y `swayidle` no llega a
  lanzar `hyprlock`. Verificado con VLC: 10 s sin disparar con reproducción,
  8 s disparando al cerrarlo.
- **B3 · Portal sin diálogo de permiso.** El backend `umbriel.portal` solo
  implementa ScreenCast y Screenshot; el frontend necesita además
  `org.freedesktop.impl.portal.Access` para pedir permiso. Sin él, la captura
  se quedaba en «Failed to show access dialog: Timeout was reached» y una vez
  provocó un SEGV. `~/.config/xdg-desktop-portal/portals.conf` mapea Access a
  GTK. Verificado: captura con PNG real y ScreenCast con selector de pantalla
  o ventana que devuelve un stream de HDMI-A-1 (1920×1080). Falta el flujo
  completo desde Firefox y una app X11.
- **C2 · Energía, finalmente solo en la batería.** Ajustes llegó a mostrar la
  sección «ENERGÍA», pero el usuario pidió quitarla: los perfiles se cambian
  desde el panel del icono de batería. `PowerProfilesState` sigue alimentando
  ese panel y el IPC `power profile`.
- **Decisiones del usuario (2026-11-05).** Las pestañas del reloj se
  rediseñarán más adelante; la VPN necesita más opciones que dirá el usuario.
  No avanzar en ninguna de las dos por iniciativa propia.
- **Perfiles de energía en la batería.** La barra pinta una batería propia,
  como el mockup: contorno, pista, relleno, punta, rayo amarillo y barrido del
  contorno al cargar. `BatteryState` conserva la visibilidad sin batería (rayo
  de corriente y sin porcentaje) y `BatteryPanel` muestra los perfiles con las
  fichas Ahorro/Equilibrado/Rendimiento. En Ahorro el icono se tiñe de celeste.
  Ajustes ya no muestra la sección ENERGÍA. Verificado por IPC y captura; falta
  el clic físico.
- **Lo que hace cada perfil en este equipo.** El procesador es un Intel
  i3-10105F con `intel_pstate`; el driver de plataforma de
  `power-profiles-daemon` es `placeholder`, así que el perfil solo cambia la
  preferencia energía/rendimiento del CPU (`power`, `balance_performance` o
  `performance`), no la autonomía (no hay batería). No cambia el límite máximo
  de frecuencia ni el turbo: cambia con qué agresividad sube de frecuencia y
  cuánto prioriza eficiencia frente a respuesta.
- **Música de borde a borde.** La carátula del widget de la barra ocupa ahora
  todo el alto de la píldora (34 px), pegada al borde izquierdo, y el texto
  está compensado a la derecha. Se verificó con una pista real en reproducción.
- **Carátula con la forma de la píldora.** La imagen se recorta con
  `MultiEffect` y una máscara de `Theme.itemRadius`, así que sus cuatro esquinas
  son redondeadas y no asoma ningún pico cuadrado sobre el fondo de la barra.
- **Tráfico de red estable.** El botón tiene un ancho fijo de 50 px para que
  las cifras no desplacen a los iconos vecinos, la cifra es de 9 px, la unidad
  queda más pegada y las flechas más cerca del texto.
- **Escritorios fijos.** Umbriel usaba el modelo dinámico y solo mantenía dos o
  tres escritorios; por eso cambiar al 4–9 o mover una ventana a ellos acababa
  en el último existente. Se añadió `[output."HDMI-A-1"] workspaces = 9` a la
  configuración. En un portátil o tras una instalación limpia hay que repetir
  esa sección con el conector que corresponda.
- **Números de escritorio ocupados.** `WorkspacePill` ilumina el número con el
  acento cuando el escritorio tiene cualquier ventana, incluidas las
  minimizadas o las que están en el scratchpad. Los vacíos siguen atenuados; el
  activo se distingue además por el fondo de la píldora.
- **Guía de instalación limpia.** `INSTALACION.md` documenta el equipo, los
  repositorios (`trixie-backports` y Noctalia), los paquetes, la compilación del
  edit de Umbriel, la configuración de Shell/Umbriel, portales, sudoers, SDDM,
  copias y verificación. Los archivos de sistema que vivían fuera del proyecto
  se guardaron en `install/`: scripts de `~/.local/bin`, configuración de
  Umbriel, `portals.conf`, unidad de alarmas, fuentes de APT y regla de sudoers.
  La instalación está automatizada con `install.sh` y
  `scripts/install-umbriel-edit.sh`; falta probarla de principio a fin en un
  Debian limpio y probar la reversión (E4).
- **Veredicto de uso principal.** El sistema está listo para el día a día en
  este equipo salvo B3 (captura/uso compartido) sin probar y el instalador sin
  probar en limpio. B5 sí se puede probar porque el AX210 tiene Wi-Fi y
  Bluetooth. No bloquean el uso: A4, opciones VPN, pestañas del reloj, iconos
  del escritorio, perfiles personalizados y adaptación a portátiles.
- **Escritorios automáticos, idea futura.** El `workspaces = 9` actual depende
  del conector `HDMI-A-1`. Un script que lea `umbriel outputs --json` y escriba
  el inventario por salida evitaría repetir la sección en cada equipo.
- **Perfiles personalizados, idea futura.** El usuario preguntó por perfiles
  propios con tope de frecuencia de CPU/GPU y algo tipo TDP para portátiles.
  `power-profiles-daemon` no admite perfiles personalizados; haría falta un
  ayudante con polkit para escribir en `cpufreq`/`intel_pstate`, `amdgpu` o
  `nvidia-smi`, y límites RAPL/`ryzenadj` donde el firmware lo permita. Queda
  anotado como pendiente y no se implementa hasta que concrete los controles.

### 2026-11-05 · Publicación en GitHub e instalador E1

- **Repositorio público.** El proyecto se publicó en
  `https://github.com/Gitnameb/Shell` bajo GPL-3.0, con `README.md`, aviso de
  proyecto personal en desarrollo y `.gitignore`. Se excluyeron los binarios de
  `wl-clipboard`; ahora `wl-copy`/`wl-paste` se usan del sistema y los scripts
  tienen el binario local solo como respaldo. Se añadió `wl-clipboard` a los
  paquetes.
- **Plantillas saneadas.** Las rutas `/home/username` se sustituyeron por
  `/home/USUARIO` en `install/`, se vaciaron el fondo y la ciudad del clima, y
  la regla de sudoers usa `USUARIO`.
- **Instalador general.** `install.sh` añade repositorios, instala paquetes,
  copia configuración sin sobrescribir, crea la regla de sudoers, activa las
  alarmas y llama al script del edit. Tiene `--dry-run`, `--skip-packages`,
  `--skip-edit`, `--skip-config`, `--force-config` y `--with-firmware`.
- **Módulos sin duplicar paquetes.** `install-packages.sh` instala la base del
  shell, KDE/Qt, audio, portales, compilación y firmware. `network.sh` es el
  único que instala y configura NetworkManager, Wi-Fi, punto de acceso,
  Bluetooth y VPN (`network-manager-openvpn`), además de `dnsmasq-base`,
  `libspa-0.2-bluetooth` (audio Bluetooth) y `qrencode`. `--skip-network`
  omite también esos paquetes.
- **Versiones alineadas de backports.** `install-packages.sh` instala PipeWire
  y Mesa en bloque desde `trixie-backports`: `pipewire`, `pipewire-bin`,
  `pipewire-pulse`, `wireplumber`, `libpipewire-0.3-*`, `libspa-0.2-modules`,
  `libgbm1`, `mesa-libgallium`, `libgl1-mesa-dri`, `libglx-mesa0`,
  `libegl-mesa0`, `mesa-va-drivers` y `mesa-vulkan-drivers`. Mezclar versiones
  de trixie y backports rompía las dependencias exactas de `libspa`, pixman,
  Mesa y Wayland. `network.sh` instala el plugin Bluetooth junto con el stack
  completo si necesita actualizar PipeWire, y reinicia `pipewire` y
  `wireplumber` al terminar.
- **Edit automatizado.** `scripts/install-umbriel-edit.sh` reutiliza
  `~/umbriel-edit` o clona upstream, hace checkout de `b6c4b7d`, aplica
  `umbriel-edit.patch`, compila con meson/ninja, guarda el binario original e
  instala con `mv` atómico. Valida el hash y detecta si el binario ya es el
  edit.
- **Rutas de usuario.** Se quitaron las rutas `/home/username` de los comandos
  de `shell-idle`, `shell-keyboard-layout` y `shell-umbriel-theme`; ahora usan
  `Quickshell.env("HOME")`, así que el shell funciona con cualquier usuario.
- **Modo ligero.** Se quitó `plasma-workspace` y `kde-cli-tools` de la lista de
  paquetes. `shell-system-theme` ahora escribe `ColorScheme` e `Icons` con
  `kwriteconfig6` y solo usa `plasma-apply-colorscheme` si existe. Probado con
  un HOME temporal y sin `plasma-apply-colorscheme`: las apps KDE quedan en
  BreezeDark/Breeze y GTK sigue recibiendo el acento. Queda pendiente una
  alternativa ligera para el acento en apps KDE (generar un `.colors` propio,
  matugen, wallust, etc.). Para SDDM se usa `sddm-theme-maya` cuando no hay
  tema Breeze.
- **Pruebas.** Se verificó que el parche reproduce exactamente el árbol del edit
  y que una compilación desde un clon limpio termina correctamente
  (`umbriel 0.1.0 (b6c4b7ddfb03-dirty)`). También se probó `install.sh
  --dry-run`. Falta la instalación completa en una VM o disco aparte y la
  prueba de reversión E4.

### 2026-11-06 · Red de seguridad de config.toml

- **El escritorio negro no era del compositor.** `~/.config/umbriel/config.toml`
  quedó en 18 líneas y perdió `[general] autostart`; Umbriel arrancaba, pero
  Quickshell no. El archivo roto se conservó en
  `~/.config/umbriel/config.toml.truncado-20261106`.
- **Causa.** Seis scripts independientes escribían el mismo archivo al iniciar
  sesión. Faltaban por proteger `shell-window-chrome`, `shell-display-filter`,
  `shell-keyboard-layout` y `shell-umbriel-theme`; los dos primeros usaban un
  temporal compartido y los otros escribían en el sitio. Ahora los seis scripts
  calculan el valor y llaman a `shell-config-set`, el escritor único que
  centraliza `flock` sobre `config.toml.shell-lock`, la validación y el
  `os.replace` atómico.
- **`config validate` no bastaba.** Un TOML de 18 líneas puede validar aunque
  no tenga lo necesario para lanzar el shell. Por eso el guardián comprueba
  además la clave `autostart` y la pérdida masiva de secciones.
- **Guardián.** `install/bin/umbriel-config-guard` (`ensure`, `save`, `status`)
  restaura desde `config.toml.good` o `config.toml.template`, guarda una copia
  `config.toml.broken-*` y registra en
  `~/.local/state/shell/config-guard.log`. Se ejecuta antes de Umbriel con el
  drop-in `~/.config/systemd/user/umbriel.service.d/50-config-guard.conf`
  (`ExecStartPre=-%h/.local/bin/umbriel-config-guard ensure`). `shell-start` lo
  llama otra vez como segunda capa y guarda una copia buena 15 segundos después
  del arranque.
- **Pruebas del guardián.** Ocho escenarios (válido, truncado real, ausente,
  `autostart = []`, TOML inválido, sin copia buena, sin copias y plantilla sin
  renderizar) en `scripts/test-config-guard.sh`, y concurrencia de seis
  procesos × tres rondas. La configuración conserva sus 188 líneas, todas las
  secciones y `autostart`.
- **Escritor único (hecho).** `install/bin/shell-config-set` es el único
  programa que sustituye `config.toml`. Aplica parches por sección, conserva
  comentarios y claves desconocidas, escribe en un temporal, valida con
  `tomllib` y `umbriel config validate`, y solo entonces hace `os.replace`
  atómico; si algo falla, deja el original intacto. Los seis scripts
  (`shell-mod-hold`, `shell-floating-defaults`, `shell-window-chrome`,
  `shell-display-filter`, `shell-keyboard-layout` y `shell-umbriel-theme`) ya no
  abren el archivo para escribir. Pruebas: `scripts/test-config-set.sh`
  (36 comprobaciones), `scripts/test-config-writers.sh` (39), 8 escritores
  concurrentes × 5 rondas y una prueba de estrés con 40 escritores, 13 de
  ellos terminados con `kill -9`. Detalle en `CONFIGURACION-UMBRIEL.md`.
- **Consumo en reposo (hecho).** El `qs` en reposo bajó de 7,4 % a 0,6 % de
  CPU y con el centro de control abierto de 12,4 % a 1,0 %. Las causas eran el
  barrido infinito del icono de batería en equipos sin batería (`mains`),
  los dos giros de «buscando redes» atascados cuando `scanning`/`hasScanned` no
  se resolvían, y la consulta de ventanas/escritorios cada 600 ms. Ahora la
  batería solo barre al cargar, el Wi-Fi tiene vigilante de 12 s y `nmcli`
  timeout, y `UmbrielBackend` usa `umbriel subscribe`. El centro de control se
  carga con `Loader` la primera vez y los iconos usan `MultiEffect` en vez de
  `ColorOverlay`. Detalle: `CONFIGURACION-UMBRIEL.md` §17.

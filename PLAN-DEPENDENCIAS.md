# Plan · Dependencias opcionales del centro de control

Este documento separa lo que ya funciona con la instalación actual de lo que
podría mejorar con paquetes extra. `cliphist` y `brightnessctl` ya forman parte
de la instalación por defecto: el primero guarda el portapapeles y el segundo
controla el brillo del panel interno.

## Criterio

Un paquete entra en la instalación por defecto solo si cumple las tres cosas:

1. La función existe ya en el centro de control, no inventa una vista nueva.
2. Sin el paquete la opción queda claramente desactivada; con él funciona sin
   configuración manual.
3. El coste en disco y en servicios en segundo plano es pequeño, o el paquete
   es la única forma razonable de hacerlo.

Lo demás se ofrece como dependencia opcional y se explica en la ficha, sin
romper el arranque ni mostrar errores raros.

## Resumen por opción

| Opción | Estado actual | Qué falta | Paquete o solución | Prioridad |
| --- | --- | --- | --- | --- |
| Teclado en pantalla | `wvkbd` instalado. Capas `full`, `cyrillic`, `simple`, `nav` y `emoji`. | Español, alemán y portugués no tienen capa nativa; el chino necesita IME, no solo teclas. | Capas propias de `wvkbd` o cambiar a `squeekboard` (1.43) para es/de/pt. Chino: `fcitx5` + `fcitx5-chinese-addons`. | Alta |
| Portapapeles | Delegado en `cliphist`: guarda texto, listas de archivos e imágenes y deduplica el historial. | Nada para lo pedido; funciones extra (abrir archivo, pegar como archivo) serían otro paso. | `cliphist` ya incluido en la instalación. | Hecho |
| Discos extraíbles | `udisks2` ya activo; el instalador añade `udiskie` y su servicio de usuario. | Detección de adaptadores USB problemáticos. | `udiskie` ya incluido. | Hecho |
| Brillo | `ddcutil` para monitores externos, panel interno por `brightnessctl`/sysfs y filtro nativo como respaldo. | Nada; el panel interno necesita la regla de sudo que instala el instalador. | `brightnessctl` ya incluido en la instalación. | Hecho |
| Luz nocturna y atenuación extra | Ya son nativas: Umbriel aplica `[display]` como shader de salida. | Nada. | Ninguno. | Hecho |
| VPN | OpenVPN instalado (`network-manager-openvpn`). | WireGuard, OpenConnect, StrongSwan, PPTP y VPNC no aparecen si su plugin no está. | `network-manager-openconnect`, `network-manager-strongswan`, `network-manager-vpnc`, `network-manager-pptp` y `wireguard-tools`. | Media |
| Audio Bluetooth | `bluez`, `bluez-obexd` y `libspa-0.2-bluetooth` instalados. | Códecs propietarios (aptX/LDAC) dependen de la versión de PipeWire y del firmware del auricular. | No hace falta paquete para SBC/AAC; valorar `libfreeaptx0`/`libldacbt-abr2` solo si el equipo lo pide. | Baja |
| Música | MPRIS nativo de Quickshell. | Nada; no necesita `playerctl` si la app publica MPRIS. | Ninguno. | Hecho |
| Batería y perfiles | `upower` y `power-profiles-daemon` instalados. | Nada. | Ninguno. | Hecho |
| Clima | `curl` y `wttr.in` sin clave. | Nada. | Ninguno. | Hecho |
| QR del punto de acceso | `qrencode` instalado por `network.sh`. | Nada. | Ninguno. | Hecho |
| Sonido de avisos | `libnotify-bin` y el reproductor del sistema. | Depende del tema de sonido instalado; no es un fallo si no hay ninguno. | Opcional: un tema de sonidos (`sound-theme-freedesktop`). | Baja |
| Capturas o grabación | No hay una opción en el centro de control. | Si se añade, `grim`, `slurp` y `wf-recorder`. | Solo al crear esa función. | Futuro |

## Plan por fases

### Fase 1 · Lo que más se nota

1. **Teclado en pantalla para es/de/pt.**
   - Probar `squeekboard` en una sesión anidada: tiene distribución española,
     alemana y portuguesa y habla el mismo protocolo de teclado virtual.
   - Si encaja, añadirlo a `RUNTIME_PKGS` y dejar `wvkbd` como respaldo.
   - Si no, escribir capas de `wvkbd` para acentos y `ñ/ç/ã/õ` sin cambiar de
     programa; pesa menos y no añade otro daemon.
   - El chino no se resuelve con una capa: hace falta un IME. Se estudia aparte
     con `fcitx5` y `fcitx5-chinese-addons`, y solo si Umbriel expone el
     protocolo `zwp_input_method_manager_v2` de forma estable.

2. **Portapapeles con imágenes. Hecho con cliphist.**
   - `shell-clipboard-watch` mantiene `wl-paste --watch cliphist store`; la
     vista lee `cliphist list` y pega con `cliphist decode`.
   - Borrar y limpiar usan `cliphist delete` y `cliphist wipe`.
   - Queda como mejora futura abrir el archivo o pegarlo como archivo.

3. **Brillo de portátiles. Hecho.**
   - Orden de intentos: `ddcutil` → `brightnessctl`/sysfs → filtro nativo.
   - El instalador añade `brightnessctl` y lo autoriza en la misma regla de
     sudo que `ddcutil`; si el permiso falla, el filtro nativo recupera el
     control sin bloquear el deslizador.
   - No cambia la interfaz: el mismo deslizador y el mismo OSD.

### Fase 2 · Red y VPN

4. **Más tipos de VPN.**
   - Detectar qué plugins están instalados y mostrar solo los tipos que
     `nmcli` puede importar.
   - Añadir los plugins de OpenConnect, StrongSwan, VPNC y PPTP como
     opcionales; WireGuard primero, porque NetworkManager lo soporta de forma
     nativa con `wireguard-tools`.
   - La vista VPN ya lista perfiles; el trabajo es de detección y mensajes,
     no de una vista nueva.

### Fase 3 · Extensiones

5. **Códecs Bluetooth.** Solo si aparece un auricular que negocia mal: instalar
   el paquete de códec que corresponda y documentar que la calidad final la
   decide el auricular.
6. **Sonidos de notificación.** Incluir un tema de sonidos si el sistema no
   trae ninguno; el selector ya soporta archivo y nombre.
7. **Capturas.** Si se añade una opción, instalar `grim`, `slurp` y
   `wf-recorder` en ese momento, no en la instalación base.

## Integración con el aviso de dependencias

- `scripts/check-deps.sh` seguirá devolviendo solo lo que **rompe** una función
  existente. Las dependencias opcionales irán en una segunda sección
  `opcional|...` y el icono junto a «No molestar» mostrará un aviso suave, no
  un error.
- Cada línea seguirá llevando un comando copiable. Para las opcionales, el
  comando será el `apt install` exacto y el texto explicará qué mejora.
- La ficha de cada opción mostrará «Requiere X» solo cuando la opción esté
  visible y el paquete falte; nunca bloqueará el resto del centro de control.

## Qué no se propone

- `playerctl`: Quickshell ya habla MPRIS.
- `onboard`: es X11 y no encaja con la sesión Wayland.
- Un IME completo para chino dentro del propio shell: es un proyecto aparte,
  con su daemon y su integración de foco; no debe mezclarse con el teclado
  flotante.
- Instalar códecs Bluetooth «por si acaso»: pueden aumentar el tamaño y no
  todos los auriculares los usan.

## Pruebas de aceptación

1. Sin paquetes opcionales, el centro de control abre y las opciones afectadas
   se ven desactivadas con un texto claro.
2. Con cada paquete instalado, la opción funciona sin reiniciar la sesión
   (o se indica que hace falta reiniciar).
3. El aviso de dependencias no muestra entradas opcionales como errores.
4. Teclado: escribir `ñ`, `á`, `ä`, `ç` y `ã` en una ventana de texto.
5. Portapapeles: copiar una imagen, verla en el historial y volver a pegarla.
6. Brillo: mover el deslizador en un portátil y en un monitor externo.
7. VPN: importar y conectar un perfil de cada tipo instalado.

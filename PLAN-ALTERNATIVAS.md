# Plan · Funciones del shell que podrían delegarse

El shell debe quedarse con lo que aporta integración real: barra, paneles,
cristal, atajos de Super, modos de escritorio y acciones de ventana. Todo lo
demás que ya existe fuera debería usarse antes de escribir otra implementación.

## Ya está delegado

| Función | Herramienta que ya se usa |
| --- | --- |
| Red, Wi-Fi, Ethernet y VPN | NetworkManager (`nmcli`) y sus plugins |
| Bluetooth y audio Bluetooth | `bluez`, PipeWire y WirePlumber |
| Volumen, micrófono y dispositivos | PipeWire a través de Quickshell |
| Reproducción | MPRIS del propio reproductor |
| Brillo externo | `ddcutil` |
| Brillo del panel interno | `brightnessctl` y `/sys/backlight` |
| Inactividad y bloqueo por tiempo | `swayidle` |
| Bloqueo de pantalla | `hyprlock`, con `shell-lock` como única entrada |
| Portapapeles | `cliphist` + `wl-paste`/`wl-copy` |
| Clima | `wttr.in` por HTTP |
| QR del punto de acceso | `qrencode` |
| Batería y perfiles | UPower y `power-profiles-daemon` |
| Atajos globales y reglas de ventana | Umbriel nativo |

## Candidatos razonables a delegar

| Función actual | Alternativa en Debian 13 | Qué se gana | Qué se pierde | Recomendación |
| --- | --- | --- | --- | --- |
| Lanzador de aplicaciones (`Launcher.qml`) | `fuzzel`, `wofi` o `rofi` | Búsqueda, iconos, historial y accesibilidad ya probados. | El gesto de un toque de Super, el cierre con el segundo toque y el estilo de cristal del shell. | Probar `fuzzel` solo como modo alternativo; no sustituir el actual. |
| Notificaciones emergentes (`NotificationPopup.qml`) | `mako-notifier`, `dunst` | Daemon maduro, reglas, historial y acciones. | Integración con «No molestar», panel lateral, tarjetas y sonido del shell. | Mantener; evaluar solo un modo «usar daemon externo». |
| OSD (`Osd.qml`) | `swayosd` | OSD estándar para volumen, brillo y teclas multimedia. | Aspecto unificado, sliders y estado del shell. | Mantener; el OSD actual es pequeño. |
| Barra (`Bar.qml`) | `waybar` | Módulos ya hechos, configuración declarativa. | Fichas de escritorio, botón de modo, orden estable y cristal propio. | No delegar: la barra es la identidad del shell. |
| Centro de control y paneles | `blueman`, `pavucontrol`, `network-manager-gnome` | Interfaces completas para ajustes avanzados. | Todo el diseño y los accesos rápidos integrados. | Ofrecer «abrir herramienta externa» para casos raros, no reemplazar. |
| Calendario y notas (`CalendarPanel.qml`, `shell-calendar`) | `khal`, `calcurse` | Sincronización iCal, repetición y edición más completa. | Panel del reloj, notas locales y estilo. | Mantener notas locales; evaluar `khal` solo como fuente iCal opcional. |
| Alarmas y temporizador | `systemd` timers, `at`, apps de reloj | Persistencia y notificaciones estándar. | Sonido en bucle, entrada de dígitos y parpadeo del reloj. | Mantener: la integración con el reloj es el valor. |
| Monitor de CPU/GPU/red | `btop`, `nvtop`, `nload` | Mucho más detalle y gráficas. | Vista compacta dentro del centro de control. | Mantener la vista rápida; añadir botón «abrir btop/nvtop». |
| Fondo de pantalla | `swaybg` | Demonio estándar para imágenes. | Color de fondo, integración con cristal y cambio desde Temas. | Mantener el actual o usar `swaybg` solo para imágenes. |
| Lector de capturas | `grim` + `slurp` + `swappy` | Herramientas estándar y bien mantenidas. | Nada, si se añade como acción nueva. | Si se añade captura, usar esas herramientas. |
| Selector de color | `hyprpicker` o `grim` + `magick` | Utilidad ya hecha. | Nada. | Solo si se añade la función. |
| Menú de sesión | `wlogout` | Apagar, reiniciar y cerrar sesión sin código propio. | Estilo del shell. | Mantener el menú actual; `wlogout` como respaldo. |

## Lo que no conviene delegar

- **Gestión de ventanas y escritorios.** Los modos mosaico/ventana, el
  redimensionado por divisores, el foco con Super y la restauración de
  geometría dependen de Umbriel y del contrato del shell.
- **Cristal, desenfoque y temas.** La integración entre barra, paneles,
  ventanas y `config.toml` es específica de este proyecto.
- **Fichas de escritorio y barra.** Un `waybar` externo no conoce el estado de
  las ventanas, el modo por escritorio ni el botón que alterna el modo.
- **Calendario local con notas.** Moverlo a `khal` obligaría a convertir el
  formato y perdería la edición en el propio panel.

## Orden sugerido

1. **Hecho:** portapapeles con `cliphist` y brillo interno con
   `brightnessctl`.
2. **Siguiente candidato barato:** botones «abrir herramienta externa» para
   Bluetooth (`blueman`), audio (`pavucontrol`) y red
   (`nm-connection-editor`), sin reemplazar los paneles.
3. **Después:** probar `fuzzel` como lanzador alternativo y `swaybg` para
   fondos, siempre detrás de un ajuste, no como cambio por defecto.
4. **No hacer:** reescribir notificaciones, barra o centro de control sobre
   otro proyecto; se perdería la integración que justifica el shell.

## Criterio para aceptar una alternativa

Una alternativa entra solo si:

- Ya está empaquetada en Debian 13 y se instala sin compilar.
- Sustituye una función completa, no añade un daemon que duplique al actual.
- El shell puede seguir mostrando su estado y sus atajos.
- Si falta el paquete, la opción se desactiva con un texto claro.

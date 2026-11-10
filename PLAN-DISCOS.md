# Plan · Montar los discos al iniciar

Objetivo: que los discos internos y las unidades extraíbles aparezcan montados
sin tener que abrirlos a mano, con un comportamiento parecido al de Windows.
Todavía no se ha cambiado nada: este documento es el plan.

## Situación de este equipo

Hay dos discos NTFS internos además del disco del sistema:

| Disco | Tipo | Estado actual |
| --- | --- | --- |
| SSD S700 500 GB | ext4 + EFI + swap | Sistema, ya montado |
| KINGSTON SA400S37960G, etiqueta `SSD1T` | NTFS | Sin montar |
| WDC WD10EZEX, etiqueta `New Volume` | NTFS | Sin montar |

`udisks2` ya está instalado y activo. `ntfs-3g` y `exfatprogs` también están
instalados. No hay ningún servicio que los monte solos al iniciar sesión.

`install.sh` ya ejecuta `scripts/mount-disks.sh --apply` al final. En una
instalación limpia deja los NTFS internos en `/etc/fstab` y no vuelven a pedir
contraseña al arrancar. Las unidades USB las monta `udiskie`.

## Decisión de diseño

Separar dos casos:

1. **Discos internos fijos** → `/etc/fstab` con UUID y `nofail`.
   Se montan al arrancar y no dependen de que el shell esté abierto.
2. **Unidades extraíbles (USB, tarjetas)** → `udisks2` + `udiskie`.
   Se montan al conectarlas y al iniciar sesión, como hace Windows.

No conviene usar `udiskie` para los discos internos: si el disco falta o está
sucio, un daemon de usuario puede reintentar y mostrar errores. `fstab` es más
predecible y permite arrancar aunque un disco no esté.

## Fase 1 · Discos internos NTFS

1. **Comprobar el estado de NTFS.**
   - Si los discos se comparten con Windows, desactivar Inicio rápido e
     hibernación en Windows. Un NTFS hibernado se monta en solo lectura o
     puede corromperse.
   - Si tienen BitLocker, desbloquearlos antes; Linux no lo abre sin
     herramientas extra.
   - Ejecutar `sudo ntfsfix -n /dev/sdX1` solo como diagnóstico, nunca para
     “arreglar” a ciegas.

2. **Elegir puntos de montaje.**
   - `/mnt/SSD1T`
   - `/mnt/NewVolume` (o `/mnt/WD10EZEX`)
   - Crear con `sudo mkdir -p` y dejar el propietario en el usuario.

3. **Añadir entradas a `/etc/fstab`.**
   - Usar `UUID=` de `lsblk -f`, nunca `/dev/sdX`, que cambia de orden.
   - Opciones recomendadas con el kernel `ntfs3`:
     `defaults,nofail,uid=1000,gid=1000,umask=022`.
   - **No añadir `windows_names`**: prohíbe `:` en nombres nuevos y Proton
     necesita crear `dosdevices/c:` en cada prefijo. Solo tiene sentido si el
     disco se usa también desde Windows y no hay prefijos de Proton.
   - Si `ntfs3` no monta bien, usar `ntfs-3g` con las mismas opciones de
     permisos.
   - `nofail` evita que el arranque se quede esperando un disco ausente.
   - `x-systemd.device-timeout=5s` acorta la espera si el disco falla.

4. **Probar sin reiniciar.**
   - `sudo systemctl daemon-reload`
   - `sudo mount -a`
   - `findmnt /mnt/SSD1T /mnt/NewVolume`
   - Escribir y borrar un archivo de prueba en cada uno.
   - Reiniciar y repetir.
   - Si al apagar el equipo se queda encendido con la pantalla apagada, usar
     `sudo ./scripts/mount-disks.sh --apply --lazy-unmount`: añade
     `LazyUnmount=yes` a las unidades para que systemd no espere al desmontar.

5. **Reversión.**
   - Guardar copia de `/etc/fstab` antes de tocarlo.
   - Para deshacer: quitar las líneas nuevas, `sudo systemctl daemon-reload`
     y `sudo umount /mnt/...`.

## Fase 2 · Unidades extraíbles

1. Instalar `udiskie` (disponible en Debian 13).
2. Crear un servicio de usuario:
   - `udiskie --automount --notify`
   - Sin bandeja: el shell no necesita un icono extra.
3. Comprobar:
   - Conectar un USB y ver que aparece en `/media/$USER/...`.
   - Desconectarlo con `udisksctl unmount` y volver a conectarlo.
   - Que no se monte si está cifrado o si Windows lo dejó hibernado.

Alternativa sin daemon: el shell puede llamar a `udisksctl mount -b` cuando
detecte un dispositivo nuevo, pero eso obliga a vigilar eventos desde el shell.
`udiskie` ya hace ese trabajo y es más pequeño que añadirlo al código propio.

## Fase 3 · Integración con el shell (opcional)

Solo si hace falta después:

- Mostrar en la barra o en un panel qué discos están montados.
- Botón «Expulsar» para unidades extraíbles.
- Abrir la carpeta montada desde el icono del escritorio.

No es necesario para el objetivo inicial: con `fstab` y `udiskie` los discos
ya están disponibles en el gestor de archivos.

## Qué no se propone

- Montar todo con `autofs`: útil para red, innecesario para discos locales.
- Usar `ntfs-3g` para siempre si `ntfs3` funciona: el kernel es más rápido y
  no necesita FUSE.
- Montar los discos con `sudo` en un script al iniciar sesión: duplica lo que
  ya hacen `fstab` y `udisks2` y falla si la sesión se reinicia.
- Compartir el mismo NTFS con Windows y Linux a la vez: Windows debe estar
  apagado del todo, no hibernado.

## Pruebas de aceptación

1. Reiniciar sin los discos externos: el sistema arranca sin esperas.
2. Reiniciar con los dos NTFS internos: aparecen en `/mnt/...` y se puede
   leer y escribir.
3. Conectar un USB: se monta sin abrir una terminal.
4. Desconectar el USB sin datos abiertos: no deja el sistema bloqueado.
5. Arrancar Windows, apagarlo bien y volver a Linux: los NTFS se montan sin
   errores.
6. Quitar una entrada de `fstab`: el sistema sigue arrancando.

## SSD externo que no se reconoce

El caso del SSD externo con adaptador USB no es lo mismo que el automontaje:
si el equipo no lo ve, primero hay que saber en qué capa falla.

1. Conectar el disco y ejecutar:

   ```sh
   ./scripts/diagnose-usb-disk.sh
   sudo ./scripts/diagnose-usb-disk.sh
   ```

2. Interpretación rápida:

   | Síntoma | Causa probable | Siguiente paso |
   | --- | --- | --- |
   | No aparece en `lsusb` | Cable, puerto o alimentación | Probar otro cable/puerto USB 3 y un hub alimentado |
   | Aparece en `lsusb`, no en `lsblk` | Puente USB-SATA/NVMe, `uas` o `usb-storage` | Revisar el registro; probar quirk con el VID:PID |
   | Aparece en `lsblk` sin `FSTYPE` | Sin tabla de particiones, APFS, BitLocker, LVM o ZFS | No formatear; identificar el formato antes |
   | Aparece con NTFS/exFAT y no monta | Windows hibernado, BitLocker o error del sistema de archivos | `ntfsfix -n` solo como diagnóstico |
   | Funciona en otro equipo | Compatibilidad del adaptador | Probar `usb-storage.quirks=VID:PID:u` |

3. Cuando funcione como disco extraíble, `udiskie` lo montará solo. Si el
   adaptador es problemático pero el disco se ve, se puede añadir el quirk del
   kernel sin tocar el automontaje.

No se ha instalado nada para diagnosticar: los comandos son de solo lectura.

## Añadir o quitar discos concretos

El bloque de `fstab` se regenera entero, así que se puede cambiar la selección:

```sh
# Solo SSD1T
sudo ./scripts/mount-disks.sh --only SSD1T --apply

# Todos menos New Volume
sudo ./scripts/mount-disks.sh --exclude "New Volume" --apply

# Quitar todos los montajes gestionados
sudo ./scripts/mount-disks.sh --uninstall
```

Después de añadir un disco interno nuevo basta con volver a ejecutar
`--apply`; los que ya estaban se conservan y el nuevo se añade.

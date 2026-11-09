#!/usr/bin/env bash
# Diagnóstico de un disco externo que no aparece.
#
# Conéctalo y ejecuta:
#   ./scripts/diagnose-usb-disk.sh
#   sudo ./scripts/diagnose-usb-disk.sh   (incluye el registro del kernel)
#
# No monta, formatea ni modifica nada. Solo reúne información.
set -u

section() {
    printf '\n== %s ==\n' "$1"
}

section "Discos y particiones"
lsblk -o NAME,PATH,FSTYPE,LABEL,UUID,SIZE,TYPE,RM,TRAN,MOUNTPOINTS,MODEL 2>&1

section "Discos SCSI/USB vistos por el kernel"
lsblk -S -o NAME,HCTL,TRAN,VENDOR,MODEL,SERIAL,SIZE,STATE 2>&1

section "Dispositivos USB"
lsusb 2>&1
printf '\nÁrbol USB:\n'
lsusb -t 2>&1

section "udisks2"
if command -v udisksctl >/dev/null 2>&1; then
    udisksctl status 2>&1
else
    echo "udisksctl no está instalado."
fi

section "Módulos de almacenamiento USB"
lsmod 2>/dev/null | grep -E '^(uas|usb_storage|usbhid|sd_mod|nvme)' || true

section "Enlaces persistentes"
find /dev/disk/by-id -maxdepth 1 -type l -printf '%f -> %l\n' 2>/dev/null |
    sort | sed -n '1,80p'

section "Registro del kernel"
if dmesg >/dev/null 2>&1; then
    dmesg | grep -iE 'usb|scsi|uas|sd [a-z]|error|reset|over-current' | tail -80
elif command -v journalctl >/dev/null 2>&1; then
    journalctl -k -b --no-pager 2>/dev/null |
        grep -iE 'usb|scsi|uas|sd [a-z]|error|reset|over-current' | tail -80 ||
        echo "Sin permiso para leer el registro; prueba con sudo."
else
    echo "Sin acceso al registro; prueba con sudo."
fi

cat <<'EOF'

== Cómo interpretarlo ==

1. No aparece una línea nueva en `lsusb` al conectarlo:
   - Prueba otro cable y otro puerto, preferiblemente USB 3.
   - Algunos adaptadores necesitan alimentación externa.
   - Descarta un hub sin alimentación.

2. Aparece en `lsusb` pero no en `lsblk`:
   - Suele ser el puente USB-SATA/NVMe. Busca errores `uas` o `usb-storage`.
   - Con el VID:PID de `lsusb` se puede añadir un quirk del kernel.
   - También puede ser una unidad sin tablas de particiones o con un formato
     que Linux no entiende.

3. Aparece en `lsblk` pero `FSTYPE` está vacío:
   - No hay tabla de particiones o el formato no es reconocido.
   - No formatear sin copia de seguridad: puede ser APFS, BitLocker, LVM,
     ZFS o un disco de instalación.

4. Aparece con NTFS/exFAT pero no se monta:
   - NTFS: comprobar que Windows no lo dejó hibernado.
   - BitLocker: Linux no lo abre sin herramientas específicas.
   - Ejecutar `sudo ntfsfix -n /dev/sdX1` solo como diagnóstico.

5. El adaptador funciona en otro equipo pero no aquí:
   - Probar `usb-storage.quirks=VID:PID:u` en el arranque, después de
     identificar el puente con `lsusb`.
   - No añadir quirks genéricos: pueden romper otros dispositivos.
EOF

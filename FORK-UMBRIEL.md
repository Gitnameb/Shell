# Fork real de Umbriel

El shell usa un Umbriel parcheado. Mantenerlo como parche sobre un commit del
repositorio original funciona, pero cualquier `apt upgrade` o instalación del
paquete oficial puede sustituir `/usr/bin/umbriel` y dejar la sesión a medias.

La solución definitiva tiene dos partes:

1. Un repositorio propio en GitHub con la rama del fork.
2. Una diversión de `dpkg` para que el paquete oficial no pueda pisar el
   binario compilado.

## Estado local

En `~/umbriel-fork` ya existe la rama `shell-fork` con los cambios del shell
commiteados. El remoto `origin` sigue apuntando al Umbriel original y hay un
remoto `fork` preparado:

```text
origin  https://github.com/noctalia-dev/umbriel.git
fork    git@github.com:Gitnameb/umbriel.git
```

Todavía no se ha subido nada: el repositorio de GitHub debe existir primero.

## Crear el fork en GitHub

1. Entra en `https://github.com/noctalia-dev/umbriel`.
2. Pulsa **Fork** y crea el repositorio en tu cuenta, por ejemplo
   `Gitnameb/umbriel`.
3. Si el nombre es distinto, cambia la URL del remoto:

   ```sh
   cd ~/umbriel-fork
   git remote set-url fork git@github.com:Gitnameb/TU-REPO.git
   ```

4. Sube la rama del fork:

   ```sh
   git push -u fork shell-fork
   ```

A partir de ahí el código vive en tu cuenta. No hace falta volver a aplicar
`umbriel-fork.patch` para instalar.

## Instalar desde el fork

```sh
cd ~/Shell
./scripts/install-umbriel-fork.sh \
  --fork-repo git@github.com:Gitnameb/umbriel.git \
  --fork-branch shell-fork \
  --yes
```

También se puede dejar fijo con variables de entorno:

```sh
export UMBRIEL_FORK_REPO=git@github.com:Gitnameb/umbriel.git
export UMBRIEL_FORK_BRANCH=shell-fork
```

## Protección contra apt

El instalador aparta el binario del paquete con `dpkg-divert`:

```text
/usr/bin/umbriel          → fork compilado
/usr/bin/umbriel.distrib  → binario del paquete oficial
```

Así, un `apt upgrade` del paquete `umbriel` escribe en
`/usr/bin/umbriel.distrib` y no toca el fork. `install-packages.sh` puede
seguir instalando o actualizando el paquete oficial sin romper la sesión.

Si alguna vez quieres volver al Umbriel oficial:

```sh
sudo dpkg-divert --local --rename --remove /usr/bin/umbriel
```

Después reinstala el paquete:

```sh
sudo apt install --reinstall umbriel
```

## Actualizar el fork

No hay actualización automática desde el original. Cuando quieras traer
cambios de Noctalia:

```sh
cd ~/umbriel-fork
git fetch origin
git merge origin/main        # o el commit que quieras
# resolver conflictos, compilar y probar
git push fork shell-fork
```

Eso convierte la actualización en una decisión explícita, no en algo que un
`apt upgrade` pueda hacer por sorpresa.

## Si no se crea el fork todavía

El instalador sigue funcionando con el árbol local `~/umbriel-fork`, que ya
tiene la rama `shell-fork` commiteada. La diversión de `dpkg` también protege
el binario. El fork en GitHub sirve para conservar el historial y poder
reinstalar desde cualquier equipo, no para que la sesión actual funcione.

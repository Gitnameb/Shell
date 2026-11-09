# Umbriel · edit personal

Este proyecto usa un **edit personal de Umbriel**, no una versión oficial ni
una versión mejorada del proyecto original. Está hecho para mi escritorio
Debian con el shell de `~/Shell`.

Repositorio:

```text
https://github.com/Gitnameb/umbriel-edit
rama: main
```

No es un fork de GitHub. Es un repositorio independiente, con una historia
propia y sin relación de pull request con `noctalia-dev/umbriel`.

## Qué significa «edit personal»

- Los cambios están pensados para mi forma de usar el escritorio.
- No hay compromiso de compatibilidad con el Umbriel oficial.
- No hay soporte ni garantías.
- Si alguien quiere usarlo, puede hacerlo, pero debe revisar los cambios y
  asumir el riesgo. El proyecto original sigue siendo la referencia.
- Se conserva la licencia MIT y la atribución original.

## Estado

En `~/umbriel-fork` hay dos ramas locales:

| Rama | Contenido |
| --- | --- |
| `shell-fork` | Historial completo con los cambios del edit. Solo local. |
| `standalone` | Un commit independiente, sin ancestros del Umbriel original. |

La rama `standalone` ya está publicada en `Gitnameb/umbriel-edit` como `main`.
Los remotos locales son:

```text
upstream    → noctalia-dev/umbriel
standalone  → Gitnameb/umbriel-edit
```

No hay un remoto `origin` apuntando al proyecto original.

## Instalar

El instalador usa el edit por defecto:

```sh
cd ~/Shell
./scripts/install-umbriel-fork.sh --yes
```

Valores por defecto:

```text
https://github.com/Gitnameb/umbriel-edit.git
rama: main
```

También se puede forzar:

```sh
./scripts/install-umbriel-fork.sh \
  --fork-repo https://github.com/Gitnameb/umbriel-edit.git \
  --fork-branch main \
  --yes
```

Si el clon falla, el instalador cae al modo antiguo: Umbriel original más el
parche local.

## Publicar desde cero

Si algún día hay que recrear el repositorio:

1. Crear un repositorio **vacío** en GitHub llamado `umbriel-edit`. No usar el
   botón Fork.
2. Subir la rama independiente:

   ```sh
   cd ~/umbriel-fork
   git push -u standalone standalone:main
   ```

Eso crea una `main` con un solo commit, sin relación de fork.

## Protección contra apt

El instalador aparta el binario oficial con `dpkg-divert`:

```text
/usr/bin/umbriel          → edit personal
/usr/bin/umbriel.distrib  → binario del paquete oficial
```

Así, `apt upgrade` e `install-packages.sh` pueden actualizar el paquete sin
sustituir el binario compilado.

Para volver al oficial:

```sh
sudo dpkg-divert --local --rename --remove /usr/bin/umbriel
sudo apt install --reinstall umbriel
```

## Traer cambios del original

Al ser independiente no hay `git merge` automático. Si quieres un cambio de
Noctalia:

```sh
cd ~/umbriel-fork
git fetch upstream
git cherry-pick <commit>
# resolver conflictos, compilar y probar
git push standalone HEAD:main
```

Es una decisión manual. Es el precio de no ser un fork.

## Comprobación de PR

No hay pull requests ni issues de `Gitnameb` en el Umbriel original. Borrar el
fork anterior fue suficiente. Se puede comprobar en:

- `https://github.com/noctalia-dev/umbriel/pulls?q=is%3Apr+author%3AGitnameb`
- `https://github.com/noctalia-dev/umbriel/issues?q=is%3Aissue+author%3AGitnameb`

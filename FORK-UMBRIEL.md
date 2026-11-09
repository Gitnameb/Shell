# Umbriel independiente

El shell usa un Umbriel propio. No conviene mantenerlo como fork del
repositorio original: un `apt upgrade` puede pisar el binario y un fork puede
acabar relacionado con el proyecto original sin querer.

La solución es un **repositorio nuevo y vacío**, sin botón «Fork», con una
historia independiente.

## Estado actual

En `~/umbriel-fork` hay dos ramas locales:

| Rama | Contenido |
| --- | --- |
| `shell-fork` | Historial completo con el parche del shell. |
| `standalone` | Un único commit con el árbol actual, sin ancestros del Umbriel original. |

La rama `standalone` ya está preparada. El remoto `standalone` apunta a:

```text
git@github.com:Gitnameb/umbriel-shell.git
```

Todavía no se ha subido nada: el repositorio de GitHub debe existir primero.

## Crear el repositorio independiente

1. En GitHub, pulsa **New repository**.
2. Nombre: `umbriel-shell`.
3. **No** pulses Fork. Déjalo vacío: sin README, sin licencia, sin `.gitignore`.
4. Si usas otro nombre, cambia la URL:

   ```sh
   cd ~/umbriel-fork
   git remote set-url standalone git@github.com:Gitnameb/TU-REPO.git
   ```

## Subir el código

```sh
cd ~/umbriel-fork
git push -u standalone standalone:main
```

Eso crea una rama `main` con **un solo commit**, sin relación de fork con
`noctalia-dev/umbriel`. No aparecerá como «forked from» ni permitirá abrir una
pull request contra el original desde este repositorio.

Conserva `LICENSE` y la atribución del proyecto original; el historial
independiente no elimina la licencia.

## Instalar desde el repositorio independiente

El instalador ya usa ese repositorio por defecto:

```sh
cd ~/Shell
./scripts/install-umbriel-fork.sh --yes
```

Valores por defecto:

```text
https://github.com/Gitnameb/umbriel-shell.git
rama: main
```

Si usas otro nombre o rama:

```sh
./scripts/install-umbriel-fork.sh \
  --fork-repo https://github.com/Gitnameb/TU-REPO.git \
  --fork-branch main \
  --yes
```

Si el clon falla, el instalador cae al modo antiguo: Umbriel original + parche.

## Protección contra apt

El instalador aparta el binario oficial con `dpkg-divert`:

```text
/usr/bin/umbriel          → Umbriel propio
/usr/bin/umbriel.distrib  → binario del paquete oficial
```

Así, `apt upgrade` e `install-packages.sh` pueden actualizar el paquete sin
sustituir el binario compilado. Si quieres volver al oficial:

```sh
sudo dpkg-divert --local --rename --remove /usr/bin/umbriel
sudo apt install --reinstall umbriel
```

## Actualizar desde el original

Al no compartir historia, no hay `git merge` automático. Si algún día quieres
traer un cambio de Noctalia:

```sh
cd ~/umbriel-fork
git fetch upstream   # el remoto original ya se llama upstream
git cherry-pick <commit>
# resolver conflictos, compilar y probar
git push standalone HEAD:main
```

Eso convierte la actualización en una decisión manual. Es el precio de que el
repositorio sea independiente.

## Comprobar que no hay PR abierta

La cuenta `Gitnameb` no tiene pull requests ni issues abiertos en
`noctalia-dev/umbriel` según la búsqueda pública. Si quieres confirmarlo:

- `https://github.com/noctalia-dev/umbriel/pulls?q=is%3Apr+author%3AGitnameb`
- `https://github.com/noctalia-dev/umbriel/issues?q=is%3Aissue+author%3AGitnameb`

Borrar el fork fue suficiente.

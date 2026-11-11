# Patches

A patch raises a dependency of cloudflared with a known vulnerability in the image, before Cloudflare releases an update.

## Rules

- Go, Alpine and the CA bundle need no patch. Bump their pins in `src/Dockerfile` and release a patch version of the image
- Patch a dependency of cloudflared only for a known vulnerability, once the version that fixes it is released
- Drop a dependency from the patch once a cloudflared release requires the fixed version
- Never patch the code of cloudflared, its fixes come with its releases

## Package managers

Every package manager runs in the image of its `ARG` in `src/Dockerfile`, nothing is installed locally. pnpm and Yarn run in the version that `packageManager` in `package.json` names.

| Lockfile                                   | Package manager  | `ARG` in `src/Dockerfile` |
| ------------------------------------------ | ---------------- | ------------------------- |
| `go.mod`                                   | Go               | `GO_IMAGE`                |
| `Cargo.lock`                               | Cargo            | `RUST_IMAGE`              |
| `composer.lock`                            | Composer         | `COMPOSER_IMAGE`          |
| `package-lock.json`                        | npm              | `NODE_IMAGE`              |
| `pnpm-lock.yaml`                           | pnpm 10 or later | `NODE_IMAGE`              |
| `yarn.lock`                                | Yarn             | `NODE_IMAGE`              |
| `bun.lock`                                 | Bun              | `BUN_IMAGE`               |
| `aube-lock.yaml`                           | aube             | `AUBE_IMAGE`              |

## Add a patch

1. Raise the dependency to the version that fixes it, several at once if needed:

   ```sh
   scripts/patch-dependencies.sh github.com/go-chi/chi/v5@v5.4.0
   ```

2. Build the image and test it:

   ```sh
   scripts/build.sh && scripts/test.sh peakimages/cloudflared:local
   ```

3. Commit `src/patches/dependencies.patch` and release a patch version of the image

## Update cloudflared with a patch

The build workflow runs `scripts/patch-dependencies.sh --check` before it builds. It fails when the pinned cloudflared requires a raised dependency itself, or when the patch no longer applies. On the branch of the pull request that bumps cloudflared, manually write the patch again for the new release. It drops every dependency the release raises itself, and the whole file once none is left:

```sh
scripts/patch-dependencies.sh
```

> [!IMPORTANT]
> A patch that no longer applies stops the build.

## Remove a patch

Drop one dependency:

```sh
scripts/patch-dependencies.sh --remove github.com/go-chi/chi/v5
```

Drop all of them:

```sh
scripts/patch-dependencies.sh --remove
```

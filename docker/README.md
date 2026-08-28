# Minimal Dockerfiles with Nix

Addresses [ropensci/rix#218](https://github.com/ropensci/rix/issues/218):
*"Provide minimal Dockerfiles based on Alpine and Ubuntu with Nix through the
rstats-on-nix org"*.

Today, the `vignette("nix-inside-docker")` asks every user to write ~40 lines of
`Dockerfile` that install Nix, configure the `rstats-on-nix` cache, download a
bootstrap `default.nix` and build it — and to pay that cost on every
`docker build`. These images do that work once, so a user's `Dockerfile`
becomes:

```dockerfile
FROM ghcr.io/rstats-on-nix/rix-ubuntu:latest

COPY generate_env.R .
RUN rix-shell --run "Rscript generate_env.R"
RUN nix-build

CMD ["nix-shell"]
```

## What is here

| Path | Image | Contents |
| --- | --- | --- |
| `ubuntu/Dockerfile` (`--target nix`) | `nix-ubuntu` | Ubuntu 24.04 + Nix + the `rstats-on-nix` cache |
| `ubuntu/Dockerfile` (`--target rix`) | `rix-ubuntu` | the above + R, `{rix}` and `{rixpress}`, pre-realised |
| `alpine/Dockerfile` (`--target nix`) | `nix-alpine` | Alpine 3.22 + Nix + the `rstats-on-nix` cache |
| `alpine/Dockerfile` (`--target rix`) | `rix-alpine` | the above + R, `{rix}` and `{rixpress}`, pre-realised |
| `workflows/publish-images.yml` | — | CI that builds all four natively on amd64 and arm64, smoke-tests them and pushes them to `ghcr.io` |
| `test/smoke.R` | — | generates an environment with `{rix}`; CI runs it and then `nix-build`s the result in each `rix` image before pushing |

The `rix` variants ship a `rix-shell` helper: `rix-shell` drops you into the
R + `{rix}` environment, and `rix-shell --run "Rscript generate_env.R"` runs a
command in it.

## Building locally

```sh
docker build --target nix -t nix-ubuntu docker/ubuntu
docker build --target rix -t rix-ubuntu docker/ubuntu

docker build --target nix -t nix-alpine docker/alpine
docker build --target rix -t rix-alpine docker/alpine
```

Both `rix` variants take a `RIX_REF` build argument (a branch, tag or commit of
`ropensci/rix`) that selects which `inst/extdata/default.nix` is used to
bootstrap R and `{rix}`. That file pins nixpkgs and the package commits itself,
so pinning `RIX_REF` to a commit makes the image fully reproducible. It
defaults to `main` for local builds; CI resolves `main` to a commit once per run
and records it in the `org.opencontainers.image.revision.rix` label.

The pre-realised R + `{rix}` closure is registered as a GC root
(`/nix/var/nix/gcroots/rix`), so running `nix-collect-garbage` in a derived
image does not throw it away.

## How Nix is installed

Both images run the Determinate Systems installer, which is what the `{rix}`
documentation recommends everywhere else, with `--init none` (there is no init
system in a container) and `sandbox = false` (the build sandbox relies on user
namespaces, which are not always available inside a container).

Alpine is musl-based, but that turns out not to matter: everything Nix
installs lives in `/nix` and is linked against its own glibc. The installer
only needs `shadow` (for the `useradd`/`groupadd` it uses to create the `nixbld`
users, which busybox's applets do not cover) and `bash` (for `nix-shell`).

Copying `/nix` out of the official `nixos/nix` image is the other common way to
get Nix onto Alpine, and it was tried here first. It works, but the resulting
image is **1.03 GB** against **406 MB** for the installer, because that image
ships a nixpkgs channel and a fatter Nix closure. Trying to trim it with
`nix-collect-garbage` breaks the root profile mid-build. The installer is both
smaller and simpler.

## Measured sizes

Built on `linux/arm64`, on 2026-08-28:

| Image | Size |
| --- | --- |
| `nix-alpine` | 406 MB |
| `nix-ubuntu` | 532 MB |
| `rix-alpine` | 5.01 GB |
| `rix-ubuntu` | 5.55 GB (before the Nix cache cleanup, expect ~5.1 GB) |

The `rix` variants are dominated by R and its dependency closure, so the choice
of base barely registers there. Alpine is worth roughly 100 MB on the plain Nix
images.

## CI notes

The `rix` images are ~5.5 GB, so the workflow frees disk space on the runner
before building them and only caches the small `nix` stage in the GitHub
Actions cache (which is capped at 10 GB per repository). Each image is loaded
and smoke-tested locally before being pushed by digest; the `merge` job then
assembles the amd64 + arm64 manifests and tags them `latest` and with the
build date (not the rstats-on-nix snapshot date pinned inside the image).

## Where this should live

These belong in their own repository under the
[rstats-on-nix](https://github.com/rstats-on-nix) organisation, so that the
published images are `ghcr.io/rstats-on-nix/*` and are rebuilt independently of
`{rix}` releases. `workflows/publish-images.yml` is deliberately **not** under
`.github/workflows` here: dropping it into `{rix}`'s CI would publish images
from the `ropensci` org instead. Once the repository exists, move it to
`.github/workflows/publish-images.yml`, drop the `docker/` prefix from the
paths, and update `vignette("nix-inside-docker")` to `FROM` the published
images.

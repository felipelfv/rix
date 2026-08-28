# Minimal Alpine image with the Nix package manager, and an optional variant
# with R and {rix} baked in.
#
#   docker build --target nix -t nix-alpine docker/alpine
#   docker build --target rix -t rix-alpine docker/alpine
#
# Alpine is musl-based, but that does not matter here: everything Nix installs
# lives in /nix and is linked against its own glibc.
#
# See docker/README.md for details.

########################################
# Stage 1: Alpine + Nix
########################################
FROM alpine:3.22 AS nix

# `sandbox = false` is needed because the build sandbox relies on user
# namespaces, which are not always available inside a container, and
# `--init none` because there is no init system to register the daemon with.
# The rstats-on-nix cache is configured here so that R packages are downloaded
# as binaries instead of being compiled from source. Extra nix.conf lines can
# be passed through NIX_EXTRA_CONF.
ARG NIX_EXTRA_CONF=""

# `shadow` provides the useradd/groupadd the installer uses to create the
# nixbld users; busybox's applets are not enough. `bash` is needed by
# `nix-shell`.
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    shadow \
    xz

RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install linux \
    --extra-conf "sandbox = false" \
    --extra-conf "extra-substituters = https://rstats-on-nix.cachix.org" \
    --extra-conf "extra-trusted-public-keys = rstats-on-nix.cachix.org-1:vdiiVgocg6WeJrODIqdprZRUrhi1JzhBnXv7aWI6+F0=" \
    ${NIX_EXTRA_CONF:+--extra-conf "${NIX_EXTRA_CONF}"} \
    --init none \
    --no-confirm

ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"
# The installer expects `$USER` to be set, and {rix} defaults to the
# `nix-shell` user when it's absent
ENV USER=root
ENV user=root

WORKDIR /workspace

CMD ["bash"]

########################################
# Stage 2: + R and {rix}
########################################
FROM nix AS rix

# The `default.nix` shipped with {rix} provides R, {rix} and {rixpress}.
# It pins nixpkgs and the package commits itself, so pinning RIX_REF to a
# commit (as CI does) makes the image fully reproducible.
ARG RIX_REF=main

RUN curl -fsSL -o /rix.nix \
  "https://raw.githubusercontent.com/ropensci/rix/${RIX_REF}/inst/extdata/default.nix"

# Realise the environment now so that containers start instantly instead of
# downloading R and {rix} on first use. `mkShell` itself cannot be built, so a
# `buildEnv` of its inputs is built instead and kept as a GC root, so that a
# downstream `nix-collect-garbage` does not throw R and {rix} away.
RUN nix-build --no-out-link -E 'with import /rix.nix; pkgs.buildEnv { name = "rix-env"; paths = shell.buildInputs; ignoreCollisions = true; }' \
  | xargs nix-store --add-root /nix/var/nix/gcroots/rix -r > /dev/null \
  && nix-shell /rix.nix --run 'Rscript -e "cat(as.character(packageVersion(\"rix\")), \"\n\")"' \
  && rm -rf /root/.cache/nix

# `rix-shell` drops you into that environment; `rix-shell --run "..."` runs a
# command in it, e.g. `docker run rix-alpine rix-shell --run "Rscript gen.R"`
RUN printf '#!/bin/sh\nexec nix-shell /rix.nix "$@"\n' > /usr/local/bin/rix-shell \
  && chmod 0755 /usr/local/bin/rix-shell

CMD ["rix-shell"]

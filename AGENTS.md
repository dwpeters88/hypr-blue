# AGENTS.md

## Cursor Cloud specific instructions

This repository is a **bootc/OSTree OS-image build project** (`hypr-blue` / `bazzite-hyprland-nix`).
The "product" is a custom immutable Linux desktop **OCI container image** (Fedora/Bazzite base +
the Hyprland Wayland compositor), which is then convertible to bootable ISOs and disk images.
There is **no web frontend, backend service, or database** — the deliverable is the OS image and its
build pipeline. Tooling is orchestrated with `just`; `podman`/`buildah` do the image builds.

### Important: the `main` branch is empty
All project files were removed by PR #32. The actual sources (`Containerfile`, `Justfile`,
`build-iso-local.sh`, kickstart/config, CI workflows, `README.md`) live on feature branches — the most
complete is `feat/bazzite-hyprland-nix-iso`. If you need to work on the build itself, check out or
diff against that branch; do not expect files on `main`.

### Toolchain
The startup update script installs the full toolchain via apt: `podman`, `buildah`, `skopeo`, `just`,
`shellcheck`, `shfmt`. Rootless `podman` works in this VM (fuse-overlayfs storage driver, netavark).
`/dev/kvm` is available for VM-based testing.

### Lint / format / build / run (with non-obvious caveats)
- **Lint:** `just lint` runs `shellcheck` over all `*.sh`; **format:** `just format` runs `shfmt --write`.
  Gotcha: the committed `Justfile` currently **fails to parse** (`just --list` errors with
  "Unknown start of token") because of a wrapped `jq` line in the `_rootful_load_image` recipe (~line 133),
  present on every branch. Until that is fixed, run the tools directly, e.g.
  `find . -iname '*.sh' -exec shellcheck {} ';'` and `... -exec shfmt -d {} ';'`.
- **Build image:** `just build` or `podman build --tag hypr-blue:latest .`. Gotcha: the real
  `Containerfile` uses a large `ghcr.io/ublue-os/bazzite-nvidia` base (multi-GB pulls) and installs a
  **multi-user Nix daemon**, which is known to fail during rootless container builds at the Nix step
  (see the repo's own `fix-nix-setup-errors-during-build` branches). A plain Fedora-bootc + Hyprland
  `podman build` works fine and is a good smoke test of the environment.
- **ISO / disk images:** `just build-iso` (and `build-qcow2`/`build-raw`) run **Bootc Image Builder** in a
  `--privileged` podman container and require `sudo`. Note `disk_config/disk.toml` (referenced by the
  qcow2/raw recipes) is missing from the repo; only `disk_config/iso.toml` exists.
- **Run a VM:** `just run-vm-iso` launches a `docker.io/qemux/qemu` container that exposes a browser VM
  console on **port 8006** (uses `/dev/kvm`).

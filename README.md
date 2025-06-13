# hypr-blue

hypr-blue is a bootable container image based on Fedora with the Hyprland desktop environment. The project produces OCI container images that can be converted into disk or ISO installations.

## Prerequisites
- [Podman](https://podman.io/) for container builds and running images
- [just](https://github.com/casey/just) to use the provided recipes
- Optionally the Bootc Image Builder utilities for creating disk or ISO images

## Building the container
Build the main container image with `just`:

```bash
just build
```

The same image can be built manually using Podman:

```bash
podman build --tag hypr-blue:latest .
```

## Building an ISO
An ISO can be generated locally with:

```bash
just build-iso
```

A helper script `build-iso-local.sh` is also provided for advanced usage.

## GitHub Workflows
Automated workflows live under [`.github/workflows`](.github/workflows/):
- `build.yml` builds and pushes the container image
- `build-iso.yml` builds and uploads an installable ISO
- `build-disk.yml` builds additional disk images

These workflows are triggered on commits or can be run manually via the GitHub interface.

## License
See [LICENSE](LICENSE) for license information.

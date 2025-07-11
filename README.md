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

A helper script `build-iso-local.sh` is also provided for more control over the local ISO build process.

### Using `build-iso-local.sh`

The `build-iso-local.sh` script allows for customized local builds of both the OCI container image and the final bootable ISO.

**Basic Usage:**

```bash
./build-iso-local.sh
```
This will:
1. Build the OCI container image (e.g., `hypr-blue:iso-build-local`) using default settings (typically `linux/amd64`, auto-detected CPU cores and memory).
2. Use the OCI image to generate a bootable ISO (e.g., `hypr-blue-42.iso`) using the default Fedora version (42), Kinoite variant, and the `config/hyper-blue.ks` kickstart file.

**Common Options:**

You can customize the build process using various command-line flags. Here are some of a common ones:

*   `--platform <platform>`: Set the target platform for the OCI image (e.g., `linux/arm64`).
*   `--cpus <num>`: Specify the number of CPU cores for the build.
*   `--memory <GB>`: Specify the memory in GB for the build.
*   `--image-name <name>`: Set the OCI image name.
*   `--image-tag <tag>`: Set the OCI image tag.
*   `--fedora-version <ver>`: Set the Fedora version for the ISO installer.
*   `--variant <variant>`: Set the installer variant (e.g., `Kinoite`, `Server`).
*   `--iso-name <name.iso>`: Specify the output ISO filename.
*   `--iso-output-dir <dir>`: Define the directory to save the generated ISO.
*   `--kickstart <path/to.ks>`: Specify a custom kickstart file.
*   `--skip-container-build`: Skip the OCI image build and use an existing image for ISO generation.
*   `--init-podman-machine`: Initialize a Podman machine if one isn't running (useful on macOS or Windows).
*   `--help`: Display all available options and their default values.

**Example with Options:**

Build for `linux/arm64`, use 8 CPUs, 16GB RAM, name the OCI image `my-hypr:custom`, and output the ISO as `my-hypr-os.iso` in a directory named `build_output`:

```bash
./build-iso-local.sh \
    --platform linux/arm64 \
    --cpus 8 \
    --memory 16 \
    --image-name my-hypr \
    --image-tag custom \
    --iso-name my-hypr-os.iso \
    --iso-output-dir build_output
```

**Skipping Container Build:**

If you have already built the OCI image (e.g., `hypr-blue:iso-build-local`) and only want to regenerate the ISO:

```bash
./build-iso-local.sh --skip-container-build --image-name hypr-blue --image-tag iso-build-local
```

**Environment Variables:**

All command-line options can also be set via environment variables. For example, to set the number of CPUs, you could use `CPUS=8 ./build-iso-local.sh`. Refer to the `--help` output or the script itself for the corresponding environment variable names.

**Dependencies for `build-iso-local.sh`:**
*   Podman (for OCI image building and running the ISO builder container).
*   The script will attempt to pull the ISO builder container image (default: `ghcr.io/jasonn3/build-container-installer:v1.2.2`) if not present locally.

## GitHub Workflows
Automated workflows live under [`.github/workflows`](.github/workflows/):
- `build.yml` builds and pushes the container image
- `build-iso.yml` builds and uploads an installable ISO
- `build-disk.yml` builds additional disk images

These workflows are triggered on commits or can be run manually via the GitHub interface.

## License
See [LICENSE](LICENSE) for license information.

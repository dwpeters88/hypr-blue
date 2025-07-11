#!/bin/bash
# Local container build script
set -euo pipefail

# Function to get available CPU cores
get_cpu_cores() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        nproc
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        sysctl -n hw.ncpu
    else
        echo "2" # Default to 2 cores if OS is not recognized
    fi
}

# Function to get available memory in GB
get_memory_gb() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        free -g | awk '/^Mem:/{print $2}'
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}'
    else
        echo "4" # Default to 4GB if OS is not recognized
    fi
}

# Default values
DEFAULT_PLATFORM="linux/amd64"
DEFAULT_CPUS=$(get_cpu_cores)
DEFAULT_MEMORY_GB=$(get_memory_gb)
DEFAULT_DISK_SIZE_GB="100" # Default disk size for Podman machine
DEFAULT_IMAGE_NAME="hypr-blue"
DEFAULT_IMAGE_TAG="iso-build-local"
DEFAULT_CONTAINERFILE="Containerfile"
DEFAULT_FEDORA_VERSION="42"
DEFAULT_VARIANT="Kinoite"
DEFAULT_ISO_OUTPUT_DIR="output" # Relative to script execution directory
DEFAULT_BUILDER_IMAGE="ghcr.io/jasonn3/build-container-installer:v1.2.2" # Using the version from workflow

# User-configurable variables (can be overridden by environment variables)
PLATFORM="${PLATFORM:-$DEFAULT_PLATFORM}"
CPUS="${CPUS:-$DEFAULT_CPUS}"
MEMORY_GB="${MEMORY_GB:-$DEFAULT_MEMORY_GB}"
DISK_SIZE_GB="${DISK_SIZE_GB:-$DEFAULT_DISK_SIZE_GB}" # For Podman machine
IMAGE_NAME="${IMAGE_NAME:-$DEFAULT_IMAGE_NAME}"
IMAGE_TAG="${IMAGE_TAG:-$DEFAULT_IMAGE_TAG}"
CONTAINERFILE="${CONTAINERFILE:-$DEFAULT_CONTAINERFILE}"
FEDORA_VERSION="${FEDORA_VERSION:-$DEFAULT_FEDORA_VERSION}"
VARIANT="${VARIANT:-$DEFAULT_VARIANT}"
ISO_NAME="${ISO_NAME:-${IMAGE_NAME}-${FEDORA_VERSION}.iso}"
ISO_OUTPUT_DIR="${ISO_OUTPUT_DIR:-$DEFAULT_ISO_OUTPUT_DIR}"
BUILDER_IMAGE="${BUILDER_IMAGE:-$DEFAULT_BUILDER_IMAGE}"
KICKSTART_PATH="${KICKSTART_PATH:-config/hyper-blue.ks}" # Default kickstart path

# ISO Builder specific options (mirroring GitHub action inputs)
# Defaulting to false as in the workflow, but making them configurable
ENABLE_CACHE_DNF="${ENABLE_CACHE_DNF:-false}"
ENABLE_CACHE_SKOPEO="${ENABLE_CACHE_SKOPEO:-false}"
ENABLE_FLATPAK_DEPS="${ENABLE_FLATPAK_DEPS:-false}"
# Values from the GitHub workflow
SECURE_BOOT_KEY_URL="${SECURE_BOOT_KEY_URL:-https://github.com/ublue-os/akmods/raw/main/certs/public_key.der}"
ENROLLMENT_PASSWORD="${ENROLLMENT_PASSWORD:-universalblue}"


# Script help message
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Container Build Options:"
    echo "  --platform <platform>   Target platform for container (default: $DEFAULT_PLATFORM)."
    echo "  --cpus <num_cpus>       Number of CPU cores to use (default: $DEFAULT_CPUS)."
    echo "  --memory <memory_gb>    Memory in GB to allocate (default: $DEFAULT_MEMORY_GB GB)."
    echo "  --disk-size <disk_gb>   Disk size for Podman machine (default: $DEFAULT_DISK_SIZE_GB GB)."
    echo "  --image-name <name>     Name for the built OCI image (default: $DEFAULT_IMAGE_NAME)."
    echo "  --image-tag <tag>       Tag for the built OCI image (default: $DEFAULT_IMAGE_TAG)."
    echo "  --containerfile <path>  Path to the Containerfile (default: $DEFAULT_CONTAINERFILE)."
    echo "  --init-podman-machine   Initialize Podman machine if not running (optional)."
    echo "  --skip-podman-check     Skip Podman installation and machine checks."
    echo ""
    echo "ISO Build Options:"
    echo "  --fedora-version <ver>  Fedora version for the installer (default: $DEFAULT_FEDORA_VERSION)."
    echo "  --variant <variant>     Installer variant (e.g., Kinoite, Server) (default: $DEFAULT_VARIANT)."
    echo "  --iso-name <name.iso>   Output ISO file name (default: ${IMAGE_NAME}-${FEDORA_VERSION}.iso)."
    echo "  --iso-output-dir <dir>  Directory to save the ISO (default: $DEFAULT_ISO_OUTPUT_DIR)."
    echo "  --builder-image <img_uri> ISO builder container image (default: $DEFAULT_BUILDER_IMAGE)."
    echo "  --kickstart <path>      Path to kickstart file (default: $KICKSTART_PATH)."
    echo "  --enable-cache-dnf      Enable DNF caching for ISO build (true/false, default: $ENABLE_CACHE_DNF)."
    echo "  --enable-cache-skopeo   Enable Skopeo caching for ISO build (true/false, default: $ENABLE_CACHE_SKOPEO)."
    echo "  --enable-flatpak-deps   Enable Flatpak dependency resolution (true/false, default: $ENABLE_FLATPAK_DEPS)."
    echo "  --secure-boot-key-url <url> URL for secure boot key (default: $SECURE_BOOT_KEY_URL)."
    echo "  --enrollment-password <pw> Password for secure boot enrollment (default: $ENROLLMENT_PASSWORD)."
    echo ""
    echo "Other Options:"
    echo "  -h, --help              Show this help message and exit."
    echo "  --skip-container-build  Skip OCI container build, proceed to ISO build (requires existing image)."
    echo ""
    echo "Environment variables can also be used to set these options (e.g., CPUS=8 $0)."
}

# Parse command-line arguments
INIT_PODMAN_MACHINE=false
SKIP_PODMAN_CHECK=false
SKIP_CONTAINER_BUILD=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        # Container options
        --platform) PLATFORM="$2"; shift ;;
        --cpus) CPUS="$2"; shift ;;
        --memory) MEMORY_GB="$2"; shift ;;
        --disk-size) DISK_SIZE_GB="$2"; shift ;;
        --image-name) IMAGE_NAME="$2"; shift ;;
        --image-tag) IMAGE_TAG="$2"; shift ;;
        --containerfile) CONTAINERFILE="$2"; shift ;;
        --init-podman-machine) INIT_PODMAN_MACHINE=true ;;
        --skip-podman-check) SKIP_PODMAN_CHECK=true ;;
        # ISO options
        --fedora-version) FEDORA_VERSION="$2"; shift ;;
        --variant) VARIANT="$2"; shift ;;
        --iso-name) ISO_NAME="$2"; shift ;;
        --iso-output-dir) ISO_OUTPUT_DIR="$2"; shift ;;
        --builder-image) BUILDER_IMAGE="$2"; shift ;;
        --kickstart) KICKSTART_PATH="$2"; shift ;;
        --enable-cache-dnf) ENABLE_CACHE_DNF="$2"; shift ;;
        --enable-cache-skopeo) ENABLE_CACHE_SKOPEO="$2"; shift ;;
        --enable-flatpak-deps) ENABLE_FLATPAK_DEPS="$2"; shift ;;
        --secure-boot-key-url) SECURE_BOOT_KEY_URL="$2"; shift ;;
        --enrollment-password) ENROLLMENT_PASSWORD="$2"; shift ;;
        # Other
        --skip-container-build) SKIP_CONTAINER_BUILD=true ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

echo "🚀 Starting local build process..."
echo "💻 System: $(uname -s -m)"
echo "🎯 Target Platform: $PLATFORM"
echo "⏱️  Build times can vary depending on system resources and emulation (if any)."
echo ""

if [ "$SKIP_PODMAN_CHECK" = false ]; then
    # Check if podman is available
    if ! command -v podman &> /dev/null; then
        echo "❌ Podman not found."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "💡 Try installing it with: brew install podman"
        else
            echo "💡 Please install Podman for your distribution."
        fi
        exit 1
    fi

    # Initialize podman machine if requested and not running
    if [ "$INIT_PODMAN_MACHINE" = true ] && ! podman machine list | grep -q "Running"; then
        echo "🔧 Initializing Podman machine with $CPUS CPUs, ${MEMORY_GB}GB RAM, ${DISK_SIZE_GB}GB disk..."
        if ! podman machine init --cpus="$CPUS" --memory="$((MEMORY_GB * 1024))" --disk-size="$DISK_SIZE_GB"; then
            echo "❌ Failed to initialize Podman machine. Please check Podman setup."
            exit 1
        fi
        if ! podman machine start; then
            echo "❌ Failed to start Podman machine."
            exit 1
        fi
    elif ! podman machine list | grep -q "Running" && [[ "$PLATFORM" != "linux/$(uname -m)" ]]; then
        echo "⚠️ Podman machine is not running, and the target platform ($PLATFORM) may require emulation."
        echo "💡 Consider starting your Podman machine or use the --init-podman-machine flag."
    fi
else
    echo "🏃 Skipping Podman installation and machine checks."
fi


# Set environment variables for build
export BUILDAH_LAYERS=true
export BUILDAH_ISOLATION="${BUILDAH_ISOLATION:-chroot}" # Use chroot by default, allow override
export TMPDIR="${TMPDIR:-/tmp}"
export PODMAN_USERNS="${PODMAN_USERNS:-keep-id}" # keep-id is often needed for rootless builds

# Configure build parallelism
export GOMAXPROCS="$CPUS"
export MAKEFLAGS="-j$CPUS"
export CARGO_BUILD_JOBS="$CPUS"

# Memory optimization for Buildah
export BUILDAH_TMPDIR="${BUILDAH_TMPDIR:-/tmp/buildah_$$}" # Use a unique temp dir
mkdir -p "$BUILDAH_TMPDIR"

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up temporary Buildah directory: $BUILDAH_TMPDIR..."
    rm -rf "$BUILDAH_TMPDIR"
}
trap cleanup EXIT

FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"

echo "🔨 Building container image..."
echo "📊 Build configuration:"
echo "   • Target Platform: $PLATFORM"
echo "   • CPU cores for build: $CPUS"
echo "   • Memory for build: ${MEMORY_GB}GB"
echo "   • Jobs for build tools: $CPUS"
echo "   • Containerfile: $CONTAINERFILE"
echo "   • Image Name: $FULL_IMAGE_NAME"
echo ""

# Start timing
start_time=$(date +%s)

if [ "$SKIP_CONTAINER_BUILD" = false ]; then
    echo "🔨 Building OCI container image..."
    echo "📊 OCI Build configuration:"
    echo "   • Target Platform: $PLATFORM"
    echo "   • CPU cores for build: $CPUS"
    echo "   • Memory for build: ${MEMORY_GB}GB"
    echo "   • Jobs for build tools: $CPUS"
    echo "   • Containerfile: $CONTAINERFILE"
    echo "   • Image Name: $FULL_IMAGE_NAME"
    echo ""

    # Build the container
    echo "Starting OCI container build process..."
    if ! time podman build \
        ${PLATFORM:+--platform "$PLATFORM"} \
        --jobs "$CPUS" \
        --memory "${MEMORY_GB}g" \
        --tag "$FULL_IMAGE_NAME" \
        --file "$CONTAINERFILE" \
        --progress=plain \
        .; then
            echo ""
            echo "❌ OCI Container build failed."
            if [[ "$PLATFORM" != "linux/$(uname -m)" && "$OSTYPE" == "darwin"* ]]; then
                echo "💡 Building for a different architecture (e.g., amd64 on arm64 Mac) can be complex due to emulation."
                echo "   Consider using a native builder or cloud CI for cross-architecture builds if issues persist."
                echo "   Check Podman machine status and resource allocation."
            fi
            echo "   Review the build logs above for specific errors."
            exit 1
    fi

    # Calculate build time
    oci_end_time=$(date +%s)
    oci_build_time=$((oci_end_time - start_time))
    oci_minutes=$((oci_build_time / 60))
    oci_seconds=$((oci_build_time % 60))

    echo ""
    echo "✅ OCI Container build completed successfully!"
    echo "⏱️  OCI Container Build time: ${oci_minutes}m ${oci_seconds}s"
    echo "🏷️  Image: $FULL_IMAGE_NAME"
    echo ""
else
    echo "⏭️ Skipping OCI container build as requested."
    echo "ℹ️ Ensure the image '$FULL_IMAGE_NAME' exists locally or is pullable for ISO generation."
    # Check if image exists locally if skipping build
    if ! podman image exists "$FULL_IMAGE_NAME"; then
        echo "❌ Image '$FULL_IMAGE_NAME' not found locally. Cannot proceed with ISO generation without it."
        echo "💡 Please build the image first or ensure it's available in your local Podman storage."
        exit 1
    fi
    # Set start_time again if OCI build was skipped, for ISO build timing
    start_time=$(date +%s)
fi


# --- ISO Building Section ---
echo "🛠️ Starting ISO generation process..."

# Ensure output directory exists
mkdir -p "$ISO_OUTPUT_DIR"
ABSOLUTE_ISO_OUTPUT_DIR="$(cd "$ISO_OUTPUT_DIR" && pwd)" # Get absolute path for Podman mount

# Extract architecture from PLATFORM (e.g., linux/amd64 -> amd64)
TARGET_ARCH=$(echo "$PLATFORM" | cut -d'/' -f2)
if [ -z "$TARGET_ARCH" ]; then
    echo "❌ Could not determine target architecture from PLATFORM variable: $PLATFORM"
    exit 1
fi

echo "📊 ISO Build configuration:"
echo "   • Builder Image: $BUILDER_IMAGE"
echo "   • Source OCI Image: $FULL_IMAGE_NAME"
echo "   • Fedora Version: $FEDORA_VERSION"
echo "   • Variant: $VARIANT"
echo "   • Target Architecture: $TARGET_ARCH"
echo "   • Kickstart File: $KICKSTART_PATH"
echo "   • Output ISO: $ABSOLUTE_ISO_OUTPUT_DIR/$ISO_NAME"
echo "   • Secure Boot Key URL: $SECURE_BOOT_KEY_URL"
echo "   • Enrollment Password: $ENROLLMENT_PASSWORD"
echo "   • DNF Cache: $ENABLE_CACHE_DNF"
echo "   • Skopeo Cache: $ENABLE_CACHE_SKOPEO"
echo "   • Flatpak Deps: $ENABLE_FLATPAK_DEPS"
echo ""

echo "Pulling ISO builder image: $BUILDER_IMAGE (if not present)..."
if ! podman pull "$BUILDER_IMAGE"; then
    echo "❌ Failed to pull ISO builder image: $BUILDER_IMAGE"
    exit 1
fi

# Using containers-storage: to refer to local image that Podman built
LOCAL_IMAGE_SRC="containers-storage:${FULL_IMAGE_NAME}"

# Resolve absolute path for kickstart directory for robust mounting
KICKSTART_DIR_ABS=$(readlink -f "$(dirname "$KICKSTART_PATH")")
KICKSTART_BASENAME=$(basename "$KICKSTART_PATH")

echo "🏃 Running ISO builder container..."
# The jasonn3/build-container-installer action.yml sets environment variables for the container,
# and the Makefile inside the container is expected to use these.
# The default make target in the builder image should handle the ISO creation.
if ! time podman run --rm --privileged \
    -v "${ABSOLUTE_ISO_OUTPUT_DIR}:/github/workspace/${ISO_OUTPUT_DIR}:z" \
    -v "/var/lib/containers/storage:/var/lib/containers/storage:ro,z" \
    -v "${KICKSTART_DIR_ABS}:/kickstart_root:ro,z" \
    -e "ARCH=${TARGET_ARCH}" \
    -e "IMAGE_NAME=${IMAGE_NAME}" \
    -e "IMAGE_TAG=${IMAGE_TAG}" \
    -e "IMAGE_SRC=${LOCAL_IMAGE_SRC}" \
    -e "VERSION=${FEDORA_VERSION}" \
    -e "VARIANT=${VARIANT}" \
    -e "ISO_NAME=/github/workspace/${ISO_OUTPUT_DIR}/${ISO_NAME}" \
    -e "KICKSTART_FILE=/kickstart_root/${KICKSTART_BASENAME}" \
    -e "SECURE_BOOT_KEY_URL=${SECURE_BOOT_KEY_URL}" \
    -e "ENROLLMENT_PASSWORD=${ENROLLMENT_PASSWORD}" \
    -e "ENABLE_CACHE_DNF=${ENABLE_CACHE_DNF}" \
    -e "ENABLE_CACHE_SKOPEO=${ENABLE_CACHE_SKOPEO}" \
    -e "ENABLE_FLATPAK_DEPENDENCIES=${ENABLE_FLATPAK_DEPS}" \
    "$BUILDER_IMAGE"; then

    echo ""
    echo "❌ ISO generation failed."
    echo "   Review the Podman run command and the builder container logs for specific errors."
    echo "   Ensure the kickstart path is correct and accessible: ${KICKSTART_DIR_ABS}/${KICKSTART_BASENAME}"
    echo "   Ensure the source OCI image exists: ${FULL_IMAGE_NAME}"
    exit 1
fi

# Calculate ISO build time
iso_end_time=$(date +%s)
iso_build_time=$((iso_end_time - start_time)) # If OCI was skipped, start_time was reset
if [ "$SKIP_CONTAINER_BUILD" = false ]; then
    total_build_time=$((iso_end_time - oci_end_time + oci_build_time)) # Sum of OCI and ISO if OCI ran
else
    total_build_time=$iso_build_time
fi

iso_minutes=$((iso_build_time / 60))
iso_seconds=$((iso_build_time % 60))
total_minutes=$((total_build_time / 60))
total_seconds=$((total_build_time % 60))

echo ""
echo "✅ ISO generation completed successfully!"
echo "⏱️  ISO Build time: ${iso_minutes}m ${iso_seconds}s"
echo "💿 ISO Location: $ABSOLUTE_ISO_OUTPUT_DIR/$ISO_NAME"
echo ""
# --- End ISO Building Section ---


# Optional: Export the image for transfer
if [[ "${EXPORT_IMAGE_AFTER_BUILD:-false}" == "true" || "$*" == *--export-image* ]] && [ "$SKIP_CONTAINER_BUILD" = false ]; then
    EXPORT_FILENAME="${IMAGE_NAME}-$(echo "$PLATFORM" | tr '/' '_')-$(date +%Y%m%d).tar.gz"
    echo "📦 Exporting image to $EXPORT_FILENAME..."
    if podman save "$FULL_IMAGE_NAME" | gzip > "$EXPORT_FILENAME"; then
        echo "✅ Image exported to $EXPORT_FILENAME"
        ls -lh "$EXPORT_FILENAME"
    else
        echo "❌ Failed to export image."
    fi
fi

echo ""
echo "🎉 Local build script finished!"
echo "📋 Next steps (after ISO generation is implemented):"
echo "   1. Test the generated ISO in a VM or on hardware."
echo "   2. For container testing: podman run --rm ${PLATFORM:+--platform "$PLATFORM"} $FULL_IMAGE_NAME uname -m"


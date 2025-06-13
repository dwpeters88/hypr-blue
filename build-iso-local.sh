#!/bin/bash
# High-performance local container build script for M4 Pro
set -euo pipefail

echo "🚀 Starting high-performance AMD x86_64 build using all available resources..."
echo "💻 System: M4 Pro (14 cores, 64GB RAM)"
echo "🎯 Target: AMD x86_64 architecture"
echo "⏱️  Expected time: 2-3 hours (due to emulation)"
echo ""

# Check if podman is available
if ! command -v podman &> /dev/null; then
    echo "❌ Podman not found. Installing via Homebrew..."
    brew install podman
fi

# Initialize podman machine if needed
if ! podman machine list | grep -q "Running"; then
    echo "🔧 Initializing Podman machine..."
    podman machine init --cpus=14 --memory=32768 --disk-size=100 || true
    podman machine start || true
fi

# Set environment variables for maximum performance
export BUILDAH_LAYERS=true
export BUILDAH_ISOLATION=chroot
export TMPDIR=/tmp
export PODMAN_USERNS=keep-id

# Configure build parallelism
export GOMAXPROCS=14
export MAKEFLAGS="-j14"
export CARGO_BUILD_JOBS=14

# Memory optimization
export BUILDAH_TMPDIR=/tmp/buildah
mkdir -p $BUILDAH_TMPDIR

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up temporary files..."
    rm -rf $BUILDAH_TMPDIR
}
trap cleanup EXIT

echo "🔨 Building container image with maximum parallelism..."
echo "📊 Build configuration:"
echo "   • Platform: linux/amd64"
echo "   • CPU cores: 14"
echo "   • Memory: 32GB"
echo "   • Jobs: 14 parallel"
echo ""

# Start timing
start_time=$(date +%s)

# Build the container with maximum resources
echo "Starting container build..."
if ! time podman build \
    --platform linux/amd64 \
    --jobs 14 \
    --memory 32g \
    --tag hypr-blue:iso-build-amd64 \
    --file Containerfile \
    --progress=plain \
    .; then
        echo "❌ Container build failed. This is expected on ARM64 due to emulation complexity."
        echo "💡 Recommendation: Use GitHub Actions for native AMD64 performance."
        echo "🔗 URL: https://github.com/dwpeters88/hypr-blue/actions/workflows/build.yml"
        exit 1
fi

# Calculate build time
end_time=$(date +%s)
build_time=$((end_time - start_time))
minutes=$((build_time / 60))
seconds=$((build_time % 60))

echo ""
echo "✅ Container build completed successfully!"
echo "⏱️  Build time: ${minutes}m ${seconds}s"
echo "🏷️  Image: hypr-blue:iso-build-amd64"
echo ""
echo "📦 Container image ready for AMD x86_64 deployment"
echo "💡 Note: For ISO generation, use GitHub Actions workflow"
echo "🔗 Workflow: https://github.com/dwpeters88/hypr-blue/actions/workflows/build-iso.yml"

# Optional: Export the image for transfer
echo ""
read -p "🤔 Export image to file? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📦 Exporting image..."
    podman save hypr-blue:iso-build-amd64 | gzip > hypr-blue-amd64-$(date +%Y%m%d).tar.gz
    echo "✅ Image exported to hypr-blue-amd64-$(date +%Y%m%d).tar.gz"
    ls -lh hypr-blue-amd64-*.tar.gz
fi

echo ""
echo "🎉 Local AMD x86_64 build completed!"
echo "📋 Next steps:"
echo "   1. Test the container: podman run --rm --platform linux/amd64 hypr-blue:iso-build-amd64 uname -m"
echo "   2. Use GitHub Actions for ISO generation"
echo "   3. Deploy to AMD64 hardware"


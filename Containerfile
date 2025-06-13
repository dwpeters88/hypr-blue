# Build context for scripts
FROM scratch AS ctx
COPY build_files /

# Base Image - Bazzite with proper version tag
FROM ghcr.io/ublue-os/bazzite:stable

# CRITICAL: Add OSTree metadata labels
LABEL ostree.bootable="true"
LABEL com.coreos.ostree="true"
LABEL org.opencontainers.image.title="hypr-blue"
LABEL org.opencontainers.image.description="Custom Fedora 42 Bazzite with Hyprland"
LABEL io.buildah.version="1.35.0"

# Set proper OSTree variables
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-42}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-bazzite}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-dwpeters88}"
ARG IMAGE_NAME="${IMAGE_NAME:-hypr-blue}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"

# Copy system configuration files
COPY system_files/usr /usr

# Run build script with proper mounts
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=tmpfs,dst=/var/tmp \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && \
    # CRITICAL: Properly commit the OSTree container
    ostree container commit && \
    # Clean up to reduce image size
    mkdir -p /var/tmp && \
    chmod 1777 /var/tmp && \
    rm -rf /tmp/* /var/tmp/* && \
    # Ensure bootc compatibility
    bootc container lint

# Set the container as bootable
RUN touch /etc/containers/bootc/bootc.conf
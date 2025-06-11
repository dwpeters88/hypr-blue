# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM quay.io/fedora/fedora-bootc:40

USER root
RUN rpm-ostree override remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra && \
    rpm-ostree install --allow-inactive dnf5 util-linux && \
    rpm-ostree cleanup -m
# The ostree container commit for this stage will be combined with the next one.

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
#
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### MODIFICATIONS

RUN --mount=type=bind,from=ctx,source=/,target=/ctx,rw \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    chmod +x /ctx/build.sh && /ctx/build.sh && \
    ostree container commit

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
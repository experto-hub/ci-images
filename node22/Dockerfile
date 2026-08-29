FROM node:22-bookworm-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

ARG IMAGE_SOURCE="https://github.com/JacekKardys/ci-images"
ARG IMAGE_REVISION="local"
ARG IMAGE_CREATED="unknown"
ARG IMAGE_VERSION="1"

LABEL org.opencontainers.image.title="Reusable Node.js 22 CI toolchain" \
      org.opencontainers.image.description="Node.js 22, npm, Git and CA certificates for Linux x86_64 CI jobs" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.base.name="docker.io/library/node:22-bookworm-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5"

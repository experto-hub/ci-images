FROM python:3.14-slim-bookworm@sha256:416f0db2a2b561945630cef9877a7ea0581b27449eb9fd9df42f03e1b74b5b63

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

ARG IMAGE_SOURCE="https://github.com/experto-hub/ci-images"
ARG IMAGE_REVISION="local"
ARG IMAGE_CREATED="unknown"
ARG IMAGE_VERSION="1"

LABEL org.opencontainers.image.title="Reusable Python 3.14 CI toolchain" \
      org.opencontainers.image.description="Python 3.14, pip, venv, Git and CA certificates for Linux x86_64 CI jobs" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.base.name="docker.io/library/python:3.14-slim-bookworm@sha256:416f0db2a2b561945630cef9877a7ea0581b27449eb9fd9df42f03e1b74b5b63"

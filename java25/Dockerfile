FROM eclipse-temurin:25-jdk-noble@sha256:534968c051301957beae735e7ba1db54d99ddecf08746d3b9d4f318cc132dbc3

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

ARG IMAGE_SOURCE="https://github.com/experto-hub/ci-images"
ARG IMAGE_REVISION="local"
ARG IMAGE_CREATED="unknown"
ARG IMAGE_VERSION="1"

LABEL org.opencontainers.image.title="Reusable Java 25 CI toolchain" \
      org.opencontainers.image.description="Eclipse Temurin JDK 25, Git, CA certificates, curl, unzip and Ubuntu shell utilities for Linux x86_64 CI jobs" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.base.name="docker.io/library/eclipse-temurin:25-jdk-noble@sha256:534968c051301957beae735e7ba1db54d99ddecf08746d3b9d4f318cc132dbc3"

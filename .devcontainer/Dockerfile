FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae

ARG OPENHANDS_UID=10001
ARG WORKSPACE_GID=1000

RUN useradd --create-home --uid "${OPENHANDS_UID}" --gid "${WORKSPACE_GID}" \
        --shell /bin/bash openhands

USER openhands

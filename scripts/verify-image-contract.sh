#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 7 ]]; then
  echo "Usage: $0 <node22|python312|java21|java25> <image> <source> <revision> <created> <version> <base-digest>" >&2
  exit 2
fi

profile="$1"
image="$2"
expected_source="$3"
expected_revision="$4"
expected_created="$5"
expected_version="$6"
expected_base_digest="$7"

assert_equal() {
  local field="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "Contract mismatch for ${field}: expected '${expected}', got '${actual}'" >&2
    exit 1
  fi
}

label_value() {
  local label="$1"
  docker image inspect "$image" --format "{{ index .Config.Labels \"${label}\" }}"
}

architecture="$(docker image inspect "$image" --format '{{.Architecture}}')"
logical_size="$(docker image inspect "$image" --format '{{.Size}}')"

assert_equal architecture amd64 "$architecture"
assert_equal org.opencontainers.image.source "$expected_source" "$(label_value org.opencontainers.image.source)"
assert_equal org.opencontainers.image.revision "$expected_revision" "$(label_value org.opencontainers.image.revision)"
assert_equal org.opencontainers.image.created "$expected_created" "$(label_value org.opencontainers.image.created)"
assert_equal org.opencontainers.image.version "$expected_version" "$(label_value org.opencontainers.image.version)"

case "$profile" in
  node22)
    assert_equal org.opencontainers.image.base.name \
      "docker.io/library/node:22-bookworm-slim@${expected_base_digest}" \
      "$(label_value org.opencontainers.image.base.name)"
    docker run --rm "$image" sh -ceu '
      node --version
      npm --version
      git --version
      test "$(node -p "process.versions.node.split(\".\")[0]")" = "22"
      test "$(uname -m)" = "x86_64"
      test "$(pwd)" = "/workspace"
      test -f /etc/ssl/certs/ca-certificates.crt
      ! command -v python
      ! command -v python3
      ! command -v java
      ! command -v docker
    '
    ;;
  python312)
    assert_equal org.opencontainers.image.base.name \
      "docker.io/library/python:3.12-slim-bookworm@${expected_base_digest}" \
      "$(label_value org.opencontainers.image.base.name)"
    docker run --rm "$image" sh -ceu '
      venv_dir="$(mktemp -d)"
      trap '\''rm -rf "$venv_dir"'\'' EXIT
      python3 --version
      pip --version
      git --version
      test "$(python3 -c "import sys; print(f'\''{sys.version_info.major}.{sys.version_info.minor}'\'')")" = "3.12"
      python3 -m venv "$venv_dir"
      "$venv_dir/bin/python" --version
      test "$(uname -m)" = "x86_64"
      test "$(pwd)" = "/workspace"
      test -f /etc/ssl/certs/ca-certificates.crt
      ! command -v node
      ! command -v java
      ! command -v docker
    '
    ;;
  java21 | java25)
    java_feature="${profile#java}"
    assert_equal org.opencontainers.image.title \
      "Reusable Java ${java_feature} CI toolchain" \
      "$(label_value org.opencontainers.image.title)"
    assert_equal org.opencontainers.image.description \
      "Eclipse Temurin JDK ${java_feature}, Git, CA certificates, curl, unzip and Ubuntu shell utilities for Linux x86_64 CI jobs" \
      "$(label_value org.opencontainers.image.description)"
    assert_equal org.opencontainers.image.base.name \
      "docker.io/library/eclipse-temurin:${java_feature}-jdk-noble@${expected_base_digest}" \
      "$(label_value org.opencontainers.image.base.name)"
    docker run --rm "$image" sh -ceu '
      expected_feature="$1"

      test -n "${JAVA_HOME:-}"
      test -d "$JAVA_HOME"
      test -x "$JAVA_HOME/bin/java"
      test -x "$JAVA_HOME/bin/javac"
      test "$(readlink -f "$(command -v java)")" = "$(readlink -f "$JAVA_HOME/bin/java")"
      test "$(readlink -f "$(command -v javac)")" = "$(readlink -f "$JAVA_HOME/bin/javac")"

      java_feature="$(
        java -XshowSettings:properties -version 2>&1 |
          awk -F" = " "/^[[:space:]]*java.specification.version = / { print \$2; exit }"
      )"
      javac_version="$(javac -version 2>&1 | awk "{ print \$2 }")"
      javac_feature="${javac_version%%.*}"
      test "$java_feature" = "$expected_feature"
      test "$javac_feature" = "$expected_feature"

      java -version
      javac -version
      git --version
      curl --version | head -n 1
      unzip -v | head -n 1

      for required_command in bash git curl unzip sed awk grep tar gzip mktemp uname id; do
        command -v "$required_command" >/dev/null
      done
      test "$(id -u)" = "0"
      test "$(uname -m)" = "x86_64"
      test "$(pwd)" = "/workspace"
      test -s /etc/ssl/certs/ca-certificates.crt
      command -v update-ca-certificates >/dev/null

      for excluded_command in mvn gradle node npm python python3 docker; do
        if command -v "$excluded_command" >/dev/null 2>&1; then
          echo "Excluded command is present: ${excluded_command}" >&2
          exit 1
        fi
      done
    ' -- "$java_feature"
    ;;
  *)
    echo "Unsupported image profile: $profile" >&2
    exit 2
    ;;
esac

echo "contract=passed profile=${profile} image=${image} architecture=${architecture} logical_size_bytes=${logical_size}"

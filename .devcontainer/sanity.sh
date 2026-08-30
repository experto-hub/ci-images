#!/usr/bin/env bash

set -euo pipefail

test "$(id -u)" = 10001
test "$(id -g)" = 1000
test -f README.md
test -f node22/Dockerfile
test -f python312/Dockerfile
test "$(javac -version 2>&1 | awk '{print $2}' | cut -d. -f1)" = 25
test "$(node --version | sed -E 's/^v([0-9]+).*/\1/')" = 24
test ! -e /var/run/docker.sock
test ! -e /run/docker.sock

git diff --check
git status --short

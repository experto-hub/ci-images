#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 9 ]]; then
  echo "Usage: $0 <profile> <display-name> <local-image> <published-image> <source> <revision> <created> <version> <base-digest>" >&2
  exit 2
fi

profile="$1"
display_name="$2"
local_image="$3"
published_image="$4"
source_url="$5"
source_revision="$6"
image_created="$7"
image_version="$8"
base_digest="$9"

for required_name in DOCKER_CONFIG GHCR_TOKEN GITHUB_ACTOR GITHUB_API_URL GITHUB_OUTPUT GITHUB_REPOSITORY GITHUB_STEP_SUMMARY; do
  if [[ -z "${!required_name:-}" ]]; then
    echo "Required environment variable is not set: ${required_name}" >&2
    exit 2
  fi
done

resolve_registry_digest() {
  local reference="$1"
  local digest_reference

  docker pull "$reference" >&2
  digest_reference="$(
    docker image inspect "$reference" --format '{{range .RepoDigests}}{{println .}}{{end}}' |
      awk -v prefix="${published_image}@" 'index($0, prefix) == 1 { print; exit }'
  )"

  if [[ -z "$digest_reference" ]]; then
    echo "Registry digest was not recorded for ${reference}" >&2
    exit 1
  fi

  printf '%s\n' "${digest_reference#*@}"
}

mkdir -p "$DOCKER_CONFIG"
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io --username "$GITHUB_ACTOR" --password-stdin

commit_tag="sha-${source_revision}"
contract_tag="$image_version"
commit_reference="${published_image}:${commit_tag}"
contract_reference="${published_image}:${contract_tag}"

docker tag "$local_image" "$commit_reference"
docker push "$commit_reference"
published_digest="$(resolve_registry_digest "$commit_reference")"

if [[ ! "$published_digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "Invalid registry digest: ${published_digest}" >&2
  exit 1
fi

digest_reference="${published_image}@${published_digest}"
docker pull "$digest_reference"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "${script_dir}/verify-image-contract.sh" \
  "$profile" \
  "$digest_reference" \
  "$source_url" \
  "$source_revision" \
  "$image_created" \
  "$image_version" \
  "$base_digest"

main_ref_json="$(
  curl --fail --silent --show-error --location \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer ${GHCR_TOKEN}" \
    --header "X-GitHub-Api-Version: 2026-03-10" \
    "${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/git/ref/heads/main"
)"
current_main_revision="$(
  printf '%s\n' "$main_ref_json" |
    sed -nE 's/.*"sha"[[:space:]]*:[[:space:]]*"([0-9a-f]{40})".*/\1/p' |
    head -n 1
)"

if [[ -z "$current_main_revision" ]]; then
  echo "Could not resolve the current main revision" >&2
  exit 1
fi

if [[ "$current_main_revision" != "$source_revision" ]]; then
  echo "Refusing to promote ${source_revision}: current main is ${current_main_revision}" >&2
  exit 1
fi

docker tag "$commit_reference" "$contract_reference"
docker push "$contract_reference"

resolved_commit_digest="$(resolve_registry_digest "$commit_reference")"
resolved_contract_digest="$(resolve_registry_digest "$contract_reference")"

if [[ "$resolved_commit_digest" != "$published_digest" ]]; then
  echo "Commit tag digest changed: expected ${published_digest}, got ${resolved_commit_digest}" >&2
  exit 1
fi

if [[ "$resolved_contract_digest" != "$published_digest" ]]; then
  echo "Contract tag digest mismatch: expected ${published_digest}, got ${resolved_contract_digest}" >&2
  exit 1
fi

logical_size="$(docker image inspect "$digest_reference" --format '{{.Size}}')"
case "$profile" in
  node22)
    runtime_version="$(docker run --rm "$digest_reference" node -p 'process.versions.node')"
    npm_version="$(docker run --rm "$digest_reference" npm --version)"
    git_version="$(docker run --rm "$digest_reference" sh -ceu "git --version | awk '{print \$3}'")"
    toolchain="Node.js ${runtime_version}, npm ${npm_version}, Git ${git_version}"
    ;;
  python312)
    runtime_version="$(docker run --rm "$digest_reference" python3 -c 'import platform; print(platform.python_version())')"
    pip_version="$(docker run --rm "$digest_reference" sh -ceu "pip --version | awk '{print \$2}'")"
    git_version="$(docker run --rm "$digest_reference" sh -ceu "git --version | awk '{print \$3}'")"
    toolchain="Python ${runtime_version}, pip ${pip_version}, Git ${git_version}"
    ;;
  *)
    echo "Unsupported image profile: $profile" >&2
    exit 2
    ;;
esac

{
  echo "image=$published_image"
  echo "contract_tag=$contract_tag"
  echo "commit_tag=$commit_tag"
  echo "digest=$published_digest"
  echo "runtime_version=$runtime_version"
  echo "base_digest=$base_digest"
  echo "logical_size_bytes=$logical_size"
} >> "$GITHUB_OUTPUT"

{
  echo "## ${display_name} image"
  echo
  echo "- Image: \`${published_image}\`"
  echo "- Toolchain: ${toolchain}"
  echo "- Contract tag: \`${contract_reference}\`"
  echo "- Commit release tag: \`${commit_reference}\`"
  echo "- Registry digest: \`${published_digest}\`"
  echo "- Preferred consumer pin: \`${digest_reference}\`"
  echo "- Base image digest: \`${base_digest}\`"
  echo "- Logical image size: \`${logical_size}\` bytes"
  echo "- Registry pull-back contract verification: passed"
  echo "- Commit/contract tag digest equality: passed"
} >> "$GITHUB_STEP_SUMMARY"

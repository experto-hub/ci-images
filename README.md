# Reusable CI images

This repository owns two narrow execution toolchains for trusted private Linux x86_64 CI jobs. It does not own application dependencies, dependency caches, source code, browsers, Docker access or repository-specific configuration.

## Image contracts

| Image | Included | Deliberately excluded | Pinned base |
|---|---|---|---|
| `ghcr.io/experto-hub/ci-node22` | Node.js 22, npm, Git, CA certificates, Debian shell utilities | Python, JDK, browsers, Docker CLI, application dependencies | `node:22-bookworm-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5` |
| `ghcr.io/experto-hub/ci-python312` | Python 3.12, pip, venv, Git, CA certificates, Debian shell utilities | Node.js, JDK, browsers, Docker CLI, application dependencies | `python:3.12-slim-bookworm@sha256:0f5b26b9518d002b6173fd61daad821fa340635ebfec5bba471013f9ca114579` |

Both images are `linux/amd64` only and use `/workspace` as their working directory. The repository intentionally does not publish `latest`.

The images run as root. GitHub Actions controls the mounted workspace ownership, and introducing another user would add checkout and write-permission failure modes without creating a meaningful isolation boundary in this trusted private-CI model. Consumers must not mount the Docker socket into these images; access to the host daemon is effectively host-root access.

## Release identity

Each successful `main` publication exposes three different references:

- `:1` is a mutable moving reference for image contract line 1.
- `:sha-<full-ci-images-commit>` is a mutable registry tag that identifies the source commit used for a release.
- `@sha256:<registry-digest>` is the cryptographic content identity and the preferred consumer pin.

Example consumer configuration:

```yaml
permissions:
  contents: read
  packages: read

jobs:
  verify:
    runs-on: [self-hosted, linux, x64, proart]
    container:
      image: ghcr.io/experto-hub/ci-node22@sha256:<digest-from-the-release-manifest>
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
```

The packages are private. A consumer repository needs explicit package access plus `packages: read`; do not replace that boundary with a long-lived personal access token.

## Build and publication model

Pull requests build and verify both images without publishing. Changes merged to `main` run on `[self-hosted, linux, x64, proart]` and use run-unique local tags so the shared persistent Docker daemon cannot confuse concurrent or rerun scratch images.

OCI source metadata is derived from the Git commit, including `org.opencontainers.image.created`. This makes source metadata deterministic for a revision. It does not make builds bit-identical: unpinned Debian repository contents may change between rebuilds.

For each image, the workflow:

1. builds a local candidate from a digest-pinned base;
2. verifies labels, architecture, working directory, required tools and excluded toolchains;
3. publishes the commit release tag and resolves the GHCR digest;
4. pulls that digest back and runs the same contract verifier against it;
5. confirms the source revision is still the current `main` head;
6. advances `:1` and asserts that both tags resolve to the candidate digest;
7. reports the exact image, toolchain versions, tags, digest, base digest and logical size;
8. uploads a small JSON release manifest artifact after both images succeed.

The workflow concurrency group serializes runs for the same ref. The explicit current-`main` check also prevents an old run of this hardened workflow from regressing the moving `:1` tag. Local scratch tags and temporary Docker authentication under `RUNNER_TEMP` are removed after every job; the shared layer cache is deliberately retained.

The workflow run summary and JSON artifact are the authoritative release records. Documentation does not duplicate live registry digests.

The Node.js and Python contract tags are independent release streams, not one atomic two-image transaction. Each `:1` advances only after its own end-to-end proof. The combined release manifest is emitted only when both images in that workflow run succeed; its absence means there is no paired snapshot for that source revision.

## Local verification

Use the current commit metadata so local labels match the release contract:

```bash
revision="$(git rev-parse HEAD)"
created="$(git show --no-show-signature --format=%cI -s "$revision")"
source="https://github.com/experto-hub/ci-images"

docker build \
  --build-arg "IMAGE_SOURCE=$source" \
  --build-arg "IMAGE_REVISION=$revision" \
  --build-arg "IMAGE_CREATED=$created" \
  --build-arg "IMAGE_VERSION=1" \
  --tag ci-node22:local \
  node22

bash scripts/verify-image-contract.sh \
  node22 ci-node22:local "$source" "$revision" "$created" 1 \
  sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5

docker build \
  --build-arg "IMAGE_SOURCE=$source" \
  --build-arg "IMAGE_REVISION=$revision" \
  --build-arg "IMAGE_CREATED=$created" \
  --build-arg "IMAGE_VERSION=1" \
  --tag ci-python312:local \
  python312

bash scripts/verify-image-contract.sh \
  python312 ci-python312:local "$source" "$revision" "$created" 1 \
  sha256:0f5b26b9518d002b6173fd61daad821fa340635ebfec5bba471013f9ca114579
```

The latest pre-hardening ProArt baseline (workflow run `33252417011`) reported 113,501,224 logical bytes for Node.js and 74,817,520 logical bytes for Python. Docker storage backends account for layers differently, so compare sizes only when the same engine and measurement are used. Every publication records fresh sizes and exact runtime versions.

## Updates and supply-chain status

Base tags and digests are updated only through reviewed Dockerfile changes that pass the normal build and contract tests. Dependabot checks both Dockerfiles and pinned GitHub Actions weekly; updates are never auto-merged.

| Capability | Status | Reason |
|---|---|---|
| GitHub-native build provenance | Deferred | Artifact attestations for a private repository require GitHub Enterprise Cloud; this organization currently uses GitHub Team. No signing keys or workaround service are introduced. |
| OCI-attached SBOM | Deferred | Attaching and preserving a BuildKit SBOM would require changing the current daemon build/push path and exact-artifact validation model. That is not a low-complexity closeout change. |
| Vulnerability gate | Deferred | A stable scanner/database source and an explicit severity and fix-availability policy must be agreed before making it a release gate. |
| Automated dependency PRs | Enabled | Weekly, bounded Dependabot PRs cover the two Docker bases and pinned GitHub Actions. |

## Intentional non-goals

- consumer workflow migration;
- application dependency installation or cache redesign;
- JDK, browsers, Docker CLI, Docker-in-Docker, build-essential or CUDA;
- a combined Node/Python image;
- ARM or multi-architecture publication;
- changing the Debian base family merely to reduce size;
- snapshot Debian repositories or full bit-for-bit reproducibility claims.

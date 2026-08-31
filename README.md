# Reusable CI images

This repository owns five narrow execution toolchains for trusted Linux x86_64 CI jobs. It does not own application dependencies, dependency caches, source code, browsers, Docker access or repository-specific configuration.

## Image contracts

| Image | Included | Deliberately excluded | Pinned base |
|---|---|---|---|
| `ghcr.io/experto-hub/ci-node22` | Node.js 22, npm, Git, CA certificates, Debian shell utilities | Python, JDK, browsers, Docker CLI, application dependencies | `node:22-bookworm-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5` |
| `ghcr.io/experto-hub/ci-python312` | Python 3.12, pip, venv, Git, CA certificates, Debian shell utilities | Node.js, JDK, browsers, Docker CLI, application dependencies | `python:3.12-slim-bookworm@sha256:0f5b26b9518d002b6173fd61daad821fa340635ebfec5bba471013f9ca114579` |
| `ghcr.io/experto-hub/ci-python314` | Python 3.14, pip, venv, Git, CA certificates, Debian shell utilities | Node.js, JDK, browsers, Docker CLI, application dependencies | `python:3.14-slim-bookworm@sha256:416f0db2a2b561945630cef9877a7ea0581b27449eb9fd9df42f03e1b74b5b63` |
| `ghcr.io/experto-hub/ci-java21` | Eclipse Temurin JDK 21 and `javac`, Git, CA certificates, curl, unzip, Ubuntu shell utilities | Maven, Gradle, Node.js, Python, browsers, Docker CLI, application dependencies | `eclipse-temurin:21-jdk-noble@sha256:75ce56643243c3db632be2ef259625fb42ee3be1334389659f7a1a61acb78783` |
| `ghcr.io/experto-hub/ci-java25` | Eclipse Temurin JDK 25 and `javac`, Git, CA certificates, curl, unzip, Ubuntu shell utilities | Maven, Gradle, Node.js, Python, browsers, Docker CLI, application dependencies | `eclipse-temurin:25-jdk-noble@sha256:534968c051301957beae735e7ba1db54d99ddecf08746d3b9d4f318cc132dbc3` |

All five images are `linux/amd64` only and use `/workspace` as their working directory. The repository intentionally does not publish `latest`. The Java images deliberately leave Maven version ownership to each consumer's checked-in Maven Wrapper.

The images run as root. GitHub Actions controls the mounted workspace ownership, and introducing another user would add checkout and write-permission failure modes without creating a meaningful isolation boundary in this trusted-CI model. Consumers must not mount the Docker socket into these images; access to the host daemon is effectively host-root access.

## Release identity

Each successful `main` publication exposes three different references:

- `:1` is a mutable moving reference for image contract line 1.
- `:sha-<full-ci-images-commit>` is a mutable registry tag that identifies the source commit used for a release.
- `@sha256:<registry-digest>` is the cryptographic content identity and the preferred consumer pin.

Example consumer configuration:

```yaml
permissions:
  contents: read

jobs:
  verify:
    runs-on: [self-hosted, linux, x64, proart]
    container:
      image: ghcr.io/experto-hub/ci-node22@sha256:<digest-from-the-release-manifest>
```

The packages are public and can be pulled anonymously. Consumers do not need package access, `packages: read`, registry credentials or a long-lived personal access token.

GitHub creates a new container package as private. The first publication of a new image profile therefore publishes and proves the image, then deliberately fails the public-visibility gate. An organization owner must allow public package creation in the organization package settings, change that package to **Public**, optionally disable public package creation again, and rerun the same workflow. The package visibility transition is permanent: GitHub does not allow a public package to become private again.

## Build and publication model

Pull requests build and verify all five images without publishing. Changes merged to `main` run on `[self-hosted, linux, x64, proart]` and use run-unique local tags so the shared persistent Docker daemon cannot confuse concurrent or rerun scratch images.

OCI source metadata is derived from the Git commit, including `org.opencontainers.image.created`. This makes source metadata deterministic for a revision. It does not make builds bit-identical: unpinned Debian repository contents may change between rebuilds.

For each image, the workflow:

1. builds a local candidate from a digest-pinned base;
2. verifies labels, architecture, working directory, required tools and excluded toolchains;
3. publishes the commit release tag and resolves the GHCR digest;
4. pulls that digest back and runs the same contract verifier against it;
5. confirms the source revision is still the current `main` head;
6. advances `:1` and asserts that both tags resolve to the candidate digest;
7. verifies through the GitHub Packages API that the package is public;
8. reports the exact image, toolchain versions, tags, digest, base digest and logical size;
9. uploads a small JSON release manifest artifact after all five images succeed.

The workflow concurrency group serializes runs for the same ref. The explicit current-`main` check also prevents an old run of this hardened workflow from regressing the moving `:1` tag. Local scratch tags and temporary Docker authentication under `RUNNER_TEMP` are removed after every job; the shared layer cache is deliberately retained.

## Pull request security

The repository is public, but its ProArt runners are not a public execution service. Pull request validation uses the workflow definition from the protected target branch and executes the proposed revision only when the pull request head belongs to this repository. Fork pull requests fail the stable `Quality` check without checking out or executing fork content on a self-hosted runner. A maintainer may review an external contribution as data and recreate an accepted change on a branch in this repository.

## Branch and release model

`develop` is the default integration branch. Feature and dependency pull requests target `develop`. Both `develop` and `main` are protected against direct pushes, force pushes and deletion. They require the stable `Quality` check, resolved review conversations and one approving review from the owners declared in `.github/CODEOWNERS`. A new push dismisses a stale approval, and the last pusher cannot provide the required approval.

All pull requests use merge commits. Production releases use a pull request whose head is exactly `develop` and whose base is `main`. The `Quality` policy rejects every other pull request source for `main`. This preserves `develop` as an ancestor of `main`; the protected `develop` branch must not be deleted after release. Publishing remains exclusive to the resulting push on `main`.

The workflow run summary and JSON artifact are the authoritative release records. Documentation does not duplicate live registry digests.

The five contract tags are independent release streams, not one atomic registry transaction. Each `:1` advances only after its own end-to-end proof. The combined release manifest is emitted only when Node 22, Python 3.12, Python 3.14, Java 21 and Java 25 all succeed in that workflow run; its absence means there is no complete five-image snapshot for that source revision.

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

docker build \
  --build-arg "IMAGE_SOURCE=$source" \
  --build-arg "IMAGE_REVISION=$revision" \
  --build-arg "IMAGE_CREATED=$created" \
  --build-arg "IMAGE_VERSION=1" \
  --tag ci-python314:local \
  python314

bash scripts/verify-image-contract.sh \
  python314 ci-python314:local "$source" "$revision" "$created" 1 \
  sha256:416f0db2a2b561945630cef9877a7ea0581b27449eb9fd9df42f03e1b74b5b63

docker build \
  --build-arg "IMAGE_SOURCE=$source" \
  --build-arg "IMAGE_REVISION=$revision" \
  --build-arg "IMAGE_CREATED=$created" \
  --build-arg "IMAGE_VERSION=1" \
  --tag ci-java21:local \
  java21

bash scripts/verify-image-contract.sh \
  java21 ci-java21:local "$source" "$revision" "$created" 1 \
  sha256:75ce56643243c3db632be2ef259625fb42ee3be1334389659f7a1a61acb78783

bash scripts/verify-maven-wrapper.sh ci-java21:local 21

docker build \
  --build-arg "IMAGE_SOURCE=$source" \
  --build-arg "IMAGE_REVISION=$revision" \
  --build-arg "IMAGE_CREATED=$created" \
  --build-arg "IMAGE_VERSION=1" \
  --tag ci-java25:local \
  java25

bash scripts/verify-image-contract.sh \
  java25 ci-java25:local "$source" "$revision" "$created" 1 \
  sha256:534968c051301957beae735e7ba1db54d99ddecf08746d3b9d4f318cc132dbc3

bash scripts/verify-maven-wrapper.sh ci-java25:local 25
```

The latest pre-hardening ProArt baseline (workflow run `33252417011`) reported 113,501,224 logical bytes for Node.js and 74,817,520 logical bytes for Python. Docker storage backends account for layers differently, so compare sizes only when the same engine and measurement are used. Every publication records fresh sizes and exact runtime versions.

## Updates and supply-chain status

Base tags and digests are updated only through reviewed Dockerfile changes that pass the normal build and contract tests. Dependabot checks all five Dockerfiles and pinned GitHub Actions weekly; updates are never auto-merged. Runtime feature-line updates are ignored inside a version-named profile because they require a new profile, explicit contract metadata and consumer compatibility evidence.

| Capability | Status | Reason |
|---|---|---|
| GitHub-native build provenance | Deferred | Artifact attestations for a private repository require GitHub Enterprise Cloud; this organization currently uses GitHub Team. No signing keys or workaround service are introduced. |
| OCI-attached SBOM | Deferred | Attaching and preserving a BuildKit SBOM would require changing the current daemon build/push path and exact-artifact validation model. That is not a low-complexity closeout change. |
| Vulnerability gate | Deferred | A stable scanner/database source and an explicit severity and fix-availability policy must be agreed before making it a release gate. |
| Automated dependency PRs | Enabled | Weekly, bounded Dependabot PRs cover the five Docker bases and pinned GitHub Actions without changing a named runtime feature line. |

## Intentional non-goals

- consumer workflow migration;
- application dependency installation or cache redesign;
- Maven, Gradle, browsers, Docker CLI, Docker-in-Docker, build-essential or CUDA;
- combined multi-toolchain images;
- ARM or multi-architecture publication;
- changing the Debian base family merely to reduce size;
- snapshot Debian repositories or full bit-for-bit reproducibility claims.

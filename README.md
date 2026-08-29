# Reusable CI images

This repository owns small, reusable execution toolchains for Linux x86_64 CI jobs. It does not own application builds, dependency caches, source code or repository-specific configuration.

The first consumer analysis is based on `JacekKardys/last-diagrams` at `feature/self-hosted-proart-runner` commit `bc41b7f69755cfd7eda424ca77443c71fd0cea93` (PR #162), based on `develop` commit `7d96ad5f1ef5097d297587763796c0a7fc78ea15`.

## Images

| Image | Intended consumers | Included | Deliberately excluded | Base |
|---|---|---|---|---|
| `ghcr.io/jacekkardys/ci-node22` | Node-only build, test and static-analysis jobs | Node.js 22, npm, Git, CA certificates, standard Debian shell utilities | Python, JDK, browsers, Docker CLI, application dependencies | `node:22-bookworm-slim@sha256:83f487e0a63425e5b4d146fb5e5be574bcbe1b7b843d3ebafdd95eaf7767a7e5` |
| `ghcr.io/jacekkardys/ci-python312` | Python-only test and validation jobs | Python 3.12, pip, venv, Git, CA certificates, standard Debian shell utilities | Node.js, JDK, browsers, Docker CLI, application dependencies | `python:3.12-slim-bookworm@sha256:0f5b26b9518d002b6173fd61daad821fa340635ebfec5bba471013f9ca114579` |

Both images currently support only Linux x86_64. They intentionally run as root because GitHub Actions mounts the workspace with runner-controlled ownership. Consumers must not mount the Docker socket into these general images.

### Local image characteristics

Measured from clean local builds on 2026-08-29. Docker reports logical (uncompressed) image size.

| Image | Logical size | Runtime versions | Git | Smoke test |
|---|---:|---|---|---|
| `ci-node22` | 321,727,304 bytes (306.8 MiB) | Node.js 22.23.2, npm 10.9.8 | 2.39.5 | passed, including excluded-tool checks |
| `ci-python312` | 208,552,705 bytes (198.9 MiB) | Python 3.12.14, pip 25.0.1, working `venv` | 2.39.5 | passed, including excluded-tool checks |

Installing the exact `last-diagrams` Python requirements from the analysis ref and importing Flask, MSS, Pillow and PyYAML also passed. Those packages remain consumer dependencies and are not part of the shared image.

### Current validated release

Published and validated by workflow run `33247299035` from `ci-images` commit `dd0a13e97fcdb2819756a98ce400ef3101eeccd9`:

| Image | Immutable commit tag | Preferred digest reference |
|---|---|---|
| Node.js 22 | `ghcr.io/jacekkardys/ci-node22:sha-dd0a13e97fcdb2819756a98ce400ef3101eeccd9` | `ghcr.io/jacekkardys/ci-node22@sha256:c56d483456faa28229c08d588bda41432827619bbc96ef946e1983358a773a87` |
| Python 3.12 | `ghcr.io/jacekkardys/ci-python312:sha-dd0a13e97fcdb2819756a98ce400ef3101eeccd9` | `ghcr.io/jacekkardys/ci-python312@sha256:1d8329c0f27a9f2402d4aa07be2150547a07d9102d40e78ae9e8e19e5185db6a` |

Both packages are private. Unauthenticated pulls correctly fail; consumers need `packages: read` and explicit package access.

## Why these boundaries

`last-diagrams` has many Node-only jobs, three Python-only jobs, one browser job that needs Node and one browser job that needs Node plus Python. It has no Java, Gradle, Maven or JDK job.

Node and Python change independently, have independent upstream bases and are used separately by almost all jobs. Combining them would increase transfer size and attack surface for every job without removing meaningful setup from more than one consumer.

The mixed `studio-browser` job is not sufficient reason for a combined image. Browser dependencies dominate its environment. The pinned upstream Playwright image is about 2.49 GB logical size and already owns the browser/system-library compatibility contract. Wrapping it would duplicate a large image and couple browser updates to this repository. The browser jobs should continue to run the trusted upstream image directly while the host workflow supplies the exact Node/Python runtimes required by the application.

No Docker image is provided. `root-tests` uses a GitHub Actions PostgreSQL service, not Testcontainers. Browser jobs invoke the host daemon explicitly. Adding Docker CLI or the Docker socket to every toolchain would increase privilege and attack surface for jobs that do not need it.

## `last-diagrams` CI requirements

The table separates toolchain setup from dependency installation and build/test execution. `setup-*` installs runtimes; `npm ci` and `pip install` restore application dependencies and remain repository-owned.

| Workflow / job | Runner at analysis ref | Current job container | Toolchains and package managers | Docker / services | Browser / native requirements | Setup versus execution |
|---|---|---|---|---|---|---|
| Verify / `static-contracts` | self-hosted Linux x64 proart | none | Node 22, npm | none | none | `setup-node`; `npm ci`; contract/data checks |
| Verify / `lint-typecheck` | self-hosted Linux x64 proart | none | Node 22, npm | none | none | `setup-node`; `npm ci`; generation, lint, typecheck |
| Verify / `root-tests` | self-hosted Linux x64 proart | none | Node 22, npm | PostgreSQL 18 Actions service | PostgreSQL client is an npm dependency | `setup-node`; `npm ci`; generation, migration, tests |
| Verify / `runtime-core` | self-hosted Linux x64 proart | none | Python 3.12, pip, venv | none | Python packages from `tools/automation-runtime/requirements.txt` | `setup-python`; pip install; runtime and LastZ target tests |
| Verify / `runtime-visual-calibration` | self-hosted Linux x64 proart | none | Python 3.12, pip, venv | none | capture/visual Python packages | `setup-python`; pip install; visual/calibration tests |
| Verify / `runtime-studio-execution` | self-hosted Linux x64 proart | none | Python 3.12, pip, venv | none | capture/runtime Python packages | `setup-python`; pip install; studio/execution tests |
| Verify / `automation-studio` | self-hosted Linux x64 proart | none | Node 22, npm | none | none | `setup-node`; `npm ci`; workspace tests |
| Verify / `build` | self-hosted Linux x64 proart | none | Node 22, npm | none | none | `setup-node`; `npm ci`; TypeScript/Vite build |
| Verify / `auth-browser` | self-hosted Linux x64 proart | pinned Playwright child container | Node 22, npm | host Docker daemon invokes Playwright | Chromium from `mcr.microsoft.com/playwright:v1.62.1-noble@sha256:c091b21d9fae78c76e85cd4356431e9b018402f172a214fc7d7a5e9a7e29d8ac` | `setup-node`; `npm ci`; built-app auth smoke |
| Verify / `studio-browser` | self-hosted Linux x64 proart | pinned Playwright child container | Node 22/npm plus Python 3.12/pip/venv | host Docker daemon invokes Playwright | Chromium plus capture/runtime Python packages | both setup actions; npm/pip install; Studio smoke |
| Verify / `windows-capture-storage` | GitHub-hosted Windows | none | Python 3.12, pip | none | `pywin32` is Windows-only | `setup-python`; pip install; focused Windows tests |
| Verify / `quality` | self-hosted Linux x64 proart | none | shell only | none | none | aggregates prior job conclusions |
| Backup / `backup` | GitHub-hosted Ubuntu | none | Node 22 for manifest generation | Docker CLI/socket; PostgreSQL 18 child containers | GPG, OpenSSL, `gh`, core utilities | `setup-node`; dump, restore-check, encrypt, upload/prune |
| Deploy / `deploy` | GitHub-hosted Ubuntu | none | no language runtime | none | `gh` and curl | resolve a SHA and invoke Render hook |
| Release / `verify` | GitHub-hosted Ubuntu | none | Node 22, npm | PostgreSQL 18 Actions service | Playwright Chromium, `gh`, tar, SHA utilities | `setup-node`; npm install; verify/build/browser/package |
| Release / `publish-and-deploy` | GitHub-hosted Ubuntu | none | Node 22, npm | Docker CLI/socket; PostgreSQL 18 child containers | GPG, OpenSSL, `gh`, curl | `setup-node`; backup, npm install, migrate, release, deploy |

There are no Testcontainers jobs. PostgreSQL is either an Actions service or an explicitly invoked `postgres:18-alpine` child container. There are no Kafka, Redis or CUDA requirements in the analyzed workflows.

Recent self-hosted runs show runtime setup is material: `setup-node` commonly takes roughly 25–44 seconds when four runners execute concurrently, and `setup-python` roughly 17–29 seconds. A cold earlier job recorded 67 seconds for Node setup and 112 seconds for Python setup. Dependency installation is separate and often only 1–5 seconds once the host caches are warm. The large Playwright pull is shared by all four runner processes through the single host Docker daemon after the first pull.

## Local build and smoke tests

Build:

```bash
docker build --tag ci-node22:local node22
docker build --tag ci-python312:local python312
```

Smoke test Node.js:

```bash
docker run --rm ci-node22:local sh -ceu 'node --version; npm --version; git --version; test "$(uname -m)" = x86_64'
```

Smoke test Python:

```bash
docker run --rm ci-python312:local sh -ceu 'python3 --version; pip --version; git --version; python3 -m venv /tmp/venv; /tmp/venv/bin/python --version; test "$(uname -m)" = x86_64'
```

The publishing workflow performs stronger smoke tests, including major/minor version assertions and checks that excluded toolchains did not enter either image.

## Publishing and versioning

Pull requests build and smoke-test both images but do not publish. A change to a Dockerfile or the workflow on `main` runs on `[self-hosted, linux, x64, proart]`, builds the image, runs its smoke test, inspects it, then authenticates to GHCR with `GITHUB_TOKEN` and `packages: write`.

Runner registration is repository-scoped in the current personal-account setup. The four permanent ProArt runners belong to `last-diagrams` and are not visible to `ci-images`. The first release used two checksum-verified, ephemeral Linux runners on the same host; they automatically unregistered after the successful jobs. Before the next image change, either register a dedicated `ci-images` runner or move both repositories and the runners under an organization-level runner scope. Do not reassign the existing four and silently remove capacity from `last-diagrams`.

Each validated `main` build publishes:

- `:1` — moving image contract line;
- `:sha-<full-ci-images-commit>` — immutable build identity;
- a registry digest — preferred final consumer pin.

The toolchain version is part of the image name (`node22`, `python312`). The tag `1` is the image contract revision and does not imply Node 1 or Python 1. A future incompatible image contract uses tag line `2`; a future runtime uses another explicit image name. No `latest` tag is published.

The Dockerfiles pin upstream tags and digests. Updating a base is a deliberate Dockerfile change that rebuilds and smoke-tests the image. OCI source, revision, creation time, version and base metadata are attached after the stable OS/toolchain installation layer so per-build metadata does not invalidate package-install caching.

For another private repository to consume private GHCR packages, grant that repository read access in each package's settings and add `packages: read` to its workflow permissions.

## Proposed `last-diagrams` migration (not applied)

Use the current immutable digests recorded under **Current validated release**.

### Node-only jobs

Apply this container to `static-contracts`, `lint-typecheck`, `automation-studio` and `build`, then remove their `actions/setup-node` steps. Keep checkout, `npm ci` and all repository commands.

```yaml
permissions:
  contents: read
  packages: read

jobs:
  static_contracts:
    runs-on: [self-hosted, linux, x64, proart]
    container:
      image: ghcr.io/jacekkardys/ci-node22@sha256:c56d483456faa28229c08d588bda41432827619bbc96ef946e1983358a773a87
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      # Existing repository verification steps remain unchanged.
```

`root-tests` can use the same image, but a job container reaches its Actions service by service name, not `127.0.0.1`. Remove `setup-node`, keep the PostgreSQL service and change only the connection host:

```yaml
root_tests:
  runs-on: [self-hosted, linux, x64, proart]
  container:
    image: ghcr.io/jacekkardys/ci-node22@sha256:c56d483456faa28229c08d588bda41432827619bbc96ef946e1983358a773a87
    credentials:
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}
  env:
    TEST_DATABASE_URL: postgresql://kls:kls-test-password@postgres:5432/kls_auth_test
    DATABASE_MIGRATION_URL: postgresql://kls:kls-test-password@postgres:5432/kls_auth_test
  services:
    postgres:
      image: postgres:18-alpine
      env:
        POSTGRES_USER: kls
        POSTGRES_PASSWORD: kls-test-password
        POSTGRES_DB: kls_auth_test
      options: >-
        --health-cmd "pg_isready -U kls -d kls_auth_test"
        --health-interval 5s
        --health-timeout 5s
        --health-retries 10
```

The host port mapping becomes unnecessary in a job-container network. No Docker socket is required by the job container; Actions owns service lifecycle.

### Python-only jobs

Apply this container to `runtime-core`, `runtime-visual-calibration` and `runtime-studio-execution`. Remove `actions/setup-python`. Keep venv creation, pip installation and all tests because Python packages are application dependencies.

```yaml
automation_runtime_core:
  runs-on: [self-hosted, linux, x64, proart]
  container:
    image: ghcr.io/jacekkardys/ci-python312@sha256:1d8329c0f27a9f2402d4aa07be2150547a07d9102d40e78ae9e8e19e5185db6a
    credentials:
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}
  steps:
    - uses: actions/checkout@v4
    - name: Install LastZ capture dependencies
      run: |
        python -m venv .local/automation-runtime/venv
        .local/automation-runtime/venv/bin/python -m pip install -r tools/automation-runtime/requirements.txt
    # Existing runtime tests remain unchanged.
```

### Jobs that should not use these images

- `auth-browser`: keep it host-executed with Node 22 and invoke the exact pinned Microsoft Playwright image. This avoids adding Docker CLI/socket/browser libraries to `ci-node22`.
- `studio-browser`: keep it host-executed with Node 22 and Python 3.12, mounting those setup-action runtimes read-only into the exact pinned Playwright container. This is the only mixed-toolchain job.
- `windows-capture-storage`: keep GitHub-hosted Windows and `setup-python`; Linux containers cannot satisfy `pywin32` or the Windows behavior contract.
- `quality`: keep host-executed; it needs only the runner shell and should not pull a language image.
- production backup/deploy/release jobs: keep host-executed for the first migration. They require combinations of `gh`, Docker, GPG, OpenSSL, curl, PostgreSQL utilities or Playwright that the two narrow images deliberately exclude. Migrate these separately only after the verification jobs establish a measured baseline.

For the browser jobs, the upstream image remains:

```yaml
env:
  PLAYWRIGHT_IMAGE: mcr.microsoft.com/playwright:v1.62.1-noble@sha256:c091b21d9fae78c76e85cd4356431e9b018402f172a214fc7d7a5e9a7e29d8ac
```

Access to `/var/run/docker.sock` is effectively host-root privilege. The current trusted private-repository assumption makes the browser-child-container approach acceptable, but the socket must remain limited to the host-executed jobs that invoke Docker. It must not be mounted into ordinary Node or Python jobs.

### Migration acceptance criteria

1. GHCR package access is granted to `last-diagrams`, and both digests pull on the ProArt host.
2. One Node-only and one Python-only job first prove container startup, checkout and workspace write permissions.
3. `root-tests` proves PostgreSQL access through hostname `postgres` without a host port mapping.
4. All removed setup steps are limited to the runtime already present in the selected image; `npm ci`, venv creation and pip install remain.
5. Browser, Windows and production jobs retain their existing execution boundary.
6. Exact-head Verify finishes successfully and timing is compared with the pre-image baseline before any cache work.

## Deferred optimizations

- Gradle, Maven, npm, pnpm, yarn and pip cache redesign
- shared `RUNNER_TOOL_CACHE`
- Docker registry mirror or local/NAS registry
- checkout mirrors or pre-cloned repositories
- workspace sharing between runner processes
- CUDA/GPU profiles
- ARM/multi-architecture builds
- a Docker-enabled or mixed Node/Python profile

## Verdict

The two-image platform removes repeated installation of the expensive stable Node and Python runtimes from ten Linux verification jobs while preserving repository-owned dependency installation and using the existing shared Docker daemon layer cache. It improves startup determinism without introducing a universal image, browser wrapper, Docker-in-Docker or application coupling.

After integration, the next single optimization should be measuring and then addressing checkout duplication across the four runner processes. Dependency-cache redesign should follow only after the image-only baseline is recorded.

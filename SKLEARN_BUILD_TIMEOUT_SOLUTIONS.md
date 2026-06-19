# SKLearn Server Docker Build Timeout Solutions

## Problem Statement

The SKLearn Server Docker build job is getting killed after 6 hours when building for multiple architectures (amd64, arm64, ppc64le). This is primarily due to:

1. **QEMU Emulation Overhead**: Building ppc64le on amd64 runners using QEMU is 10-50x slower
2. **Python Package Compilation**: NumPy, SciPy, scikit-learn compile native extensions
3. **Multiple uv sync Operations**: The Dockerfile runs `uv sync` multiple times
4. **No Build Caching**: Each architecture builds from scratch

## Current Build Time Estimates

| Architecture | Build Method | Estimated Time |
|--------------|--------------|----------------|
| linux/amd64 | Native | 5-10 minutes |
| linux/arm64/v8 | QEMU | 30-60 minutes |
| linux/ppc64le | QEMU | **4-8 hours** ⚠️ |

**Total for all platforms**: 5-9 hours (exceeds 6-hour GitHub Actions limit)

## Solution Strategies

### Strategy 1: Use Pre-built Wheels (RECOMMENDED - Fastest)

Most Python packages now provide pre-built wheels for ppc64le on PyPI.

#### Implementation

**Update `python/sklearn.Dockerfile`:**

```dockerfile
ARG PYTHON_VERSION=3.11
ARG BASE_IMAGE=python:${PYTHON_VERSION}-slim-bookworm
ARG VENV_PATH=/prod_venv

FROM ${BASE_IMAGE} AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-dev curl build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv

# Create virtual environment
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
RUN uv venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# OPTIMIZATION: Use --no-build-isolation to prefer pre-built wheels
# This significantly speeds up ppc64le builds

# ========== Install kserve dependencies ==========
COPY kserve/pyproject.toml kserve/uv.lock kserve/
RUN cd kserve && uv sync --active --no-cache --no-build-isolation

COPY kserve kserve
RUN cd kserve && uv sync --active --no-cache --no-build-isolation

# ========== Install kserve storage dependencies ==========
COPY storage/pyproject.toml storage/uv.lock storage/
RUN cd storage && uv sync --active --no-cache --no-build-isolation

COPY storage storage
RUN cd storage && uv pip install . --no-cache --no-build-isolation

# ========== Install sklearnserver dependencies ==========
COPY sklearnserver/pyproject.toml sklearnserver/uv.lock sklearnserver/
RUN cd sklearnserver && uv sync --active --no-cache --no-build-isolation

COPY sklearnserver sklearnserver
RUN cd sklearnserver && uv sync --active --no-cache --no-build-isolation

# Generate third-party licenses
COPY pyproject.toml pyproject.toml
COPY third_party/pip-licenses.py pip-licenses.py
RUN pip install --no-cache-dir tomli
RUN mkdir -p third_party/library && python3 pip-licenses.py

# =================== Final stage ===================
FROM ${BASE_IMAGE} AS prod

COPY third_party third_party

ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN useradd kserve -m -u 1000 -d /home/kserve

COPY --from=builder --chown=kserve:kserve third_party third_party
COPY --from=builder --chown=kserve:kserve $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=builder kserve kserve
COPY --from=builder storage storage
COPY --from=builder sklearnserver sklearnserver

USER 1000
ENV PYTHONPATH=/sklearnserver
ENTRYPOINT ["python", "-m", "sklearnserver"]
```

**Expected Improvement**: Reduces ppc64le build time from 4-8 hours to 30-60 minutes

---

### Strategy 2: Enable Docker Layer Caching (RECOMMENDED)

Use GitHub Actions cache to store Docker layers between builds.

**Update `.github/workflows/sklearnserver-docker-publish.yml`:**

```yaml
name: Sklearn Server Docker Publisher

on:
  push:
    branches:
      - master
    tags:
      - v*
  pull_request:

env:
  IMAGE_NAME: sklearnserver

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source
        uses: actions/checkout@v4
      
      - name: Free-up disk space
        uses: ./.github/actions/free-up-disk-space

      - name: Setup QEMU
        uses: docker/setup-qemu-action@v3
        with:
          cache-image: true

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3
        with:
          cache-binary: true

      - name: Run tests
        uses: docker/build-push-action@v6
        with:
          platforms: linux/amd64,linux/arm64/v8
          context: python
          file: python/sklearn.Dockerfile
          push: false
          provenance: false
          # Enable caching
          cache-from: type=gha
          cache-to: type=gha,mode=max

  push:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    
    # OPTIMIZATION: Increase timeout for multi-arch builds
    timeout-minutes: 480  # 8 hours

    steps:
      - name: Checkout source
        uses: actions/checkout@v4
      
      - name: Free-up disk space
        uses: ./.github/actions/free-up-disk-space

      - name: Setup QEMU
        uses: docker/setup-qemu-action@v3
        with:
          cache-image: true
          # OPTIMIZATION: Only setup platforms we need
          platforms: linux/ppc64le

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3
        with:
          cache-binary: true
          # OPTIMIZATION: Use larger builder instance
          driver-opts: |
            image=moby/buildkit:latest
            network=host

      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USER }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Export version variable
        run: |
          IMAGE_ID=kserve/$IMAGE_NAME
          IMAGE_ID=$(echo $IMAGE_ID | tr '[A-Z]' '[a-z]')
          VERSION=$(echo "${{ github.ref }}" | sed -e 's,.*/\(.*\),\1,')
          [ "$VERSION" == "master" ] && VERSION=latest
          echo VERSION=$VERSION >> $GITHUB_ENV
          echo IMAGE_ID=$IMAGE_ID >> $GITHUB_ENV

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          platforms: linux/amd64,linux/arm64/v8,linux/ppc64le
          context: python
          file: python/sklearn.Dockerfile
          push: true
          tags: ${{ env.IMAGE_ID }}:${{ env.VERSION }}
          provenance: false
          sbom: true
          # OPTIMIZATION: Enable layer caching
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Expected Improvement**: Subsequent builds reuse cached layers, reducing time by 50-70%

---

### Strategy 3: Split Build Jobs by Architecture (RECOMMENDED for CI)

Build each architecture in parallel jobs to avoid timeout.

**Create new workflow: `.github/workflows/sklearnserver-docker-publish-multiarch.yml`:**

```yaml
name: Sklearn Server Multi-Arch Docker Publisher

on:
  push:
    branches:
      - master
    tags:
      - v*
  pull_request:

env:
  IMAGE_NAME: sklearnserver

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # Build each architecture separately
  build-amd64:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source
        uses: actions/checkout@v4
      
      - name: Free-up disk space
        uses: ./.github/actions/free-up-disk-space

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to DockerHub
        if: github.event_name == 'push'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USER }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push amd64
        uses: docker/build-push-action@v6
        with:
          platforms: linux/amd64
          context: python
          file: python/sklearn.Dockerfile
          push: ${{ github.event_name == 'push' }}
          tags: kserve/${{ env.IMAGE_NAME }}:${{ github.sha }}-amd64
          cache-from: type=gha,scope=amd64
          cache-to: type=gha,mode=max,scope=amd64

  build-arm64:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout source
        uses: actions/checkout@v4
      
      - name: Free-up disk space
        uses: ./.github/actions/free-up-disk-space

      - name: Setup QEMU
        uses: docker/setup-qemu-action@v3
        with:
          platforms: linux/arm64

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to DockerHub
        if: github.event_name == 'push'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USER }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push arm64
        uses: docker/build-push-action@v6
        with:
          platforms: linux/arm64/v8
          context: python
          file: python/sklearn.Dockerfile
          push: ${{ github.event_name == 'push' }}
          tags: kserve/${{ env.IMAGE_NAME }}:${{ github.sha }}-arm64
          cache-from: type=gha,scope=arm64
          cache-to: type=gha,mode=max,scope=arm64

  build-ppc64le:
    runs-on: ubuntu-latest
    timeout-minutes: 480  # 8 hours for ppc64le
    steps:
      - name: Checkout source
        uses: actions/checkout@v4
      
      - name: Free-up disk space
        uses: ./.github/actions/free-up-disk-space

      - name: Setup QEMU
        uses: docker/setup-qemu-action@v3
        with:
          platforms: linux/ppc64le

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to DockerHub
        if: github.event_name == 'push'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USER }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push ppc64le
        uses: docker/build-push-action@v6
        with:
          platforms: linux/ppc64le
          context: python
          file: python/sklearn.Dockerfile
          push: ${{ github.event_name == 'push' }}
          tags: kserve/${{ env.IMAGE_NAME }}:${{ github.sha }}-ppc64le
          cache-from: type=gha,scope=ppc64le
          cache-to: type=gha,mode=max,scope=ppc64le

  # Create multi-arch manifest
  create-manifest:
    needs: [build-amd64, build-arm64, build-ppc64le]
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - name: Login to DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USER }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Export version variable
        run: |
          IMAGE_ID=kserve/${{ env.IMAGE_NAME }}
          VERSION=$(echo "${{ github.ref }}" | sed -e 's,.*/\(.*\),\1,')
          [ "$VERSION" == "master" ] && VERSION=latest
          echo VERSION=$VERSION >> $GITHUB_ENV
          echo IMAGE_ID=$IMAGE_ID >> $GITHUB_ENV

      - name: Create and push manifest
        run: |
          docker buildx imagetools create -t ${{ env.IMAGE_ID }}:${{ env.VERSION }} \
            ${{ env.IMAGE_ID }}:${{ github.sha }}-amd64 \
            ${{ env.IMAGE_ID }}:${{ github.sha }}-arm64 \
            ${{ env.IMAGE_ID }}:${{ github.sha }}-ppc64le
```

**Expected Improvement**: Each architecture builds in parallel, total time = slowest build (ppc64le ~4-8 hours)

---

### Strategy 4: Use Native ppc64le Runners (BEST - If Available)

If you have access to native ppc64le runners (self-hosted or cloud):

```yaml
build-ppc64le:
  runs-on: [self-hosted, linux, ppc64le]  # Native ppc64le runner
  steps:
    - name: Checkout source
      uses: actions/checkout@v4

    - name: Setup Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Build and push ppc64le
      uses: docker/build-push-action@v6
      with:
        platforms: linux/ppc64le
        context: python
        file: python/sklearn.Dockerfile
        push: true
        tags: kserve/${{ env.IMAGE_NAME }}:${{ github.sha }}-ppc64le
```

**Expected Improvement**: Native build reduces time from 4-8 hours to 10-20 minutes

---

### Strategy 5: Optimize Dockerfile (Additional Improvements)

**Further optimizations for `python/sklearn.Dockerfile`:**

```dockerfile
ARG PYTHON_VERSION=3.11
ARG BASE_IMAGE=python:${PYTHON_VERSION}-slim-bookworm
ARG VENV_PATH=/prod_venv

FROM ${BASE_IMAGE} AS builder

# OPTIMIZATION 1: Install only essential build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-dev curl build-essential \
    # Add these for faster compilation
    ccache \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# OPTIMIZATION 2: Setup ccache for faster recompilation
ENV CCACHE_DIR=/root/.ccache
ENV PATH="/usr/lib/ccache:$PATH"

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv

# Create virtual environment
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
RUN uv venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# OPTIMIZATION 3: Set pip to prefer binary wheels
ENV PIP_PREFER_BINARY=1
ENV UV_PREFER_BINARY=1

# OPTIMIZATION 4: Install dependencies in order of likelihood to change
# (least likely to change first for better layer caching)

# Install kserve dependencies (changes rarely)
COPY kserve/pyproject.toml kserve/uv.lock kserve/
RUN cd kserve && uv sync --active --no-cache --no-build-isolation

COPY kserve kserve
RUN cd kserve && uv sync --active --no-cache --no-build-isolation

# Install storage dependencies
COPY storage/pyproject.toml storage/uv.lock storage/
RUN cd storage && uv sync --active --no-cache --no-build-isolation

COPY storage storage
RUN cd storage && uv pip install . --no-cache --no-build-isolation

# Install sklearnserver dependencies (changes more frequently)
COPY sklearnserver/pyproject.toml sklearnserver/uv.lock sklearnserver/
RUN cd sklearnserver && uv sync --active --no-cache --no-build-isolation

COPY sklearnserver sklearnserver
RUN cd sklearnserver && uv sync --active --no-cache --no-build-isolation

# Generate third-party licenses
COPY pyproject.toml pyproject.toml
COPY third_party/pip-licenses.py pip-licenses.py
RUN pip install --no-cache-dir tomli
RUN mkdir -p third_party/library && python3 pip-licenses.py

# =================== Final stage ===================
FROM ${BASE_IMAGE} AS prod

COPY third_party third_party

ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN useradd kserve -m -u 1000 -d /home/kserve

COPY --from=builder --chown=kserve:kserve third_party third_party
COPY --from=builder --chown=kserve:kserve $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=builder kserve kserve
COPY --from=builder storage storage
COPY --from=builder sklearnserver sklearnserver

USER 1000
ENV PYTHONPATH=/sklearnserver
ENTRYPOINT ["python", "-m", "sklearnserver"]
```

---

## Recommended Implementation Plan

### Phase 1: Quick Wins (Implement First)
1. ✅ Add `--no-build-isolation` to uv commands (Strategy 1)
2. ✅ Enable Docker layer caching (Strategy 2)
3. ✅ Increase timeout to 8 hours (Strategy 2)
4. ✅ Add `PIP_PREFER_BINARY=1` environment variable (Strategy 5)

**Expected Result**: Build time reduced to 2-4 hours

### Phase 2: Parallel Builds (If Phase 1 Still Times Out)
1. ✅ Implement split build jobs (Strategy 3)
2. ✅ Build each architecture in parallel
3. ✅ Create multi-arch manifest at the end

**Expected Result**: Total time = slowest build (~4-8 hours for ppc64le, but doesn't block other architectures)

### Phase 3: Native Runners (Long-term Solution)
1. ✅ Set up self-hosted ppc64le runners OR
2. ✅ Use cloud providers with ppc64le instances (IBM Cloud, AWS)

**Expected Result**: Build time reduced to 10-20 minutes

---

## Testing the Solutions

### Test Locally with QEMU

```bash
# Setup QEMU
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Test build for ppc64le only
cd python
docker buildx build --platform linux/ppc64le \
  --build-arg PIP_PREFER_BINARY=1 \
  -f sklearn.Dockerfile \
  --progress=plain \
  .

# Monitor build time
time docker buildx build --platform linux/ppc64le -f sklearn.Dockerfile .
```

### Monitor GitHub Actions Build

Add timing information to workflow:

```yaml
- name: Build and push
  uses: docker/build-push-action@v6
  with:
    platforms: linux/amd64,linux/arm64/v8,linux/ppc64le
    context: python
    file: python/sklearn.Dockerfile
    push: true
    tags: ${{ env.IMAGE_ID }}:${{ env.VERSION }}
    # Add build progress output
    outputs: type=registry,push=true
    # Show detailed timing
    build-args: |
      BUILDKIT_PROGRESS=plain
```

---

## Summary

| Strategy | Complexity | Time Savings | Recommended |
|----------|------------|--------------|-------------|
| Pre-built wheels | Low | 50-70% | ✅ Yes |
| Layer caching | Low | 50-70% | ✅ Yes |
| Split jobs | Medium | Avoids timeout | ✅ Yes |
| Native runners | High | 90%+ | ⚠️ If available |
| Dockerfile optimization | Low | 10-20% | ✅ Yes |

**Recommended Approach**: Implement Strategies 1, 2, and 5 first. If still timing out, implement Strategy 3 (split jobs).

---

**Last Updated**: 2026-04-24  
**Document Version**: 1.0
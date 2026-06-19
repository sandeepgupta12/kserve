# KServe Power (ppc64le) Images - Location Guide

This document shows you where to find the pre-built ppc64le images for all KServe Go-based components.

## Docker Hub Repository

All KServe images are published to Docker Hub under the **`kserve`** organization:
- **Base URL**: https://hub.docker.com/u/kserve

## Go-Based Components with ppc64le Support

### 1. KServe Controller
- **Docker Hub**: https://hub.docker.com/r/kserve/kserve-controller
- **Image Name**: `kserve/kserve-controller`
- **Pull Command**:
  ```bash
  docker pull kserve/kserve-controller:latest
  ```
- **Supported Architectures**: 
  - linux/amd64
  - linux/arm/v7
  - linux/arm64/v8
  - **linux/ppc64le** ✅
  - linux/s390x

### 2. Agent
- **Docker Hub**: https://hub.docker.com/r/kserve/agent
- **Image Name**: `kserve/agent`
- **Pull Command**:
  ```bash
  docker pull kserve/agent:latest
  ```
- **Supported Architectures**: 
  - linux/amd64
  - linux/arm/v7
  - linux/arm64/v8
  - **linux/ppc64le** ✅
  - linux/s390x

### 3. Router
- **Docker Hub**: https://hub.docker.com/r/kserve/router
- **Image Name**: `kserve/router`
- **Pull Command**:
  ```bash
  docker pull kserve/router:latest
  ```
- **Supported Architectures**: 
  - linux/amd64
  - linux/arm/v7
  - linux/arm64/v8
  - **linux/ppc64le** ✅
  - linux/s390x

### 4. LLM Inference Service Controller
- **Docker Hub**: https://hub.docker.com/r/kserve/llmisvc-controller
- **Image Name**: `kserve/llmisvc-controller`
- **Pull Command**:
  ```bash
  docker pull kserve/llmisvc-controller:latest
  ```
- **Supported Architectures**: 
  - linux/amd64
  - linux/arm/v7
  - linux/arm64/v8
  - **linux/ppc64le** ✅
  - linux/s390x

### 5. Queue Proxy Extension (QPExt)
- **Docker Hub**: https://hub.docker.com/r/kserve/qpext
- **Image Name**: `kserve/qpext`
- **Pull Command**:
  ```bash
  docker pull kserve/qpext:latest
  ```
- **Supported Architectures**: 
  - linux/amd64
  - linux/arm/v7
  - linux/arm64/v8
  - **linux/ppc64le** ✅
  - linux/s390x

### 6. LocalModel Node Agent
- **Docker Hub**: https://hub.docker.com/r/kserve/kserve-localmodelnode-agent
- **Image Name**: `kserve/kserve-localmodelnode-agent`
- **Pull Command**:
  ```bash
  docker pull kserve/kserve-localmodelnode-agent:latest
  ```
- **Supported Architectures**: 
  - linux/amd64
  - linux/arm/v7
  - linux/arm64/v8
  - **linux/ppc64le** ✅
  - linux/s390x

### 7. LocalModel Controller
- **Docker Hub**: https://hub.docker.com/r/kserve/kserve-localmodel-controller
- **Image Name**: `kserve/kserve-localmodel-controller`
- **Pull Command**:
  ```bash
  docker pull kserve/kserve-localmodel-controller:latest
  ```
- **Supported Architectures**: 
  - linux/amd64
  - linux/arm/v7
  - linux/arm64/v8
  - **linux/ppc64le** ✅
  - linux/s390x

## How to Verify ppc64le Support

### Method 1: Using Docker Manifest (Recommended)

Check the available architectures for any image:

```bash
# Example: Check KServe Controller
docker manifest inspect kserve/kserve-controller:latest | grep -A 5 "architecture"

# Example: Check Agent
docker manifest inspect kserve/agent:latest | grep -A 5 "architecture"
```

You should see output like:
```json
"architecture": "ppc64le",
"os": "linux"
```

### Method 2: Using Docker Buildx

```bash
docker buildx imagetools inspect kserve/kserve-controller:latest
```

This will show all available platforms including `linux/ppc64le`.

### Method 3: Pull on ppc64le System

On an actual Power system:
```bash
# Docker will automatically pull the ppc64le variant
docker pull kserve/kserve-controller:latest
docker inspect kserve/kserve-controller:latest | grep Architecture
```

## Pulling Specific Architecture

If you want to explicitly pull the ppc64le version (useful for testing with QEMU):

```bash
# Pull ppc64le variant explicitly
docker pull --platform linux/ppc64le kserve/kserve-controller:latest

# Verify the architecture
docker inspect kserve/kserve-controller:latest | grep Architecture
# Should output: "Architecture": "ppc64le"
```

## Version Tags

All components support version tags. Replace `latest` with specific versions:

```bash
# Example with version tag
docker pull kserve/kserve-controller:v0.13.0
docker pull kserve/agent:v0.13.0
docker pull kserve/router:v0.13.0
```

## CI/CD Build Information

These images are automatically built by GitHub Actions:

| Component | Workflow File | Trigger |
|-----------|---------------|---------|
| KServe Controller | `.github/workflows/kserve-controller-docker-publish.yml` | Push to master, version tags |
| Agent | `.github/workflows/agent-docker-publish.yml` | Push to master, version tags |
| Router | `.github/workflows/router-docker-publish.yml` | Push to master, version tags |
| LLM Controller | `.github/workflows/kserve-llmisvc-controller-docker-publish.yml` | Push to master, version tags |
| QPExt | `.github/workflows/qpext-docker-publish.yml` | Push to master, version tags |
| LocalModel Agent | `.github/workflows/kserve-localmodel-agent-docker-publish.yml` | Push to master, version tags |
| LocalModel Controller | `.github/workflows/kserve-localmodel-controller-docker-publish.yml` | Push to master, version tags |

## Testing ppc64le Images Locally (with QEMU)

If you don't have a Power system, you can test ppc64le images using QEMU emulation:

### Setup QEMU
```bash
# Install QEMU
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Verify QEMU is working
docker run --rm --platform linux/ppc64le alpine uname -m
# Should output: ppc64le
```

### Test KServe Components
```bash
# Pull and run ppc64le variant
docker run --rm --platform linux/ppc64le kserve/kserve-controller:latest --version

# Test agent
docker run --rm --platform linux/ppc64le kserve/agent:latest --help

# Test router
docker run --rm --platform linux/ppc64le kserve/router:latest --help
```

## Python-Based Components (NOT YET AVAILABLE for ppc64le)

The following components currently only support `linux/amd64` and `linux/arm64/v8`:

❌ **Not yet available for ppc64le:**
- `kserve/sklearnserver`
- `kserve/xgbserver`
- `kserve/lgbserver`
- `kserve/pmmlserver`
- `kserve/paddleserver`
- `kserve/huggingfaceserver`
- `kserve/storage-initializer`
- `kserve/art-explainer`
- And other Python-based serving runtimes

**These are the components that need to be ported** as outlined in the main porting plan.

## Quick Reference Table

| Component | Docker Hub URL | ppc64le Support | Python/Go |
|-----------|----------------|-----------------|-----------|
| kserve-controller | hub.docker.com/r/kserve/kserve-controller | ✅ Yes | Go |
| agent | hub.docker.com/r/kserve/agent | ✅ Yes | Go |
| router | hub.docker.com/r/kserve/router | ✅ Yes | Go |
| llmisvc-controller | hub.docker.com/r/kserve/llmisvc-controller | ✅ Yes | Go |
| qpext | hub.docker.com/r/kserve/qpext | ✅ Yes | Go |
| localmodelnode-agent | hub.docker.com/r/kserve/kserve-localmodelnode-agent | ✅ Yes | Go |
| localmodel-controller | hub.docker.com/r/kserve/kserve-localmodel-controller | ✅ Yes | Go |
| sklearnserver | hub.docker.com/r/kserve/sklearnserver | ❌ No | Python |
| xgbserver | hub.docker.com/r/kserve/xgbserver | ❌ No | Python |
| lgbserver | hub.docker.com/r/kserve/lgbserver | ❌ No | Python |
| storage-initializer | hub.docker.com/r/kserve/storage-initializer | ❌ No | Python |
| huggingfaceserver | hub.docker.com/r/kserve/huggingfaceserver | ❌ No | Python |

## Deployment on Power Systems

When deploying KServe on a Power (ppc64le) system:

1. **Controller components will work out of the box** - They already have ppc64le images
2. **Python serving runtimes will NOT work** - Need to wait for ppc64le support or build locally

### Example Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kserve-controller
spec:
  template:
    spec:
      containers:
      - name: manager
        image: kserve/kserve-controller:latest
        # Docker will automatically pull ppc64le variant on Power systems
```

## Summary

✅ **Available NOW for ppc64le:**
- All 7 Go-based components (Controller, Agent, Router, LLM Controller, QPExt, LocalModel x2)
- Published to Docker Hub
- Built automatically via GitHub Actions
- Support 5 architectures including ppc64le and s390x

❌ **Not yet available for ppc64le:**
- All Python-based serving runtimes
- These are the focus of the porting effort

## Additional Resources

- **KServe Docker Hub**: https://hub.docker.com/u/kserve
- **KServe GitHub**: https://github.com/kserve/kserve
- **Multi-arch Docker Guide**: https://docs.docker.com/build/building/multi-platform/
- **QEMU Setup**: https://github.com/multiarch/qemu-user-static

---

**Last Updated**: 2026-04-23  
**Document Version**: 1.0
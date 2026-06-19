# KServe Power (ppc64le) Architecture Porting Plan

## Executive Summary

This document outlines the comprehensive plan to add IBM Power (ppc64le) architecture support to KServe. The plan covers all components, infrastructure changes, testing strategy, and upstream contribution approach.

## Current State Analysis

### Existing Architecture Support

Based on the codebase analysis:

**Go Components (Controller):**
- Current support: `linux/amd64`, `linux/arm/v7`, `linux/arm64/v8`, `linux/ppc64le`, `linux/s390x`
- ✅ **KServe Controller already supports ppc64le** (see `.github/workflows/kserve-controller-docker-publish.yml:99`)

**Python Components (Serving Runtimes):**
- Current support: `linux/amd64`, `linux/arm64/v8`
- ❌ **Python runtimes DO NOT support ppc64le yet**

### Components Requiring Power Support

#### 1. **Go-based Components** (✅ ALL ALREADY HAVE ppc64le + s390x SUPPORT!)
- ✅ KServe Controller (`Dockerfile`)
- ✅ Agent (`agent.Dockerfile`)
- ✅ Router (`router.Dockerfile`)
- ✅ LLM Controller (`llmisvc-controller.Dockerfile`)
- ✅ QPExt (`qpext/qpext.Dockerfile`)
- ✅ LocalModel Agent (`localmodel-agent.Dockerfile`)
- ✅ LocalModel Controller (`localmodel.Dockerfile`)

#### 2. **Python-based Serving Runtimes** (Need ppc64le support)
- ❌ SKLearn Server (`python/sklearn.Dockerfile`) sunidhi
- ❌ XGBoost Server (`python/xgb.Dockerfile`) sunidhi
- ❌ LightGBM Server (`python/lgb.Dockerfile`) Prerna
- ❌ PMML Server (`python/pmml.Dockerfile`) Prerna
- ❌ Paddle Server (`python/paddle.Dockerfile`) 
- ❌ HuggingFace Server (`python/huggingface_server.Dockerfile`)
- ❌ HuggingFace CPU Server (`python/huggingface_server_cpu.Dockerfile`)
- ❌ Storage Initializer (`python/storage-initializer.Dockerfile`) Sunidhi
- ❌ AIF Fairness (`python/aiffairness.Dockerfile`)
- ❌ ART Explainer (`python/artexplainer.Dockerfile`) sunidhi
- ❌ Custom Model/Transformer variants

## Detailed Porting Plan

### Phase 1: Infrastructure & Base Image Verification

#### 1.1 Base Image Availability Check

**Go Base Images:**
```dockerfile
FROM golang:1.24 AS builder
FROM gcr.io/distroless/static:nonroot
```
- ✅ `golang:1.24` supports ppc64le
- ✅ `gcr.io/distroless/static:nonroot` supports ppc64le

**Python Base Images:**
```dockerfile
FROM python:3.11-slim-bookworm
FROM eclipse-temurin:21-jdk-noble  # For PMML
```
- ✅ `python:3.11-slim-bookworm` supports ppc64le
- ✅ `eclipse-temurin:21-jdk-noble` supports ppc64le

#### 1.2 Python Dependencies Verification

Critical dependencies to verify for ppc64le support:
- ✅ NumPy - has ppc64le wheels
- ✅ Scikit-learn - has ppc64le wheels
- ✅ XGBoost - has ppc64le wheels
- ✅ LightGBM - has ppc64le wheels
- ⚠️ PyTorch - limited ppc64le support (may need building from source)
- ⚠️ TensorFlow - limited ppc64le support
- ⚠️ ONNX Runtime - may need verification
- ⚠️ vLLM - may not support ppc64le yet

### Phase 2: CI/CD Workflow Updates

#### 2.1 GitHub Actions Workflows to Update

**Priority 1 - Go Components:** ✅ **ALREADY COMPLETE!**
1. ✅ `.github/workflows/agent-docker-publish.yml` - Already has ppc64le + s390x
2. ✅ `.github/workflows/router-docker-publish.yml` - Already has ppc64le + s390x
3. ✅ `.github/workflows/kserve-llmisvc-controller-docker-publish.yml` - Already has ppc64le + s390x
4. ✅ `.github/workflows/qpext-docker-publish.yml` - Already has ppc64le + s390x
5. ✅ `.github/workflows/kserve-localmodel-agent-docker-publish.yml` - Already has ppc64le + s390x
6. ✅ `.github/workflows/kserve-localmodel-controller-docker-publish.yml` - Already has ppc64le + s390x

**Priority 2 - Python Runtimes:**
1. `.github/workflows/sklearnserver-docker-publish.yml`
2. `.github/workflows/xgbserver-docker-publisher.yml`
3. `.github/workflows/lightgbm-docker-publish.yml`
4. `.github/workflows/pmml-docker-publish.yml`
5. `.github/workflows/paddle-docker-publish.yml`
6. `.github/workflows/storage-initializer-docker-publisher.yml`

**Priority 3 - Advanced Runtimes (May have dependency issues):**
1. `.github/workflows/huggingface-docker-publish.yml`
2. `.github/workflows/huggingface-cpu-docker-publish.yml`
3. `.github/workflows/artexplainer-docker-publish.yml`

#### 2.2 Workflow Changes Required

For each workflow, update the `platforms` field:

**Current:**
```yaml
platforms: linux/amd64,linux/arm64/v8
```

**Updated:**
```yaml
platforms: linux/amd64,linux/arm64/v8,linux/ppc64le
```

**For Go components (already done for controller):**
```yaml
platforms: linux/amd64,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/s390x
```

### Phase 3: Makefile Updates

Update `Makefile` to support ppc64le builds:

**Current ARCH variable usage:**
```makefile
ARCH ?=
```

**Add ppc64le build targets:**
```makefile
# Example for sklearn
docker-build-sklearn-ppc64le:
	cd python && ${ENGINE} buildx build --platform linux/ppc64le --build-arg BASE_IMAGE=${BASE_IMG} -t ${KO_DOCKER_REPO}/${SKLEARN_IMG}:ppc64le -f sklearn.Dockerfile .
```

### Phase 4: Component-by-Component Porting

#### 4.1 Go Components ✅ **ALREADY COMPLETE!**

**Status:** All 7 Go components already build for `linux/amd64`, `linux/arm/v7`, `linux/arm64/v8`, `linux/ppc64le`, `linux/s390x`

**No changes required!** The KServe team has already implemented full multi-architecture support for all Go-based components.

#### 4.2 Python Runtimes - Basic ML (High Priority)

**Order of implementation:**

1. **Storage Initializer** (Foundation component)
   - File: `python/storage-initializer.Dockerfile`
   - Workflow: `.github/workflows/storage-initializer-docker-publisher.yml`
   - Dependencies: boto3, google-cloud-storage, azure-storage-blob
   - Risk: LOW - Pure Python dependencies

2. **SKLearn Server**
   - File: `python/sklearn.Dockerfile`
   - Workflow: `.github/workflows/sklearnserver-docker-publish.yml`
   - Dependencies: scikit-learn, numpy, scipy
   - Risk: LOW - All have ppc64le wheels

3. **XGBoost Server**
   - File: `python/xgb.Dockerfile`
   - Workflow: `.github/workflows/xgbserver-docker-publisher.yml`
   - Dependencies: xgboost
   - Risk: LOW - Has ppc64le wheels

4. **LightGBM Server**
   - File: `python/lgb.Dockerfile`
   - Workflow: `.github/workflows/lightgbm-docker-publish.yml`
   - Dependencies: lightgbm
   - Risk: LOW - Has ppc64le wheels

5. **PMML Server**
   - File: `python/pmml.Dockerfile`
   - Workflow: `.github/workflows/pmml-docker-publish.yml`
   - Dependencies: Java-based (PyPMML)
   - Risk: MEDIUM - Java dependencies need verification

#### 4.3 Python Runtimes - Deep Learning (Medium Priority)

6. **Paddle Server**
   - File: `python/paddle.Dockerfile`
   - Workflow: `.github/workflows/paddle-docker-publish.yml`
   - Dependencies: paddlepaddle
   - Risk: MEDIUM - Need to verify ppc64le support

7. **HuggingFace CPU Server**
   - File: `python/huggingface_server_cpu.Dockerfile`
   - Workflow: `.github/workflows/huggingface-cpu-docker-publish.yml`
   - Dependencies: transformers, torch (CPU)
   - Risk: MEDIUM - PyTorch CPU support for ppc64le needs verification

8. **HuggingFace Server** (GPU)
   - File: `python/huggingface_server.Dockerfile`
   - Workflow: `.github/workflows/huggingface-docker-publish.yml`
   - Dependencies: transformers, torch, vllm
   - Risk: HIGH - vLLM may not support ppc64le, GPU drivers

#### 4.4 Explainability Components (Lower Priority)

9. **AIF Fairness**
   - File: `python/aiffairness.Dockerfile`
   - Workflow: `.github/workflows/artexplainer-docker-publish.yml`
   - Dependencies: aif360
   - Risk: MEDIUM

10. **ART Explainer**
    - File: `python/artexplainer.Dockerfile`
    - Dependencies: adversarial-robustness-toolbox
    - Risk: MEDIUM

### Phase 5: Testing Strategy

#### 5.1 Build Testing

**Local Testing (with QEMU):**
```bash
# Test Go component
docker buildx build --platform linux/ppc64le -f agent.Dockerfile .

# Test Python component
cd python && docker buildx build --platform linux/ppc64le -f sklearn.Dockerfile .
```

**CI Testing:**
- GitHub Actions with QEMU emulation
- Actual ppc64le hardware testing (if available)

#### 5.2 Functional Testing

**Test Matrix:**
| Component | Test Type | Priority |
|-----------|-----------|----------|
| Controller | Unit + Integration | P0 |
| Agent | Unit + Integration | P0 |
| Router | Unit + Integration | P0 |
| SKLearn | E2E Inference | P0 |
| XGBoost | E2E Inference | P0 |
| LightGBM | E2E Inference | P1 |
| Storage Init | Integration | P0 |
| HuggingFace | E2E Inference | P1 |

#### 5.3 Performance Testing

- Inference latency comparison (amd64 vs ppc64le)
- Throughput testing
- Resource utilization

### Phase 6: Documentation Updates

#### 6.1 Files to Update

1. `README.md` - Add ppc64le to supported architectures
2. `docs/` - Architecture-specific installation guides
3. `ROADMAP.md` - Add Power support milestone
4. Release notes - Document ppc64le support

#### 6.2 New Documentation

1. **Power Architecture Guide**
   - Installation on Power systems
   - Known limitations
   - Performance considerations

2. **Multi-Architecture Build Guide**
   - How to build for ppc64le
   - Cross-compilation tips
   - Troubleshooting

### Phase 7: Upstream Contribution Strategy

#### 7.1 PR Submission Approach

**UPDATED: Component-wise PRs (RECOMMENDED)**

**MAJOR DISCOVERY:** All Go components already support ppc64le! No PR needed for Go components.

Advantages:
- Easier to review
- Faster merge cycles
- Can be tested independently
- Reduces risk

**REVISED PR sequence (3 PRs instead of 5):**

1. **PR #1: Basic Python Runtimes**
   - Storage Initializer
   - SKLearn Server
   - XGBoost Server
   - LightGBM Server
   - Update Makefile for Python multi-arch builds
   - Add documentation noting Go components already support ppc64le

2. **PR #2: Advanced Python Runtimes**
   - PMML Server
   - Paddle Server
   - HuggingFace CPU Server (if feasible)

3. **PR #3: Explainability & Examples**
   - AIF Fairness
   - ART Explainer
   - Custom model variants
   - Final documentation updates

4. **PR #4: HuggingFace GPU (if feasible) - OPTIONAL**
   - Only if vLLM supports ppc64le

**Option B: Single Large PR**

Advantages:
- Complete feature in one PR
- Consistent across all components

Disadvantages:
- Large review burden
- Longer merge time
- Higher risk of conflicts

#### 7.2 PR Requirements

Each PR should include:
1. ✅ Code changes (Dockerfiles, workflows, Makefile)
2. ✅ CI/CD updates
3. ✅ Documentation updates
4. ✅ Test results (build logs, test outputs)
5. ✅ Performance benchmarks (if applicable)
6. ✅ Known limitations documented

#### 7.3 Review Process

1. **Pre-submission checklist:**
   - All builds pass on ppc64le
   - Tests pass (or known failures documented)
   - Documentation updated
   - No breaking changes to existing architectures

2. **Community engagement:**
   - Announce in KServe Slack channel
   - Present in community meeting
   - Respond to review comments promptly

### Phase 8: Maintenance & Support

#### 8.1 Ongoing Responsibilities

1. **Monitor CI/CD:**
   - Watch for ppc64le build failures
   - Keep dependencies updated

2. **Dependency Management:**
   - Track upstream ppc64le support
   - Update when new wheels available

3. **Issue Triage:**
   - Label ppc64le-specific issues
   - Maintain compatibility matrix

#### 8.2 Known Limitations to Document

1. **vLLM/GPU Support:**
   - May not be available initially
   - Document workarounds or alternatives

2. **Performance:**
   - Document any performance differences
   - Provide optimization guidelines

3. **Dependency Constraints:**
   - List any packages requiring source builds
   - Document build-time requirements

## Implementation Timeline

**MAJOR UPDATE:** All Go components already support ppc64le! Timeline reduced from 12 weeks to 8 weeks.

### Week 1-2: Preparation & Discovery ✅
- ✅ Complete analysis (this document)
- ✅ **DISCOVERY: All 7 Go components already support ppc64le + s390x!**
- Verify Python dependencies for ppc64le
- Test local Python builds with QEMU
- Set up ppc64le test environment (if available)

### Week 3-4: Python Storage & Basic ML (PR #1)
- Port Storage Initializer
- Port SKLearn, XGBoost, LightGBM
- Test builds and inference workloads
- Submit PR #1 (Python basic runtimes)

### Week 5-6: Advanced Python Runtimes (PR #2)
- Port PMML, Paddle
- Port HuggingFace CPU (if feasible)
- Test builds and inference
- Submit PR #2

### Week 7-8: Explainability & Documentation (PR #3)
- Port AIF Fairness, ART Explainer
- Port custom model examples
- Update documentation (note Go components already done)
- Performance testing on Python runtimes
- Submit PR #3
- Final reviews and merges

## Risk Assessment

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| vLLM no ppc64le support | High | High | Document limitation, provide alternatives |
| PyTorch ppc64le issues | Medium | Medium | Use CPU-only builds, document workarounds |
| CI/CD build timeouts | Low | Medium | Optimize builds, use caching |
| Dependency unavailability | Medium | Low | Build from source, document process |
| Performance degradation | Medium | Low | Benchmark and optimize |

## Success Criteria

1. ✅ **All Go components build successfully for ppc64le** - ALREADY ACHIEVED!
2. ✅ Core Python runtimes (SKLearn, XGBoost, LightGBM) work on ppc64le
3. ✅ CI/CD pipelines include ppc64le builds for Python runtimes
4. ✅ Documentation updated
5. ✅ At least 3 PRs merged upstream (reduced from 4-5 since Go is done)
6. ✅ E2E tests pass on ppc64le
7. ✅ Performance within 20% of amd64 (for CPU workloads)

## Resources Required

1. **Hardware:**
   - Access to ppc64le system for testing (optional but recommended)
   - Or rely on QEMU emulation in CI

2. **Time:**
   - ~8 weeks for complete implementation (reduced from 12 - Go components already done!)
   - ~2-4 hours/week for maintenance

3. **Expertise:**
   - Docker multi-arch builds
   - GitHub Actions
   - Python packaging
   - Go cross-compilation

## Conclusion

Adding Power (ppc64le) support to KServe is feasible with moderate effort. The Go components are straightforward, while Python runtimes require careful dependency verification. A phased, component-wise approach to upstream contribution is recommended for faster review and merge cycles.

The main challenges are:
1. vLLM/GPU support for HuggingFace
2. PyTorch ppc64le compatibility
3. CI/CD build times

However, the core functionality (controller + basic ML runtimes) can be delivered with high confidence.
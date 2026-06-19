# KServe Power (ppc64le) Architecture - Component Checklist

This document provides a detailed checklist of all components that need to be ported to support Power architecture.

## Status Legend
- ✅ Already supports ppc64le
- 🔄 Ready to port (no blockers)
- ⚠️ Needs investigation (potential dependency issues)
- ❌ Blocked (dependencies don't support ppc64le)

---

## 1. Go-Based Components

### Core Controllers

| Component | File | Workflow | Status | Notes |
|-----------|------|----------|--------|-------|
| KServe Controller | `Dockerfile` | `kserve-controller-docker-publish.yml` | ✅ | Already supports ppc64le + s390x |
| Agent | `agent.Dockerfile` | `agent-docker-publish.yml` | ✅ | Already supports ppc64le + s390x |
| Router | `router.Dockerfile` | `router-docker-publish.yml` | ✅ | Already supports ppc64le + s390x |
| LLM Controller | `llmisvc-controller.Dockerfile` | `kserve-llmisvc-controller-docker-publish.yml` | ✅ | Already supports ppc64le + s390x |
| QPExt | `qpext/qpext.Dockerfile` | `qpext-docker-publish.yml` | ✅ | Already supports ppc64le + s390x |
| LocalModel Agent | `localmodel-agent.Dockerfile` | `kserve-localmodel-agent-docker-publish.yml` | ✅ | Already supports ppc64le + s390x |
| LocalModel Controller | `localmodel.Dockerfile` | `kserve-localmodel-controller-docker-publish.yml` | ✅ | Already supports ppc64le + s390x |

**Estimated Effort:** 0 days - ALREADY COMPLETE! ✅
**Risk Level:** NONE
**Dependencies:** golang:1.24, gcr.io/distroless/static:nonroot (both support ppc64le)
**All Go components build for:** `linux/amd64`, `linux/arm/v7`, `linux/arm64/v8`, `linux/ppc64le`, `linux/s390x`

---

## 2. Python-Based Serving Runtimes

### 2.1 Storage & Infrastructure

| Component | File | Workflow | Status | Notes |
|-----------|------|----------|--------|-------|
| Storage Initializer | `python/storage-initializer.Dockerfile` | `storage-initializer-docker-publisher.yml` | 🔄 | Pure Python, no ML deps |

**Estimated Effort:** 1 day
**Risk Level:** LOW
**Key Dependencies:** boto3, google-cloud-storage, azure-storage-blob (all pure Python)

### 2.2 Traditional ML Frameworks

| Component | File | Workflow | Status | Key Dependencies | Notes |
|-----------|------|----------|--------|------------------|-------|
| SKLearn Server | `python/sklearn.Dockerfile` | `sklearnserver-docker-publish.yml` | 🔄 | scikit-learn, numpy, scipy | All have ppc64le wheels |
| XGBoost Server | `python/xgb.Dockerfile` | `xgbserver-docker-publisher.yml` | 🔄 | xgboost | Has ppc64le wheels |
| LightGBM Server | `python/lgb.Dockerfile` | `lightgbm-docker-publish.yml` | 🔄 | lightgbm | Has ppc64le wheels |
| PMML Server | `python/pmml.Dockerfile` | `pmml-docker-publish.yml` | ⚠️ | PyPMML, Java | Needs Java verification |

**Estimated Effort:** 3-4 days
**Risk Level:** LOW to MEDIUM
**Notes:** PMML needs Java runtime verification on ppc64le

### 2.3 Deep Learning Frameworks

| Component | File | Workflow | Status | Key Dependencies | Notes |
|-----------|------|----------|--------|------------------|-------|
| Paddle Server | `python/paddle.Dockerfile` | `paddle-docker-publish.yml` | ⚠️ | paddlepaddle | Need to verify ppc64le support |
| HuggingFace CPU | `python/huggingface_server_cpu.Dockerfile` | `huggingface-cpu-docker-publish.yml` | ⚠️ | transformers, torch (CPU) | PyTorch CPU for ppc64le needs verification |
| HuggingFace GPU | `python/huggingface_server.Dockerfile` | `huggingface-docker-publish.yml` | ❌ | transformers, torch, vllm | vLLM likely doesn't support ppc64le |

**Estimated Effort:** 5-7 days
**Risk Level:** MEDIUM to HIGH
**Notes:** 
- PyTorch has limited ppc64le support
- vLLM is a major blocker for GPU inference
- May need to build PyTorch from source

### 2.4 Explainability & Fairness

| Component | File | Workflow | Status | Key Dependencies | Notes |
|-----------|------|----------|--------|------------------|-------|
| AIF Fairness | `python/aiffairness.Dockerfile` | N/A | ⚠️ | aif360, scikit-learn | Depends on scikit-learn (OK) |
| ART Explainer | `python/artexplainer.Dockerfile` | `artexplainer-docker-publish.yml` | ⚠️ | adversarial-robustness-toolbox | Needs investigation |

**Estimated Effort:** 2-3 days
**Risk Level:** MEDIUM
**Notes:** Depends on underlying ML frameworks

### 2.5 Custom Models & Transformers

| Component | File | Workflow | Status | Notes |
|-----------|------|----------|--------|-------|
| Custom Model | `python/custom_model.Dockerfile` | N/A | 🔄 | Example/test component |
| Custom Model gRPC | `python/custom_model_grpc.Dockerfile` | `custom-model-grpc-publish.yml` | 🔄 | Example/test component |
| Custom Transformer | `python/custom_transformer.Dockerfile` | N/A | 🔄 | Example/test component |
| Custom Transformer gRPC | `python/custom_transformer_grpc.Dockerfile` | `transformer-docker-publish.yml` | 🔄 | Example/test component |
| Custom Tokenizer | `python/custom_tokenizer.Dockerfile` | N/A | 🔄 | Example/test component |

**Estimated Effort:** 2 days
**Risk Level:** LOW
**Notes:** These are examples, lower priority

### 2.6 Test Components

| Component | File | Workflow | Status | Notes |
|-----------|------|----------|--------|-------|
| Success 200 ISVC | `python/success_200_isvc.Dockerfile` | N/A | 🔄 | Test component |
| Error 404 ISVC | `python/error_404_isvc.Dockerfile` | N/A | 🔄 | Test component |

**Estimated Effort:** 0.5 days
**Risk Level:** LOW

---

## 3. CI/CD Workflows to Update

### 3.1 Priority 1 - Core Components (Must Have)

| Workflow File | Current Platforms | Target Platforms | Status |
|---------------|-------------------|------------------|--------|
| `kserve-controller-docker-publish.yml` | amd64, arm/v7, arm64/v8, ppc64le, s390x | ✅ Already done | ✅ |
| `agent-docker-publish.yml` | amd64, arm64/v8 | + ppc64le, s390x | 🔄 |
| `router-docker-publish.yml` | amd64, arm64/v8 | + ppc64le, s390x | 🔄 |
| `kserve-llmisvc-controller-docker-publish.yml` | amd64, arm64/v8 | + ppc64le, s390x | 🔄 |
| `storage-initializer-docker-publisher.yml` | amd64, arm64/v8 | + ppc64le | 🔄 |

### 3.2 Priority 2 - ML Runtimes (Should Have)

| Workflow File | Current Platforms | Target Platforms | Status |
|---------------|-------------------|------------------|--------|
| `sklearnserver-docker-publish.yml` | amd64, arm64/v8 | + ppc64le | 🔄 |
| `xgbserver-docker-publisher.yml` | amd64, arm64/v8 | + ppc64le | 🔄 |
| `lightgbm-docker-publish.yml` | amd64, arm64/v8 | + ppc64le | 🔄 |
| `pmml-docker-publish.yml` | amd64, arm64/v8 | + ppc64le | ⚠️ |
| `paddle-docker-publish.yml` | amd64, arm64/v8 | + ppc64le | ⚠️ |

### 3.3 Priority 3 - Advanced Features (Nice to Have)

| Workflow File | Current Platforms | Target Platforms | Status |
|---------------|-------------------|------------------|--------|
| `huggingface-cpu-docker-publish.yml` | amd64, arm64/v8 | + ppc64le | ⚠️ |
| `huggingface-docker-publish.yml` | amd64, arm64/v8 | + ppc64le | ❌ |
| `artexplainer-docker-publish.yml` | amd64, arm64/v8 | + ppc64le | ⚠️ |
| `qpext-docker-publish.yml` | amd64, arm64/v8 | + ppc64le, s390x | 🔄 |

### 3.4 Priority 4 - LocalModel & Misc

| Workflow File | Current Platforms | Target Platforms | Status |
|---------------|-------------------|------------------|--------|
| `kserve-localmodel-agent-docker-publish.yml` | amd64, arm64/v8 | + ppc64le, s390x | 🔄 |
| `kserve-localmodel-controller-docker-publish.yml` | amd64, arm64/v8 | + ppc64le, s390x | 🔄 |
| `custom-model-grpc-publish.yml` | amd64, arm64/v8 | + ppc64le | 🔄 |
| `transformer-docker-publish.yml` | amd64, arm64/v8 | + ppc64le | 🔄 |

---

## 4. Makefile Targets to Update

### Current Makefile Structure
```makefile
ENGINE ?= docker
ARCH ?=
```

### Targets Needing Updates

| Target | Current | Needs Update |
|--------|---------|--------------|
| `docker-build` | Generic | Add ppc64le support |
| `docker-build-agent` | Generic | Add ppc64le support |
| `docker-build-router` | Generic | Add ppc64le support |
| `docker-build-sklearn` | Generic | Add ppc64le support |
| `docker-build-xgb` | Generic | Add ppc64le support |
| `docker-build-lgb` | Generic | Add ppc64le support |
| All other docker-build-* | Generic | Add ppc64le support |

**Suggested Addition:**
```makefile
# Multi-arch build support
PLATFORMS ?= linux/amd64,linux/arm64/v8,linux/ppc64le

docker-build-multiarch:
	${ENGINE} buildx build --platform ${PLATFORMS} ...
```

---

## 5. Documentation Updates Required

### Files to Update

| File | Section | Update Required |
|------|---------|-----------------|
| `README.md` | Architecture Support | Add ppc64le to supported list |
| `ROADMAP.md` | Future Plans | Add Power support milestone |
| `docs/admin-guide/` | Installation | Add ppc64le-specific notes |
| Release Notes | New Features | Document ppc64le support |

### New Documentation Needed

1. **`docs/admin-guide/power-architecture.md`**
   - Installation on Power systems
   - Known limitations
   - Performance considerations
   - Troubleshooting

2. **`docs/developer-guide/multi-arch-builds.md`**
   - How to build for ppc64le
   - Cross-compilation guide
   - Testing with QEMU

---

## 6. Testing Requirements

### 6.1 Build Tests

| Component Type | Test Method | Status |
|----------------|-------------|--------|
| Go Components | `docker buildx build --platform linux/ppc64le` | 🔄 |
| Python Runtimes | `docker buildx build --platform linux/ppc64le` | 🔄 |

### 6.2 Functional Tests

| Test Suite | Components | Priority |
|------------|------------|----------|
| Unit Tests | All Go components | P0 |
| Integration Tests | Controller + Agent + Router | P0 |
| E2E Tests | SKLearn, XGBoost inference | P0 |
| E2E Tests | LightGBM, PMML inference | P1 |
| E2E Tests | HuggingFace inference | P2 |

### 6.3 Performance Tests

| Metric | Baseline (amd64) | Target (ppc64le) |
|--------|------------------|------------------|
| Inference Latency | X ms | < 1.2X ms |
| Throughput | Y req/s | > 0.8Y req/s |
| Memory Usage | Z MB | < 1.1Z MB |

---

## 7. Dependency Verification Checklist

### Python Packages - Verified for ppc64le

- ✅ numpy
- ✅ scipy
- ✅ scikit-learn
- ✅ xgboost
- ✅ lightgbm
- ✅ pandas
- ✅ boto3
- ✅ google-cloud-storage
- ✅ azure-storage-blob

### Python Packages - Need Verification

- ⚠️ torch (PyTorch) - Limited support
- ⚠️ tensorflow - Limited support
- ⚠️ paddlepaddle - Unknown
- ⚠️ onnxruntime - Unknown
- ❌ vllm - Likely no support
- ⚠️ aif360 - Unknown
- ⚠️ adversarial-robustness-toolbox - Unknown

### Base Images - Verified for ppc64le

- ✅ golang:1.24
- ✅ python:3.11-slim-bookworm
- ✅ eclipse-temurin:21-jdk-noble
- ✅ gcr.io/distroless/static:nonroot

---

## 8. Upstream PR Strategy

### Recommended PR Sequence

#### PR #1: Infrastructure & Go Components (Week 3-4)
**Files Changed:** ~15-20
- All Go component Dockerfiles (no changes needed, just workflow updates)
- 7 GitHub Actions workflows
- Makefile updates
- Documentation updates

**Components:**
- ✅ KServe Controller (already done)
- Agent
- Router
- LLM Controller
- QPExt
- LocalModel Agent
- LocalModel Controller

**Estimated Review Time:** 1-2 weeks

#### PR #2: Storage & Basic ML Runtimes (Week 5-6)
**Files Changed:** ~10-12
- 4 Dockerfiles
- 4 GitHub Actions workflows
- Test updates

**Components:**
- Storage Initializer
- SKLearn Server
- XGBoost Server
- LightGBM Server

**Estimated Review Time:** 1-2 weeks

#### PR #3: Advanced ML Runtimes (Week 7-8)
**Files Changed:** ~6-8
- 3 Dockerfiles
- 3 GitHub Actions workflows
- Documentation for limitations

**Components:**
- PMML Server
- Paddle Server
- HuggingFace CPU Server (if feasible)

**Estimated Review Time:** 2-3 weeks

#### PR #4: Explainability & Examples (Week 9-10)
**Files Changed:** ~8-10
- Multiple Dockerfiles
- Workflows
- Test components

**Components:**
- AIF Fairness
- ART Explainer
- Custom model examples
- Test components

**Estimated Review Time:** 1-2 weeks

---

## 9. Risk Mitigation Strategies

### High-Risk Components

| Component | Risk | Mitigation |
|-----------|------|------------|
| HuggingFace GPU | vLLM no ppc64le support | Document limitation, provide CPU alternative |
| PyTorch | Limited ppc64le wheels | Build from source, provide pre-built images |
| TensorFlow | Limited ppc64le support | Use older stable version, or skip initially |

### Build Time Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| CI timeout | Build failures | Use build caching, optimize layers |
| QEMU slow | Long CI times | Use native ppc64le runners if available |
| Dependency downloads | Network issues | Use dependency caching |

---

## 10. Success Metrics

### Phase 1 Success (Go Components)
- [ ] All 7 Go components build successfully for ppc64le
- [ ] CI/CD pipelines green
- [ ] Unit tests pass
- [ ] PR #1 merged

### Phase 2 Success (Basic ML)
- [ ] Storage Initializer works on ppc64le
- [ ] SKLearn, XGBoost, LightGBM inference working
- [ ] E2E tests pass
- [ ] PR #2 merged

### Phase 3 Success (Advanced ML)
- [ ] At least 2 of 3 advanced runtimes working
- [ ] Known limitations documented
- [ ] PR #3 merged

### Overall Success
- [ ] 80%+ of components support ppc64le
- [ ] Documentation complete
- [ ] Community adoption (at least 1 user on Power)
- [ ] Performance within acceptable range

---

## 11. Timeline Summary

| Phase | Duration | Components | PRs |
|-------|----------|------------|-----|
| Analysis & Planning | Week 1-2 | N/A | 0 |
| Go Components | Week 3-4 | 7 components | PR #1 |
| Basic ML Runtimes | Week 5-6 | 4 components | PR #2 |
| Advanced ML Runtimes | Week 7-8 | 3 components | PR #3 |
| Explainability & Misc | Week 9-10 | 5+ components | PR #4 |
| Review & Finalization | Week 11-12 | All | All |

**Total Duration:** 12 weeks
**Total PRs:** 4-5
**Total Components:** 20+

---

## 12. Contact & Resources

### Community Resources
- KServe Slack: #kserve-dev
- GitHub Issues: Tag with `architecture/ppc64le`
- Community Meetings: Bi-weekly

### Technical Resources
- Docker Buildx: https://docs.docker.com/buildx/
- QEMU: https://www.qemu.org/
- Power Architecture: https://openpowerfoundation.org/

### Testing Resources
- QEMU ppc64le emulation
- IBM Power Systems (if available)
- Cloud providers with Power instances

---

**Last Updated:** 2026-04-23
**Document Version:** 1.0
**Status:** Planning Phase
ARG PYTHON_VERSION=3.11
ARG BASE_IMAGE=python:${PYTHON_VERSION}-slim-bookworm
ARG VENV_PATH=/prod_venv

FROM ${BASE_IMAGE} AS builder

# Required for building packages for ppc64le arch
RUN apt-get update && apt-get install -y --no-install-recommends curl python3-dev build-essential && \
    if [ "$(uname -m)" = "ppc64le" ]; then apt-get install pkg-config libssl-dev gcc gfortran cmake pkg-config libssl-dev libopenblas-dev libjpeg-dev libhdf5-dev wget -y; fi && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.local/bin/uv /usr/local/bin/uv

# Setup virtual environment
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
RUN uv venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Pre-install ppc64le wheels from devpi before running uv sync
# This ensures ppc64le-optimized wheels are used instead of building from source
# Install whatever versions are available in devpi, uv sync will upgrade/downgrade if needed
RUN if [ "$(uname -m)" = "ppc64le" ]; then \
    uv pip install --no-cache \
        --index-url https://wheels.developerfirst.ibm.com/ppc64le/linux \
        --extra-index-url https://pypi.org/simple \
        --index-strategy unsafe-best-match \
        --only-binary :all: \
        grpcio || echo "grpcio wheel not available, will be installed by uv sync"; \
    uv pip install --no-cache \
        --index-url https://wheels.developerfirst.ibm.com/ppc64le/linux \
        --extra-index-url https://pypi.org/simple \
        --index-strategy unsafe-best-match \
        --only-binary :all: \
        grpcio-tools || echo "grpcio-tools wheel not available, will be installed by uv sync"; \
    uv pip install --no-cache \
        --index-url https://wheels.developerfirst.ibm.com/ppc64le/linux \
        --extra-index-url https://pypi.org/simple \
        --index-strategy unsafe-best-match \
        --only-binary :all: \
        numpy pandas psutil pyyaml httptools uvloop; \
    fi

# Copy storage metadata for editable dependency resolution
COPY storage/pyproject.toml storage/uv.lock storage/

# ------------------ kserve deps ------------------
COPY kserve/pyproject.toml kserve/uv.lock kserve/
# uv sync will skip already-installed packages from devpi
RUN cd kserve && uv sync --active --no-cache

COPY kserve kserve
RUN cd kserve && uv sync --active --no-cache

# ------------------ artexplainer deps ------------------
COPY artexplainer/pyproject.toml artexplainer/uv.lock artexplainer/
# uv sync will skip already-installed packages from devpi
RUN cd artexplainer && uv sync --active --no-cache

COPY artexplainer artexplainer
RUN cd artexplainer && uv sync --active --no-cache

# Generate third-party licenses
COPY pyproject.toml pyproject.toml
COPY third_party/pip-licenses.py pip-licenses.py
# TODO: Remove this when upgrading to python 3.11+
RUN pip install --no-cache-dir tomli
RUN mkdir -p third_party/library && python3 pip-licenses.py


# ------------------ Production stage ------------------
FROM ${BASE_IMAGE} AS prod

# Activate virtual env
ARG VENV_PATH
ENV VIRTUAL_ENV=${VENV_PATH}
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN useradd kserve -m -u 1000 -d /home/kserve

COPY --from=builder --chown=kserve:kserve third_party third_party
COPY --from=builder --chown=kserve:kserve $VIRTUAL_ENV $VIRTUAL_ENV
COPY --from=builder kserve kserve
COPY --from=builder artexplainer artexplainer

USER 1000
ENV PYTHONPATH=/artexplainer
ENTRYPOINT ["python", "-m", "artserver"]

# Made with Bob

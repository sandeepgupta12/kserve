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

# Configure uv to use IBM Power wheel index for ppc64le
RUN mkdir -p /root/.config/uv && \
    echo '[index]' > /root/.config/uv/uv.toml && \
    echo '[[index]]' >> /root/.config/uv/uv.toml && \
    echo 'name = "ppc64le-wheels"' >> /root/.config/uv/uv.toml && \
    echo 'url = "https://wheels.developerfirst.ibm.com/ppc64le/linux"' >> /root/.config/uv/uv.toml && \
    echo 'default = true' >> /root/.config/uv/uv.toml && \
    echo '' >> /root/.config/uv/uv.toml && \
    echo '[[index]]' >> /root/.config/uv/uv.toml && \
    echo 'name = "pypi"' >> /root/.config/uv/uv.toml && \
    echo 'url = "https://pypi.org/simple"' >> /root/.config/uv/uv.toml

# Install ppc64le-specific wheels from IBM Power index
RUN if [ "$(uname -m)" = "ppc64le" ]; then \
    uv pip install --index-url https://wheels.developerfirst.ibm.com/ppc64le/linux \
        --extra-index-url https://pypi.org/simple \
        "grpcio>=1.64.1" \
        "grpcio-tools>=1.64.1" \
        "numpy>=1.26.0" \
        "pandas>=2.2.0" \
        "psutil>=5.9.6" \
        "pyyaml>=6.0.0" \
        "httptools>=0.6.0" \
        "uvloop>=0.21.0"; \
    fi

# Copy storage metadata for editable dependency resolution
COPY storage/pyproject.toml storage/uv.lock storage/

# ------------------ kserve deps ------------------
COPY kserve/pyproject.toml kserve/uv.lock kserve/
RUN cd kserve && uv sync --active --no-cache

COPY kserve kserve
RUN cd kserve && uv sync --active --no-cache

# ------------------ artexplainer deps ------------------
COPY artexplainer/pyproject.toml artexplainer/uv.lock artexplainer/
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

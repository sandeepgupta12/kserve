# LightGBM Server Local Testing Guide

This guide explains how to test your locally built LightGBM server Docker image by creating and running a container.

## Prerequisites

- Docker installed and running
- LightGBM server image built locally (e.g., `your-username/lgbserver:latest`)
- Python 3.x with lightgbm and scikit-learn installed (for creating test model)

### Install Python Dependencies on Ubuntu

```bash
# Update package list
sudo apt update

# Install Python 3 and pip (if not already installed)
sudo apt install python3 python3-pip -y

# Install lightgbm and scikit-learn
pip3 install lightgbm scikit-learn

# Verify installation
python3 -c "import lightgbm; import sklearn; print('LightGBM version:', lightgbm.__version__); print('Scikit-learn version:', sklearn.__version__)"
```

**Alternative: Using Virtual Environment (Recommended)**

```bash
# Install venv if not available
sudo apt install python3-venv -y

# Create virtual environment
python3 -m venv lgb-test-env

# Activate virtual environment
source lgb-test-env/bin/activate

# Install dependencies
pip install lightgbm scikit-learn

# Verify installation
python -c "import lightgbm; import sklearn; print('Setup complete!')"

# When done testing, deactivate
# deactivate
```

## Step 1: Create a Test Model

First, create a simple LightGBM model for testing:

```bash
# Create a directory for your test model
mkdir -p /tmp/lgb-test-model
cd /tmp/lgb-test-model
```

Create a Python script `create_model.py`:

```python
import lightgbm as lgb
from sklearn.datasets import load_iris
import os

model_dir = "."
BST_FILE = "model.bst"

# Load iris dataset
iris = load_iris()
y = iris['target']
X = iris['data']
dtrain = lgb.Dataset(X, label=y)

# Train model
params = {
    'objective': 'multiclass', 
    'metric': 'softmax',
    'num_class': 3
}
lgb_model = lgb.train(params=params, train_set=dtrain)

# Save model
model_file = os.path.join(model_dir, BST_FILE)
lgb_model.save_model(model_file)
print(f"Model saved to {model_file}")
```

Run the script:

```bash
python create_model.py
```

This creates `model.bst` in the current directory.

## Step 2: Run the Container

### Option A: Run with Local Model Directory (Recommended for Testing)

Mount your local model directory into the container:

```bash
docker run -it --rm \
  -p 8080:8080 \
  -v /tmp/lgb-test-model:/models \
  your-username/lgbserver:latest \
  --model_name lgb-iris \
  --model_dir /models
```

**Windows PowerShell:**
```powershell
docker run -it --rm `
  -p 8080:8080 `
  -v C:\tmp\lgb-test-model:/models `
  your-username/lgbserver:latest `
  --model_name lgb-iris `
  --model_dir /models
```

### Option B: Copy Model into Container

If you prefer to copy the model into the container:

```bash
# Create a Dockerfile for testing
cat > Dockerfile.test <<EOF
FROM your-username/lgbserver:latest
COPY model.bst /models/model.bst
EOF

# Build test image
docker build -f Dockerfile.test -t lgbserver-test .

# Run container
docker run -it --rm -p 8080:8080 lgbserver-test --model_name lgb-iris --model_dir /models
```

### Container Parameters Explained:

- `-it`: Interactive terminal
- `--rm`: Remove container after it stops
- `-p 8080:8080`: Map container port 8080 to host port 8080
- `-v`: Mount volume (local path:container path)
- `--model_name`: Name of your model
- `--model_dir`: Directory containing model.bst file

## Step 3: Verify Server is Running

Check if the server started successfully. You should see logs like:

```
INFO:kserve:Starting gRPC server on [::]:8081
INFO:kserve:Starting HTTPServer on 0.0.0.0:8080
```

## Step 4: Test the Server

### Health Check

```bash
curl http://localhost:8080/v1/models/lgb-iris
```

Expected response:
```json
{
  "name": "lgb-iris",
  "ready": true
}
```

### Make a Prediction

Create a test input file `iris-input.json`:

```json
{
  "inputs": [{
    "sepal_length_(cm)": [5.1],
    "sepal_width_(cm)": [3.5],
    "petal_length_(cm)": [1.4],
    "petal_width_(cm)": [0.2]
  }]
}
```

Send prediction request:

```bash
curl -X POST http://localhost:8080/v1/models/lgb-iris:predict \
  -H "Content-Type: application/json" \
  -d @iris-input.json
```

**Windows PowerShell:**
```powershell
$body = Get-Content iris-input.json -Raw
Invoke-RestMethod -Uri "http://localhost:8080/v1/models/lgb-iris:predict" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body
```

Expected response:
```json
{
  "predictions": [[0.9, 0.05, 0.05]]
}
```

### Python Test Script

Create `test_prediction.py`:

```python
import requests
import json

# Test data
request_data = {
    "inputs": [{
        "sepal_length_(cm)": [5.1],
        "sepal_width_(cm)": [3.5],
        "petal_length_(cm)": [1.4],
        "petal_width_(cm)": [0.2]
    }]
}

# Send request
url = "http://localhost:8080/v1/models/lgb-iris:predict"
response = requests.post(url, json=request_data)

print(f"Status Code: {response.status_code}")
print(f"Response: {json.dumps(response.json(), indent=2)}")
```

Run it:
```bash
python test_prediction.py
```

## Step 5: Advanced Testing

### Test with Multiple Inputs

```json
{
  "inputs": [
    {
      "sepal_length_(cm)": [5.1, 6.2, 5.9],
      "sepal_width_(cm)": [3.5, 3.4, 3.0],
      "petal_length_(cm)": [1.4, 5.4, 5.1],
      "petal_width_(cm)": [0.2, 2.3, 1.8]
    }
  ]
}
```

### Check Container Logs

```bash
# Get container ID
docker ps

# View logs
docker logs <container-id>

# Follow logs in real-time
docker logs -f <container-id>
```

### Interactive Shell Access

```bash
# Run container with shell access
docker run -it --rm \
  -p 8080:8080 \
  -v /tmp/lgb-test-model:/models \
  --entrypoint /bin/bash \
  your-username/lgbserver:latest

# Inside container, manually start server
python -m lgbserver --model_name lgb-iris --model_dir /models
```

## Step 6: Test Different Configurations

### Custom Port

```bash
docker run -it --rm \
  -p 9000:9000 \
  -v /tmp/lgb-test-model:/models \
  your-username/lgbserver:latest \
  --model_name lgb-iris \
  --model_dir /models \
  --http_port 9000
```

### Custom Number of Threads

```bash
docker run -it --rm \
  -p 8080:8080 \
  -v /tmp/lgb-test-model:/models \
  your-username/lgbserver:latest \
  --model_name lgb-iris \
  --model_dir /models \
  --nthread 4
```

### Enable Debug Logging

```bash
docker run -it --rm \
  -p 8080:8080 \
  -v /tmp/lgb-test-model:/models \
  -e LOG_LEVEL=DEBUG \
  your-username/lgbserver:latest \
  --model_name lgb-iris \
  --model_dir /models
```

## Troubleshooting

### Container Exits Immediately

Check logs:
```bash
docker logs <container-id>
```

Common issues:
- Model file not found: Verify volume mount path
- Port already in use: Change port mapping `-p 8081:8080`
- Permission issues: Check file permissions on model directory

### Model Loading Errors

```bash
# Verify model file exists in container
docker run -it --rm \
  -v /tmp/lgb-test-model:/models \
  your-username/lgbserver:latest \
  ls -la /models
```

### Connection Refused

- Ensure container is running: `docker ps`
- Check port mapping is correct
- Verify firewall settings
- On Windows, try `localhost` or `127.0.0.1`

### Model Version Mismatch

If you get errors about incompatible model format:
- Rebuild image with matching LightGBM version
- Check `python/lgbserver/pyproject.toml` for LightGBM version
- Recreate model with same LightGBM version

## Performance Testing

### Load Testing with Apache Bench

```bash
# Install apache bench
# Ubuntu: sudo apt-get install apache2-utils
# Mac: brew install apache2

# Run load test
ab -n 1000 -c 10 -p iris-input.json -T application/json \
  http://localhost:8080/v1/models/lgb-iris:predict
```

### Memory and CPU Monitoring

```bash
# Monitor container resources
docker stats <container-id>
```

## Cleanup

```bash
# Stop running container
docker stop <container-id>

# Remove test model directory
rm -rf /tmp/lgb-test-model

# Remove test images (optional)
docker rmi lgbserver-test
```

## Next Steps

Once local testing is successful:

1. **Push to Registry**: Push your image to Docker Hub or private registry
2. **Deploy to Kubernetes**: Create InferenceService YAML
3. **Integration Testing**: Test with actual workloads
4. **Performance Tuning**: Adjust resources and threading
5. **Monitoring**: Set up logging and metrics collection

## Quick Reference

```bash
# Build image
cd python
docker build -t your-username/lgbserver:latest -f lgb.Dockerfile .

# Run container
docker run -it --rm -p 8080:8080 -v /path/to/model:/models \
  your-username/lgbserver:latest --model_name mymodel --model_dir /models

# Test prediction
curl -X POST http://localhost:8080/v1/models/mymodel:predict \
  -H "Content-Type: application/json" -d @input.json

# Check logs
docker logs -f <container-id>

# Stop container
docker stop <container-id>
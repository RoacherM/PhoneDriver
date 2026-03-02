# Task 005: Create Dockerfile

**depends-on**: task-001

## Objective

Create a lightweight Dockerfile that packages the PhoneDriver control logic without any GPU dependencies.

## BDD References

### Build (`docker_container_operation.feature`)
- "Build Docker image successfully" - Python 3.11+, openai/gradio in reqs, no torch/transformers
- "Docker image excludes GPU dependencies" - no CUDA, no torch, no transformers
- "Docker image includes project files" - phone_agent.py, qwen_vl_agent.py, ui.py, config.json, requirements.txt

### Startup (`docker_container_operation.feature`)
- "Container starts with default configuration"
- "Container starts with environment variables"

### ADB (`docker_container_operation.feature`)
- "Connect to ADB via host server forwarding" - ADB_SERVER_SOCKET env var
- android-tools-adb package installed

### Lifecycle (`docker_container_operation.feature`)
- "Container stops gracefully" - SIGTERM handling
- "Container resource limits" - no GPU allocation

## Implementation Details

### Dockerfile specification

- **Base image**: `python:3.11-slim`
- **System deps**: `android-tools-adb` only (via apt-get)
- **Python deps**: install from `requirements.txt` with `--no-cache-dir`
- **Working directory**: `/app`
- **Copy**: all Python source files and config.json
- **Environment vars**: set `PYTHONUNBUFFERED=1`, `PYTHONDONTWRITEBYTECODE=1`
- **Default ADB_SERVER_SOCKET**: `tcp:host.docker.internal:5037`
- **Expose**: port 7860
- **CMD**: `python ui.py` (starts Gradio UI)
- **Create screenshots dir**: `mkdir -p /app/screenshots`

### What to exclude via .dockerignore (created in task-001)
- .git, screenshots, logs, docs, specs, Images, venv, __pycache__

## Verification

```bash
# Verify Dockerfile exists and has correct base image
grep -q "python:3.11-slim" Dockerfile && echo "OK: correct base image"
grep -q "android-tools-adb" Dockerfile && echo "OK: ADB included"
grep -q "EXPOSE 7860" Dockerfile && echo "OK: port exposed"
grep -q "requirements.txt" Dockerfile && echo "OK: requirements copied"

# Verify Docker build succeeds
docker build -t phonedriver-test . && echo "Build OK"

# Verify image does not contain torch
docker run --rm phonedriver-test pip list | grep -i torch && echo "FAIL: torch found" || echo "OK: no torch"

# Verify image size is reasonable (< 500MB)
docker images phonedriver-test --format "{{.Size}}"
```

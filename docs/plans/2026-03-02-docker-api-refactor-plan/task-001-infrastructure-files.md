# Task 001: Create Project Infrastructure Files

**depends-on**: none

## Objective

Create the foundational files needed for the Docker-based, API-only deployment: `requirements.txt`, `.dockerignore`, `.env.example`.

## BDD References

- `docker_container_operation.feature`: "Build Docker image successfully" - requirements.txt must not contain torch/transformers, must contain openai and gradio
- `docker_container_operation.feature`: "Docker image excludes GPU dependencies"
- `configuration.feature`: "Configure API endpoint via environment variables"

## Files to Create

### requirements.txt
- Include: `openai`, `pillow`, `gradio`, `requests`
- Exclude: `torch`, `transformers`, `flash_attn`, `qwen_vl_utils`
- Pin major versions for reproducibility (e.g., `openai>=1.0`, `gradio>=4.0`)

### .dockerignore
- Exclude: `.git/`, `screenshots/`, `*.log`, `*.pyc`, `__pycache__/`, `Images/`, `specs/`, `docs/`, `.env`, `venv/`, `phonedriver/`

### .env.example
- Document all supported environment variables with example values:
  - `API_BASE_URL=http://host.docker.internal:8000/v1`
  - `API_KEY=EMPTY`
  - `API_MODEL=Qwen/Qwen3-VL-8B-Instruct`
  - `API_TIMEOUT=120`
  - `ADB_SERVER_SOCKET=tcp:host.docker.internal:5037`

## Verification

```bash
# Verify requirements.txt has correct packages
grep -q "openai" requirements.txt && echo "OK: openai found"
grep -q "torch" requirements.txt && echo "FAIL: torch should not be present" || echo "OK: no torch"
grep -q "transformers" requirements.txt && echo "FAIL: transformers should not be present" || echo "OK: no transformers"

# Verify .env.example has all vars
grep -q "API_BASE_URL" .env.example && grep -q "ADB_SERVER_SOCKET" .env.example && echo "OK"

# Verify pip install works (dry run)
pip install --dry-run -r requirements.txt
```

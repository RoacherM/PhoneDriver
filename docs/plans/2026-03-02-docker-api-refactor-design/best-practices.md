# Best Practices

## API Client

### Timeout Configuration
- Vision model inference is 10-100x slower than text
- Default timeout: 120 seconds (configurable via `api_timeout`)
- OpenAI SDK auto-retries connection errors and 5xx (2 retries by default)
- Use `max_retries=3` for unreliable network connections

### Image Handling
- Always use base64 data URIs (`data:image/png;base64,...`)
- This is the only format guaranteed across all backends (vLLM, Ollama, SGLang)
- Ollama specifically does NOT support URL-based image references
- Resize images before encoding (max 1280px) to reduce payload size and API latency

### Error Handling
- Catch `openai.APIConnectionError` for server-down scenarios
- Catch `openai.APITimeoutError` for slow inference
- Return `None` on all API errors (PhoneAgent already handles None with retry)
- Log all errors with context for debugging

## Docker

### Image Size
- Use `python:3.11-slim` base (~41MB)
- Install only `android-tools-adb` for system deps
- Use `--no-cache-dir` with pip to avoid caching wheels
- Use `.dockerignore` to exclude screenshots, logs, .git, Images/

### Security
- Run as non-root user inside container
- Mount config.json as read-only (`:ro`)
- Never hardcode API keys in Dockerfile
- Use environment variables or `.env` file for secrets

### ADB Forwarding
- Host must run `adb -a start-server` (listen on all interfaces, not just localhost)
- Container uses `ADB_SERVER_SOCKET=tcp:host.docker.internal:5037`
- ADB version in container should be compatible with host version
- `host.docker.internal` works natively on macOS Docker Desktop
- Add `extra_hosts: ["host.docker.internal:host-gateway"]` for Linux compatibility

### Networking
- Gradio binds to `0.0.0.0:7860` inside container (already does this)
- Map port `7860:7860` in docker-compose
- API calls go through Docker's default bridge network to external services

## Code Quality

### Minimal Changes Principle
- Only change what's necessary for the API migration
- Preserve `_parse_action()` exactly as-is (it works correctly)
- Preserve all ADB interaction code in `phone_agent.py`
- Preserve Gradio UI structure, only update config-related widgets

### Configuration
- Environment variables take precedence over config.json
- Config.json takes precedence over defaults
- Legacy fields (`use_flash_attention`, `model_name`) accepted silently
- All new fields have sensible defaults

### Logging
- Keep existing logging patterns
- Add API request/response logging at DEBUG level
- Log API errors at ERROR level with full context

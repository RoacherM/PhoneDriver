# PhoneDriver Docker + API Refactor Design

## Context

PhoneDriver is a Python mobile automation agent that uses Qwen3-VL vision-language models to analyze phone screenshots and control Android devices via ADB. Currently it loads the model locally on GPU (`qwen_vl_agent.py` uses `transformers` + PyTorch for local inference).

**Problem**: Running on macOS is impractical because:
1. No NVIDIA GPU available for local inference
2. Docker on macOS cannot passthrough GPU
3. Heavy dependencies (PyTorch ~2GB, transformers, flash_attn)

**Solution**: Decouple inference from control by:
1. Replacing local model inference with OpenAI-compatible API calls
2. Packaging the control logic in a lightweight Docker container
3. Connecting to phones via host ADB server forwarding

## Requirements

### Functional
- R1: Replace all local GPU inference with OpenAI-compatible API calls
- R2: Support any OpenAI-compatible backend (vLLM, Ollama, SGLang, etc.)
- R3: Run control logic in Docker container on macOS
- R4: Connect to Android devices via host ADB server forwarding
- R5: Preserve existing Gradio Web UI functionality
- R6: Preserve existing ADB control logic (tap, swipe, type, wait, terminate)
- R7: Maintain same task execution loop (screenshot -> analyze -> act -> repeat)

### Non-Functional
- R8: Docker image < 500MB (no PyTorch/CUDA)
- R9: API timeout configurable (default 120s for vision inference)
- R10: Graceful error handling for API failures

### User Decisions
- **API Client**: `openai` Python SDK
- **API Backend**: Generic OpenAI-compatible (not locked to specific provider)
- **ADB Mode**: Host ADB server forwarding via `ADB_SERVER_SOCKET`
- **Local Inference**: Remove completely (API-only mode)

## Rationale

### Why OpenAI-compatible API?
- Universal standard supported by vLLM, Ollama, SGLang
- Well-maintained `openai` Python SDK with built-in retry/timeout
- Qwen3-VL confirmed to work with standard vision message format
- No vendor lock-in

### Why Host ADB Server Forwarding?
- Docker Desktop for Mac has no USB passthrough
- ADB client/server architecture designed for this use case
- Container only needs `android-tools-adb` (~5MB), not full Android SDK
- `host.docker.internal` works natively on macOS Docker Desktop

### Why Remove Local Inference?
- Docker image drops from ~8GB to <500MB
- Eliminates PyTorch, transformers, flash_attn, CUDA dependencies
- Clean separation of concerns (inference service vs. control agent)
- Users who want local inference can keep the original code on a GPU machine

## Detailed Design

### Files Changed

| File | Action | Description |
|------|--------|-------------|
| `qwen_vl_agent.py` | **Rewrite** | Replace local model with OpenAI API client |
| `qwen_vl_utils.py` | **Delete** | No longer needed (was for local image processing) |
| `phone_agent.py` | **Minor edit** | Pass API config to QwenVLAgent constructor |
| `config.json` | **Update** | Add API fields, remove GPU fields |
| `ui.py` | **Minor edit** | Update settings UI for API config |
| `Dockerfile` | **New** | Lightweight Python container |
| `docker-compose.yml` | **New** | Service configuration |
| `requirements.txt` | **New** | Python dependencies (openai, pillow, gradio, requests) |
| `.dockerignore` | **New** | Exclude unnecessary files |
| `.env.example` | **New** | Example environment variables |

### Architecture Change

```
BEFORE:
  [Phone] --USB--> [macOS + GPU: PhoneAgent + QwenVL(local)] --ADB--> [Phone]

AFTER:
  [GPU Server: vLLM/Ollama serving Qwen3-VL]
       ^
       | HTTP API (OpenAI-compatible)
       |
  [macOS Docker: PhoneAgent + QwenVL(API client)]
       |
       | ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
       v
  [macOS Host: adb server] --USB--> [Phone]
```

### QwenVLAgent API Client Design

The rewritten `QwenVLAgent` class:

```python
class QwenVLAgent:
    def __init__(self, base_url, api_key, model, temperature, max_tokens, timeout):
        self.client = OpenAI(base_url=base_url, api_key=api_key, timeout=timeout)
        self.model = model
        # ... same system_prompt as before

    def analyze_screenshot(self, screenshot_path, user_request, context):
        # 1. Load image -> base64 encode
        # 2. Build messages (same format, but image as data URI)
        # 3. Call self.client.chat.completions.create()
        # 4. Parse response with same _parse_action() logic

    def _parse_action(self, text):
        # UNCHANGED - same XML/JSON parsing logic
```

Key changes in inference pipeline:
- Image: `PIL.Image.open()` -> resize -> save to buffer -> base64 encode -> `data:image/png;base64,...`
- Messages: `{"type": "image", "image": PIL.Image}` -> `{"type": "image_url", "image_url": {"url": "data:..."}}`
- Inference: `model.generate()` -> `client.chat.completions.create()`
- Output: `processor.batch_decode()` -> `response.choices[0].message.content`

### Config Schema Change

```json
{
  "api_base_url": "http://host.docker.internal:8000/v1",
  "api_key": "EMPTY",
  "api_model": "Qwen/Qwen3-VL-8B-Instruct",
  "api_timeout": 120,
  "device_id": null,
  "screen_width": 1080,
  "screen_height": 2340,
  "screenshot_dir": "./screenshots",
  "max_retries": 3,
  "temperature": 0.1,
  "max_tokens": 512,
  "step_delay": 1.5,
  "enable_visual_debug": true
}
```

Removed fields: `use_flash_attention`, `model_name`
Added fields: `api_base_url`, `api_key`, `api_model`, `api_timeout`

Environment variable overrides (higher priority than config.json):
- `API_BASE_URL` -> `api_base_url`
- `API_KEY` -> `api_key`
- `API_MODEL` -> `api_model`
- `API_TIMEOUT` -> `api_timeout`

### Docker Setup

```
docker-compose up --build
# Requires: macOS host running `adb -a start-server`
# Requires: Remote GPU server running vLLM/Ollama
```

Container exposes Gradio on port 7860, connects to:
- Remote LLM API (configurable URL)
- Host ADB server (host.docker.internal:5037)

## Design Documents

- [BDD Specifications](./bdd-specs.md) - Behavior scenarios and testing strategy
- [Architecture](./architecture.md) - System architecture and component details
- [Best Practices](./best-practices.md) - Security, performance, and code quality guidelines
- BDD feature files: `specs/*.feature` (4 files, ~1040 lines)

# Architecture

## System Overview

```
┌─────────────────────────────────────────────────┐
│  Remote GPU Server                              │
│  ┌─────────────────────────────────────────┐    │
│  │ vLLM / Ollama / SGLang                  │    │
│  │ Serving Qwen3-VL-8B-Instruct           │    │
│  │ OpenAI-compatible API on :8000          │    │
│  └─────────────────────────────────────────┘    │
└────────────────────┬────────────────────────────┘
                     │ HTTP POST /v1/chat/completions
                     │ (JSON + base64 image)
┌────────────────────┼────────────────────────────┐
│  macOS Host        │                            │
│  ┌─────────────────┼──────────────────────┐     │
│  │ Docker          │                      │     │
│  │  ┌──────────────┴─────────────────┐    │     │
│  │  │ PhoneDriver Container          │    │     │
│  │  │                                │    │     │
│  │  │  QwenVLAgent (API client)      │    │     │
│  │  │    - openai SDK                │    │     │
│  │  │    - base64 image encoding     │    │     │
│  │  │    - _parse_action() (same)    │    │     │
│  │  │                                │    │     │
│  │  │  PhoneAgent (orchestrator)     │    │     │
│  │  │    - capture_screenshot()      │    │     │
│  │  │    - execute_action()          │    │     │
│  │  │    - execute_task() loop       │    │     │
│  │  │                                │    │     │
│  │  │  Gradio UI (:7860)             │    │     │
│  │  └──────────────┬─────────────────┘    │     │
│  └─────────────────┼──────────────────────┘     │
│                    │ ADB_SERVER_SOCKET           │
│                    │ tcp:host.docker.internal:5037│
│  ┌─────────────────┴──────────────────────┐     │
│  │ ADB Server (:5037)                     │     │
│  │ Started with: adb -a start-server      │     │
│  └─────────────────┬──────────────────────┘     │
└────────────────────┼────────────────────────────┘
                     │ USB
              ┌──────┴──────┐
              │ Android     │
              │ Phone       │
              └─────────────┘
```

## Component Details

### QwenVLAgent (Rewritten)

**Responsibility**: Send screenshots to remote VLM, parse action responses.

**Constructor**:
```python
QwenVLAgent(
    base_url: str,          # e.g., "http://host.docker.internal:8000/v1"
    api_key: str = "EMPTY", # Most self-hosted servers don't need real keys
    model: str = "Qwen/Qwen3-VL-8B-Instruct",
    temperature: float = 0.1,
    max_tokens: int = 512,
    timeout: float = 120.0,
)
```

**Image Pipeline** (changed):
```
screenshot.png
  -> PIL.Image.open()
  -> resize to max 1280px (preserving aspect ratio)
  -> save to BytesIO as PNG
  -> base64.b64encode()
  -> "data:image/png;base64,{encoded}"
```

**Message Format** (adapted for OpenAI API):
```python
messages = [
    {
        "role": "system",
        "content": self.system_prompt  # String, not list - OpenAI format
    },
    {
        "role": "user",
        "content": [
            {"type": "text", "text": user_query},
            {
                "type": "image_url",
                "image_url": {"url": f"data:image/png;base64,{b64}"}
            },
        ],
    },
]
```

**Preserved Logic** (unchanged):
- `system_prompt` - Same mobile_use tool definition, 999x999 coordinate space
- `_parse_action()` - Same `<tool_call>` XML extraction, JSON parsing
- Coordinate normalization: `coord / 999.0` to [0,1]
- Action mapping: `click` -> `tap`
- Swipe direction inference from coordinate delta
- Thought/Action text extraction via regex
- `check_task_completion()` - Same logic, just using API

### PhoneAgent (Minor Changes)

**Changes**:
- Constructor passes API config to `QwenVLAgent` instead of model/flash_attention
- Remove `model_name` from default config
- Add `api_base_url`, `api_key`, `api_model`, `api_timeout` to config

**Unchanged**:
- All ADB operations (screenshot, tap, swipe, type, wait)
- Task execution loop
- Context tracking
- Session management

### Gradio UI (Minor Changes)

**Changes**:
- Settings tab: replace Flash Attention checkbox with API config fields
- Default config updated

**Unchanged**:
- Task control tab
- Screenshot display
- Log output
- Timer-based UI refresh

## Data Flow: Single Action Cycle

```
1. PhoneAgent.capture_screenshot()
   -> adb shell screencap -p /sdcard/screenshot.png
   -> adb pull /sdcard/screenshot.png ./screenshots/screen_*.png
   -> adb shell rm /sdcard/screenshot.png
   -> returns: local_path

2. QwenVLAgent.analyze_screenshot(local_path, task, context)
   -> PIL.Image.open(local_path)
   -> resize if > 1280px
   -> base64 encode
   -> build messages (system + user with image)
   -> client.chat.completions.create(model, messages, temp, max_tokens)
   -> response.choices[0].message.content
   -> _parse_action(content)
   -> returns: {"action": "tap", "coordinates": [0.5, 0.3], ...}

3. PhoneAgent.execute_action(action)
   -> x = int(0.5 * 1080) = 540
   -> y = int(0.3 * 2340) = 702
   -> adb shell input tap 540 702
   -> sleep(step_delay)
   -> returns: {"success": True, "task_complete": False}
```

## Docker Container

### Dockerfile
- Base: `python:3.11-slim`
- System deps: `android-tools-adb` only
- Python deps: `openai`, `pillow`, `gradio`, `requests`
- No PyTorch, no transformers, no CUDA
- Estimated image size: ~300-400MB

### docker-compose.yml
- Service: `phone-agent`
- Ports: `7860:7860` (Gradio)
- Environment: API config + ADB socket
- Volumes: `config.json` (read-only), `screenshots/` (persistent)
- Extra hosts: `host.docker.internal:host-gateway` (Linux compat)

### Prerequisites
- macOS host: `adb -a start-server` (listening on all interfaces)
- Remote server: vLLM/Ollama serving Qwen3-VL with OpenAI-compatible API
- Phone: USB connected to macOS, USB debugging enabled

# BDD Specifications

## Overview

Four feature files have been created in `specs/` covering all aspects of the refactoring:

| Feature File | Scenarios | Coverage |
|---|---|---|
| `api_vision_analysis.feature` | 28 | API client, image encoding, response parsing, error handling |
| `docker_container_operation.feature` | 18 | Build, startup, ADB forwarding, Gradio, volumes, lifecycle |
| `configuration.feature` | 22 | Config schema, env vars, backward compat, UI settings |
| `end_to_end_task_execution.feature` | 21 | Full cycles, multi-step tasks, error recovery |
| **Total** | **89** | |

## Key Behavioral Contracts

### Image Encoding Contract
- Images MUST be resized to max 1280px (preserving aspect ratio) before encoding
- Images MUST be base64-encoded as `data:image/png;base64,...`
- This matches the original behavior (resize in `analyze_screenshot`)

### Coordinate Space Contract
- Model operates in 999x999 space (unchanged)
- `_parse_action` normalizes to [0,1] by dividing by 999.0 (unchanged)
- `execute_action` scales to device resolution (unchanged)

### Action Mapping Contract
- `click` from model -> `tap` internally (unchanged)
- `swipe` infers direction from coordinate delta (unchanged)
- `type` passes text through (unchanged)
- `wait` converts seconds to milliseconds (unchanged)
- `terminate` signals task completion (unchanged)

### API Error Contract
- Connection refused -> return None (agent retries)
- Timeout -> return None (agent retries)
- HTTP 500 -> return None (SDK auto-retries first)
- HTTP 401/400 -> return None with error log
- Empty response -> return None

### Config Precedence
- Environment variables > config.json > defaults
- Legacy config fields accepted but ignored with warning

## Feature File Locations

```
specs/
  api_vision_analysis.feature
  docker_container_operation.feature
  configuration.feature
  end_to_end_task_execution.feature
```

These specs serve as the acceptance criteria for the refactored implementation.

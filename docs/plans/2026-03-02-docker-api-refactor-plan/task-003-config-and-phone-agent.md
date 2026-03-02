# Task 003: Update Config Schema and phone_agent.py Integration

**depends-on**: task-002

## Objective

Update `config.json` with the new API fields, implement environment variable overrides, handle backward compatibility with legacy configs, and update `phone_agent.py` to pass API config to the rewritten `QwenVLAgent`.

## BDD References

### Config Schema (`configuration.feature`)
- "Configure API endpoint via config.json" - api_base_url, api_key, api_model
- "Configure API endpoint via environment variables" - API_BASE_URL, API_KEY, API_MODEL
- "Environment variables take precedence over config.json"
- "Default API model when not specified" - default "Qwen/Qwen3-VL-8B-Instruct"
- "API key is required" - error if missing from both config and env
- "API base URL is required" - error if missing
- "Configure API request parameters" - temperature, max_tokens from config
- "Default temperature and max_tokens" - 0.1 and 512

### ADB Config (`configuration.feature`)
- "Configure ADB for remote server via environment variable" - ADB_SERVER_SOCKET
- "Configure ADB for direct USB connection (default)"
- "Configure specific device ID"
- "Auto-detect device when device_id is null"

### Backward Compatibility (`configuration.feature`)
- "Legacy config.json without API fields still loads" - existing fields preserved
- "Config.json with both legacy and new fields" - both work together
- "Deprecated fields are logged as warnings" - use_flash_attention
- "Missing config.json uses all defaults"
- "Invalid config.json falls back to defaults"
- "Config.json with unknown fields does not cause errors"

### End-to-end Integration (`end_to_end_task_execution.feature`)
- "Context is initialized for a new task"
- "Context resets between tasks"

## Implementation Details

### config.json changes
- Add: `api_base_url`, `api_key`, `api_model`, `api_timeout`
- Remove: `model_name` (replaced by `api_model`)
- Keep: all device/agent settings (screen_width, screen_height, step_delay, etc.)

### phone_agent.py changes

1. **Update default_config dict** in `PhoneAgent.__init__`:
   - Remove `model_name`, `use_flash_attention`
   - Add `api_base_url`, `api_key`, `api_model`, `api_timeout` with defaults

2. **Add environment variable override logic**:
   - Read `API_BASE_URL`, `API_KEY`, `API_MODEL`, `API_TIMEOUT` from `os.environ`
   - Env vars override config values
   - Implement after config is loaded but before agent initialization

3. **Validate required fields**:
   - `api_base_url` must be set (from config or env) - raise clear error if missing
   - `api_key` must be set - raise clear error with instruction message

4. **Handle deprecated fields**:
   - If `use_flash_attention` in config: log deprecation warning, ignore
   - If `model_name` in config: log deprecation warning, ignore

5. **Update QwenVLAgent initialization** (line 70-74):
   - Change from: `QwenVLAgent(use_flash_attention=..., temperature=..., max_tokens=...)`
   - Change to: `QwenVLAgent(base_url=..., api_key=..., model=..., temperature=..., max_tokens=..., timeout=...)`

6. **Preserve all ADB logic**: `_check_adb_connection`, `_run_adb_command`, `capture_screenshot`, `execute_action`, `_execute_tap/swipe/type/wait` - no changes needed

## Verification

```bash
# Verify config.json has new fields
python -c "
import json
c = json.load(open('config.json'))
assert 'api_base_url' in c, 'Missing api_base_url'
assert 'api_key' in c, 'Missing api_key'
assert 'api_model' in c, 'Missing api_model'
print('Config schema OK')
"

# Verify phone_agent.py syntax
python -c "import ast; ast.parse(open('phone_agent.py').read()); print('Syntax OK')"

# Verify no reference to old model loading
grep -c "use_flash_attention" phone_agent.py  # Should be 0 in agent init
grep -c "from_pretrained" phone_agent.py  # Should be 0
```

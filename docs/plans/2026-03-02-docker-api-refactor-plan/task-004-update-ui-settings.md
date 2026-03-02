# Task 004: Update ui.py Settings for API Configuration

**depends-on**: task-003

## Objective

Update the Gradio UI settings tab to replace GPU-related controls with API configuration fields (base URL, API key, model name).

## BDD References

### UI Config (`configuration.feature`)
- "UI displays API configuration fields" - API Base URL, API Key, Model Name fields
- "UI saves API configuration" - persist to config.json
- "UI reflects current API configuration on load"

### Docker Accessibility (`docker_container_operation.feature`)
- "Gradio UI accessible on mapped port" - responds on port 7860
- "Gradio UI binds to 0.0.0.0 inside container" - already does this (line 486 of ui.py)
- "Gradio UI serves static assets correctly"

## Implementation Details

### Settings tab changes in `create_ui()`

1. **Replace "Advanced Options" section**:
   - Remove: `use_flash_attn` checkbox
   - Add: `api_base_url` textbox (label "API Base URL")
   - Add: `api_key` textbox (label "API Key", type=password for masking)
   - Add: `api_model` textbox (label "Model Name")

2. **Update `get_default_config()`**:
   - Remove: `model_name`, `use_flash_attention`
   - Add: `api_base_url`, `api_key`, `api_model`, `api_timeout`

3. **Update `apply_settings()` function**:
   - Remove: `use_fa2` parameter
   - Add: `api_base_url`, `api_key`, `api_model` parameters
   - Persist new fields to config.json

4. **Update `config_editor` initial value**: Should reflect new config schema

5. **Preserve**: All task control tab, screenshot display, log output, timer, refresh logic

### What NOT to change
- Task Control tab layout
- `execute_task_thread` logic (this calls phone_agent which handles config)
- `update_ui()` function
- `stop_task()` function
- `detect_device_resolution()` function
- Server binding (`server_name="0.0.0.0"`, `server_port=7860`)

## Verification

```bash
# Verify ui.py syntax
python -c "import ast; ast.parse(open('ui.py').read()); print('Syntax OK')"

# Verify no reference to flash attention in UI
grep -c "flash_attn" ui.py  # Should be 0
grep -c "use_flash_attention" ui.py  # Should be 0

# Verify API fields are present
grep -c "api_base_url\|API Base URL" ui.py  # Should be > 0
grep -c "api_key\|API Key" ui.py  # Should be > 0
```

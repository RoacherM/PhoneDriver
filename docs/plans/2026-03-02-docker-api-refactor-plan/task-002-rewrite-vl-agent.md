# Task 002: Rewrite qwen_vl_agent.py as OpenAI API Client

**depends-on**: none

## Objective

Replace the entire local GPU inference pipeline in `qwen_vl_agent.py` with an OpenAI-compatible API client using the `openai` Python SDK. Also delete `qwen_vl_utils.py` which is no longer needed.

## BDD References

### Image Encoding (`api_vision_analysis.feature`)
- "Encode screenshot as base64 for API submission" - base64 with `data:image/png;base64,` prefix
- "Resize oversized screenshot before encoding" - max 1280px, preserve aspect ratio

### API Request Construction (`api_vision_analysis.feature`)
- "Send screenshot with task to remote API" - messages with system/user roles, image_url content type
- "Include action history in API request" - "Step N: action element" format
- "Limit action history to last 5 actions"

### Response Parsing (`api_vision_analysis.feature`)
- "Parse tap action from API response" - click -> tap mapping, coordinate normalization
- "Parse swipe action from API response" - direction inference
- "Parse type action from API response"
- "Parse wait action from API response" - seconds to ms conversion
- "Parse terminate action with success/failure status"
- All "Normalize coordinates from 999x999 space" scenarios
- All "Infer swipe direction from coordinates" scenarios

### Validation (`api_vision_analysis.feature`)
- "Reject tap action missing coordinates"
- "Reject type action missing text"
- "Handle response without tool_call tags"
- "Handle response with malformed JSON in tool_call"
- "Handle response with missing arguments key"

### Error Handling (`api_vision_analysis.feature`)
- "Handle API connection refused" - return None, log error, don't crash
- "Handle API request timeout" - return None
- "Handle API HTTP 500/401/429 error" - return None
- "Handle API response with empty content" - return None
- "Handle API response with unexpected format" - return None

### Task Completion (`api_vision_analysis.feature`)
- "Check task completion returns success" - confidence 0.9
- "Check task completion returns failure" - confidence 0.7
- "Check task completion handles API error gracefully" - confidence 0.0

### Constructor Change (`configuration.feature`)
- "QwenVLAgent no longer accepts GPU-related parameters"
- "QwenVLAgent accepts API configuration parameters" - base_url, api_key, model, temperature, max_tokens

## Implementation Details

### What to remove from qwen_vl_agent.py
- All `import torch` references
- `from transformers import ...` imports
- `from qwen_vl_utils import process_vision_info`
- `model.generate()` pipeline
- `processor` / `tokenizer` usage
- GPU cache clearing (`torch.cuda.empty_cache()`)
- `flash_attention` logic

### What to add
- `from openai import OpenAI` and `import openai` (for exception types)
- `import base64, io` (for image encoding)
- OpenAI client initialization in `__init__`
- Image-to-base64 conversion in `analyze_screenshot`
- `client.chat.completions.create()` call in `_generate_action`

### What to preserve exactly
- `system_prompt` string (the mobile_use tool definition) - copy verbatim
- `_parse_action()` method - copy verbatim (same XML/JSON parsing logic)
- `analyze_screenshot()` method signature: `(self, screenshot_path, user_request, context)`
- `check_task_completion()` method signature and return format
- Image resize logic (max 1280px, preserve aspect ratio)
- Action history formatting ("Step N: action element", last 5)
- All coordinate normalization (divide by 999.0)
- All action mapping (click -> tap, swipe direction inference)

### What to change in message format
- System message: `{"role": "system", "content": self.system_prompt}` (string, not list)
- User message image: `{"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}` instead of `{"type": "image", "image": PIL.Image}`
- Response extraction: `response.choices[0].message.content` instead of `processor.batch_decode()`

### Delete qwen_vl_utils.py
- This file only contained `process_vision_info()` for local inference
- No longer imported by the rewritten `qwen_vl_agent.py`

## Verification

```bash
# Verify the file has no torch/transformers imports
grep -c "import torch" qwen_vl_agent.py  # Should be 0
grep -c "from transformers" qwen_vl_agent.py  # Should be 0
grep -c "from qwen_vl_utils" qwen_vl_agent.py  # Should be 0

# Verify the file imports openai
grep -c "from openai import OpenAI" qwen_vl_agent.py  # Should be 1

# Verify qwen_vl_utils.py is deleted
test ! -f qwen_vl_utils.py && echo "OK: deleted"

# Verify Python syntax
python -c "import ast; ast.parse(open('qwen_vl_agent.py').read()); print('Syntax OK')"

# Verify key methods exist
python -c "
from inspect import signature
# Can't fully import without openai installed, but check syntax
import ast
tree = ast.parse(open('qwen_vl_agent.py').read())
methods = [n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)]
assert 'analyze_screenshot' in methods, 'Missing analyze_screenshot'
assert '_parse_action' in methods, 'Missing _parse_action'
assert 'check_task_completion' in methods, 'Missing check_task_completion'
assert '_generate_action' in methods, 'Missing _generate_action'
print('All key methods present')
"
```

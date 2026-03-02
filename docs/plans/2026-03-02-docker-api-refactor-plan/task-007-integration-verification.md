# Task 007: End-to-end Integration Verification

**depends-on**: task-003, task-004, task-006

## Objective

Verify the entire refactored system works end-to-end: Docker build, container startup, Gradio UI access, API client configuration, and ADB forwarding.

## BDD References

### End-to-end (`end_to_end_task_execution.feature`)
- "Execute a single interaction cycle"
- "Full task execution inside Docker container"
- "Multiple sequential tasks via Gradio UI"

### Docker (`docker_container_operation.feature`)
- "Build Docker image successfully"
- "Container starts with default configuration"
- "Gradio UI accessible on mapped port"
- "ADB commands execute through forwarded connection"

## Verification Steps

### Step 1: Clean build
```bash
docker compose build --no-cache
# Expected: Build completes without errors
```

### Step 2: Image inspection
```bash
# Check image size
docker images phonedriver-test --format "{{.Size}}"
# Expected: < 500MB

# Check no GPU deps
docker run --rm phone-agent pip list 2>/dev/null | grep -iE "torch|transformers|cuda"
# Expected: no output (no GPU packages)
```

### Step 3: Container startup
```bash
# Create .env with test values
cat > .env << 'EOF'
API_BASE_URL=http://host.docker.internal:8000/v1
API_KEY=test-key
API_MODEL=Qwen/Qwen3-VL-8B-Instruct
EOF

docker compose up -d
sleep 5
docker compose ps
# Expected: container running, healthy
```

### Step 4: Gradio UI accessibility
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:7860
# Expected: 200
```

### Step 5: ADB connectivity (requires phone connected to host)
```bash
# On host first:
adb -a start-server

# Then check from container:
docker compose exec phone-agent adb devices
# Expected: device listed (if phone is connected)
```

### Step 6: Python import check inside container
```bash
docker compose exec phone-agent python -c "
from openai import OpenAI
from qwen_vl_agent import QwenVLAgent
from phone_agent import PhoneAgent
print('All imports OK')
"
# Expected: "All imports OK"
```

### Step 7: Cleanup
```bash
docker compose down
rm -f .env
```

## Success Criteria

All verification steps pass:
- Docker image builds < 500MB with no GPU dependencies
- Container starts and stays healthy
- Gradio UI responds on port 7860
- ADB connectivity works through host forwarding
- All Python modules import successfully

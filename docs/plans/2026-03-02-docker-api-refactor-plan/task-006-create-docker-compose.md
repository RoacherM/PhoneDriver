# Task 006: Create docker-compose.yml

**depends-on**: task-005

## Objective

Create a docker-compose.yml that configures the PhoneDriver container with correct port mapping, environment variables, volume mounts, and host networking.

## BDD References

### Startup (`docker_container_operation.feature`)
- "Container starts with environment variables" - API_BASE_URL, API_KEY, API_MODEL, ADB_SERVER_SOCKET
- "Container respects config.json mounted as volume"
- "Environment variables override config.json values"

### Networking (`docker_container_operation.feature`)
- "Gradio UI accessible on mapped port" - 7860:7860
- "Connect to ADB via host server forwarding" - host.docker.internal:5037

### Volumes (`docker_container_operation.feature`)
- "Screenshots persist via volume mount" - ./screenshots:/app/screenshots
- "Config file mounted as read-only" - ./config.json:/app/config.json:ro

### Lifecycle (`docker_container_operation.feature`)
- "Container restarts after crash" - restart: unless-stopped
- "Container resource limits" - memory limit, no GPU

## Implementation Details

### docker-compose.yml specification

- **Service name**: `phone-agent`
- **Build context**: current directory
- **Ports**: `7860:7860`
- **Environment variables** (with defaults from .env file):
  - `API_BASE_URL`
  - `API_KEY`
  - `API_MODEL`
  - `API_TIMEOUT`
  - `ADB_SERVER_SOCKET=tcp:host.docker.internal:5037`
  - `PYTHONUNBUFFERED=1`
- **env_file**: `.env` (optional, won't fail if missing)
- **Volumes**:
  - `./config.json:/app/config.json:ro`
  - `./screenshots:/app/screenshots`
- **extra_hosts**: `host.docker.internal:host-gateway` (Linux compatibility)
- **restart**: `unless-stopped`
- **deploy.resources.limits.memory**: `2g`

## Verification

```bash
# Verify docker-compose.yml syntax
docker compose config && echo "Config OK"

# Verify key sections exist
grep -q "7860:7860" docker-compose.yml && echo "OK: port mapping"
grep -q "ADB_SERVER_SOCKET" docker-compose.yml && echo "OK: ADB env"
grep -q "host.docker.internal" docker-compose.yml && echo "OK: host networking"
grep -q "unless-stopped" docker-compose.yml && echo "OK: restart policy"

# Verify compose up works (detached, then stop)
docker compose up --build -d && docker compose ps && docker compose down
```

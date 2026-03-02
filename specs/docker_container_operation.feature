Feature: Docker Container Operation
  As a developer deploying PhoneDriver
  I want to run the control logic in a Docker container on macOS
  So that the environment is reproducible and isolated from the host

  Background:
    Given a Dockerfile exists in the project root
    And a docker-compose.yml exists in the project root
    And the host machine is running macOS
    And the host has an ADB server running on port 5037

  # --------------------------------------------------------------------------
  # Container build
  # --------------------------------------------------------------------------

  Scenario: Build Docker image successfully
    Given the Dockerfile uses a Python 3.11+ base image
    And requirements.txt does not contain torch or transformers
    And requirements.txt contains the openai package
    And requirements.txt contains gradio
    When the Docker image is built
    Then the build should complete without errors
    And the image should contain Python 3.11 or later
    And the image should have the openai package installed
    And the image should not contain torch or transformers

  Scenario: Docker image excludes GPU dependencies
    When the Docker image is inspected
    Then the image size should be significantly smaller than a GPU-enabled image
    And the image should not contain CUDA libraries
    And the image should not contain torch
    And the image should not contain transformers

  Scenario: Docker image includes project files
    When the Docker image is built
    Then the image should contain the following files:
      | file              |
      | phone_agent.py    |
      | qwen_vl_agent.py  |
      | ui.py             |
      | config.json       |
      | requirements.txt  |

  # --------------------------------------------------------------------------
  # Container startup
  # --------------------------------------------------------------------------

  Scenario: Container starts with default configuration
    When the container is started via docker-compose
    Then the container should be running
    And the container should have a healthy status within 30 seconds
    And the Gradio UI process should be running inside the container

  Scenario: Container starts with environment variables
    Given the following environment variables are set:
      | variable              | value                      |
      | API_BASE_URL          | http://inference:8000/v1   |
      | API_KEY               | my-secret-key              |
      | API_MODEL             | Qwen/Qwen3-VL-8B-Instruct |
      | ADB_SERVER_SOCKET     | tcp:host.docker.internal:5037 |
    When the container is started
    Then the application should read and apply each environment variable
    And the API client should be configured with base_url "http://inference:8000/v1"
    And the API client should use api_key "my-secret-key"

  Scenario: Container respects config.json mounted as volume
    Given a custom config.json is mounted at /app/config.json
    And the config.json contains:
      """
      {
        "device_id": null,
        "screen_width": 1440,
        "screen_height": 3200,
        "temperature": 0.2,
        "api_base_url": "http://my-server:8000/v1",
        "api_key": "key-from-config",
        "api_model": "Qwen/Qwen3-VL-8B-Instruct"
      }
      """
    When the container is started
    Then the agent should use screen dimensions 1440x3200
    And the agent should use temperature 0.2

  Scenario: Environment variables override config.json values
    Given config.json contains api_base_url "http://config-server/v1"
    And the environment variable API_BASE_URL is set to "http://env-server/v1"
    When the container is started
    Then the API client should use base_url "http://env-server/v1"

  # --------------------------------------------------------------------------
  # ADB connectivity through host server
  # --------------------------------------------------------------------------

  Scenario: Connect to ADB via host server forwarding
    Given the environment variable ADB_SERVER_SOCKET is "tcp:host.docker.internal:5037"
    And the host ADB server has an Android device connected
    When the container runs "adb devices"
    Then the output should list at least one device
    And the device should have status "device"

  Scenario: ADB commands execute through forwarded connection
    Given the container is connected to the host ADB server
    And an Android device is available
    When the agent runs the ADB command "shell echo Connected"
    Then the command should return "Connected"
    And no error should be raised

  Scenario: Screenshot capture works through ADB forwarding
    Given the container is connected to the host ADB server
    And an Android device is available
    When the agent captures a screenshot
    Then the screenshot file should be saved inside the container
    And the screenshot should be a valid PNG image
    And the screenshot dimensions should match the device resolution

  Scenario: Handle ADB server not reachable from container
    Given the environment variable ADB_SERVER_SOCKET is "tcp:host.docker.internal:5037"
    And the host ADB server is not running
    When the container attempts to connect to ADB
    Then an error should be raised indicating the ADB server is unreachable
    And the error message should suggest checking the host ADB server

  Scenario: Handle no Android device connected to host ADB
    Given the container is connected to the host ADB server
    And no Android devices are connected to the host
    When the agent checks for ADB devices
    Then an error should be raised indicating no devices are connected
    And the error message should mention "No devices connected"

  # --------------------------------------------------------------------------
  # Gradio UI accessibility
  # --------------------------------------------------------------------------

  Scenario: Gradio UI accessible on mapped port
    Given the docker-compose.yml maps port 7860 to host port 7860
    When the container is running
    And a client connects to http://localhost:7860
    Then the Gradio UI should respond with HTTP 200
    And the response should contain the Phone Agent Control Panel

  Scenario: Gradio UI binds to 0.0.0.0 inside container
    When the container is running
    Then the Gradio server inside the container should listen on 0.0.0.0:7860
    And the UI should be accessible from outside the container

  Scenario: Gradio UI serves static assets correctly
    Given the container is running
    When a client requests the Gradio UI
    Then JavaScript assets should load successfully
    And CSS assets should load successfully
    And the task input form should be rendered

  # --------------------------------------------------------------------------
  # Volume mounts and persistence
  # --------------------------------------------------------------------------

  Scenario: Screenshots persist via volume mount
    Given the docker-compose.yml mounts ./screenshots to /app/screenshots
    When the agent captures a screenshot inside the container
    Then the screenshot should be accessible on the host at ./screenshots/
    And the screenshot filename should follow the pattern "screen_{session}_{timestamp}.png"

  Scenario: Logs persist via volume mount
    Given the docker-compose.yml mounts ./logs to /app/logs
    When the agent executes a task
    Then the log file should be written inside the container
    And the log file should be accessible on the host

  Scenario: Config file mounted as read-only
    Given config.json is mounted as a read-only volume
    When the application reads the configuration
    Then the configuration should load successfully
    And any attempt to write to config.json inside the container should fail gracefully

  # --------------------------------------------------------------------------
  # Container lifecycle
  # --------------------------------------------------------------------------

  Scenario: Container stops gracefully
    Given the container is running and executing a task
    When a SIGTERM signal is sent to the container
    Then the Gradio server should shut down cleanly
    And the container should exit with code 0 within 10 seconds

  Scenario: Container restarts after crash
    Given the docker-compose.yml has restart policy "unless-stopped"
    When the container process exits unexpectedly
    Then Docker should restart the container automatically
    And the Gradio UI should become available again

  Scenario: Container resource limits
    Given the docker-compose.yml specifies memory limit of 2GB
    When the container is running
    Then the container should not exceed the configured memory limit
    And the application should function within the memory constraint
    And no GPU resources should be allocated to the container

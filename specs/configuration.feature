Feature: Configuration
  As a PhoneDriver user
  I want flexible configuration for the API endpoint, ADB connection, and agent behavior
  So that I can deploy PhoneDriver in different environments

  # --------------------------------------------------------------------------
  # API endpoint configuration
  # --------------------------------------------------------------------------

  Scenario: Configure API endpoint via config.json
    Given a config.json file contains:
      """
      {
        "api_base_url": "http://inference-server:8000/v1",
        "api_key": "sk-my-secret-key",
        "api_model": "Qwen/Qwen3-VL-8B-Instruct"
      }
      """
    When the QwenVLAgent is initialized
    Then the OpenAI client should be created with base_url "http://inference-server:8000/v1"
    And the OpenAI client should use api_key "sk-my-secret-key"
    And API requests should specify model "Qwen/Qwen3-VL-8B-Instruct"

  Scenario: Configure API endpoint via environment variables
    Given the following environment variables are set:
      | variable     | value                          |
      | API_BASE_URL | http://env-server:8000/v1      |
      | API_KEY      | sk-env-key                     |
      | API_MODEL    | Qwen/Qwen3-VL-30B-A3B-Instruct |
    When the QwenVLAgent is initialized
    Then the OpenAI client should use base_url "http://env-server:8000/v1"
    And the OpenAI client should use api_key "sk-env-key"
    And API requests should specify model "Qwen/Qwen3-VL-30B-A3B-Instruct"

  Scenario: Environment variables take precedence over config.json
    Given config.json contains api_base_url "http://config-url/v1"
    And the environment variable API_BASE_URL is "http://env-url/v1"
    When the QwenVLAgent is initialized
    Then the OpenAI client should use base_url "http://env-url/v1"

  Scenario: Default API model when not specified
    Given config.json does not contain an api_model field
    And no API_MODEL environment variable is set
    When the QwenVLAgent is initialized
    Then the default model should be "Qwen/Qwen3-VL-8B-Instruct"

  Scenario: API key is required
    Given config.json does not contain an api_key field
    And no API_KEY environment variable is set
    When the QwenVLAgent is initialized
    Then an error should be raised indicating the API key is missing
    And the error message should instruct the user to set API_KEY or api_key in config.json

  Scenario: API base URL is required
    Given config.json does not contain an api_base_url field
    And no API_BASE_URL environment variable is set
    When the QwenVLAgent is initialized
    Then an error should be raised indicating the API base URL is missing

  Scenario: Configure API request parameters
    Given config.json contains:
      """
      {
        "api_base_url": "http://localhost:8000/v1",
        "api_key": "test-key",
        "temperature": 0.3,
        "max_tokens": 1024
      }
      """
    When the QwenVLAgent is initialized
    Then API requests should use temperature 0.3
    And API requests should use max_tokens 1024

  Scenario: Default temperature and max_tokens
    Given config.json does not contain temperature or max_tokens
    When the QwenVLAgent is initialized
    Then the default temperature should be 0.1
    And the default max_tokens should be 512

  # --------------------------------------------------------------------------
  # ADB connection mode configuration
  # --------------------------------------------------------------------------

  Scenario: Configure ADB for remote server via environment variable
    Given the environment variable ADB_SERVER_SOCKET is "tcp:host.docker.internal:5037"
    When the PhoneAgent initializes ADB
    Then ADB commands should connect through "host.docker.internal:5037"
    And the agent should not attempt to start a local ADB server

  Scenario: Configure ADB for direct USB connection (default)
    Given no ADB_SERVER_SOCKET environment variable is set
    When the PhoneAgent initializes ADB
    Then ADB should use the default local server
    And the agent should run "adb devices" to detect connected devices

  Scenario: Configure specific device ID
    Given config.json contains device_id "ABCDEF123456"
    When the PhoneAgent initializes ADB
    Then ADB commands should target device "ABCDEF123456"
    And commands should include "-s ABCDEF123456"

  Scenario: Auto-detect device when device_id is null
    Given config.json contains device_id null
    And one Android device is connected
    When the PhoneAgent initializes ADB
    Then the agent should auto-detect the connected device
    And the detected device ID should be stored in the config

  Scenario: Configure screen resolution
    Given config.json contains:
      | field         | value |
      | screen_width  | 1440  |
      | screen_height | 3200  |
    When the PhoneAgent is initialized
    Then the screen width should be 1440
    And the screen height should be 3200
    And tap coordinates should be scaled to 1440x3200

  Scenario: Auto-correct screen resolution from device
    Given config.json contains screen_width 1080 and screen_height 2340
    And the connected device reports resolution 1440x3200
    When the PhoneAgent verifies screen resolution
    Then the config should be auto-corrected to 1440x3200
    And a warning should be logged about the resolution mismatch

  # --------------------------------------------------------------------------
  # Backward-compatible config.json
  # --------------------------------------------------------------------------

  Scenario: Legacy config.json without API fields still loads
    Given a config.json file from the pre-refactor version:
      """
      {
        "device_id": null,
        "screen_width": 1080,
        "screen_height": 2340,
        "screenshot_dir": "./screenshots",
        "max_retries": 3,
        "use_flash_attention": true,
        "temperature": 0.1,
        "max_tokens": 512,
        "step_delay": 1.5,
        "enable_visual_debug": true
      }
      """
    When the configuration is loaded
    Then all existing fields should be preserved with their values
    And the agent should look for API configuration in environment variables
    And the use_flash_attention field should be accepted but ignored

  Scenario: Config.json with both legacy and new fields
    Given a config.json file contains:
      """
      {
        "device_id": null,
        "screen_width": 1080,
        "screen_height": 2340,
        "screenshot_dir": "./screenshots",
        "max_retries": 3,
        "use_flash_attention": true,
        "temperature": 0.1,
        "max_tokens": 512,
        "step_delay": 1.5,
        "enable_visual_debug": true,
        "api_base_url": "http://localhost:8000/v1",
        "api_key": "sk-test",
        "api_model": "Qwen/Qwen3-VL-8B-Instruct"
      }
      """
    When the configuration is loaded
    Then the agent should use the API configuration
    And device settings should still apply (screen_width, screen_height, device_id)
    And agent behavior settings should still apply (step_delay, max_retries)

  Scenario: Deprecated fields are logged as warnings
    Given config.json contains the field "use_flash_attention" set to true
    When the configuration is loaded
    Then a deprecation warning should be logged for "use_flash_attention"
    And the field should not cause an error
    And the agent should continue initialization

  Scenario: Missing config.json uses all defaults
    Given no config.json file exists
    When the configuration is loaded
    Then default values should be applied:
      | field            | default_value                |
      | screen_width     | 1080                         |
      | screen_height    | 2340                         |
      | screenshot_dir   | ./screenshots                |
      | max_retries      | 3                            |
      | temperature      | 0.1                          |
      | max_tokens       | 512                          |
      | step_delay       | 1.5                          |
    And the agent should require API configuration from environment variables

  Scenario: Invalid config.json falls back to defaults
    Given config.json contains invalid JSON
    When the configuration is loaded
    Then the default configuration should be used
    And a warning should be logged about the malformed config file

  Scenario: Config.json with unknown fields does not cause errors
    Given config.json contains an unknown field "future_setting" with value "something"
    When the configuration is loaded
    Then the unknown field should be ignored
    And no error should be raised
    And the agent should initialize normally

  # --------------------------------------------------------------------------
  # Gradio UI configuration
  # --------------------------------------------------------------------------

  Scenario: UI displays API configuration fields
    When the Gradio UI settings tab is rendered
    Then the settings should include fields for:
      | field         |
      | API Base URL  |
      | API Key       |
      | Model Name    |
    And the API Key field should be a password input (masked)

  Scenario: UI saves API configuration
    Given the user enters API base URL "http://new-server/v1"
    And the user enters API key "sk-new-key"
    And the user clicks Save Settings
    When the configuration is persisted
    Then config.json should contain api_base_url "http://new-server/v1"
    And config.json should contain api_key "sk-new-key"

  Scenario: UI reflects current API configuration on load
    Given config.json contains api_base_url "http://my-server/v1"
    When the Gradio UI is loaded
    Then the API Base URL field should display "http://my-server/v1"

  # --------------------------------------------------------------------------
  # QwenVLAgent constructor signature change
  # --------------------------------------------------------------------------

  Scenario: QwenVLAgent no longer accepts GPU-related parameters
    When the QwenVLAgent is initialized with default parameters
    Then the constructor should not accept "device_map" parameter
    And the constructor should not accept "dtype" parameter
    And the constructor should not accept "use_flash_attention" parameter

  Scenario: QwenVLAgent accepts API configuration parameters
    When the QwenVLAgent is initialized
    Then the constructor should accept these parameters:
      | parameter   | type   |
      | base_url    | str    |
      | api_key     | str    |
      | model       | str    |
      | temperature | float  |
      | max_tokens  | int    |

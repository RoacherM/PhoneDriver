Feature: End-to-end Task Execution
  As a user of PhoneDriver
  I want to issue a natural language task and have it executed on my phone
  So that I can automate mobile interactions without manual intervention

  Background:
    Given the PhoneAgent is initialized with a valid configuration
    And the QwenVLAgent is configured to use the remote API
    And an Android device is connected via ADB
    And the API server is running and reachable

  # --------------------------------------------------------------------------
  # Full cycle: screenshot -> API call -> action execution
  # --------------------------------------------------------------------------

  Scenario: Execute a single interaction cycle
    Given the user request is "Open Chrome"
    When the agent executes a single cycle
    Then the agent should capture a screenshot from the device via ADB
    And the screenshot should be base64-encoded
    And the screenshot should be sent to the API along with the task description
    And the API response should be parsed into an action
    And the action should be executed on the device via ADB
    And the cycle result should include success status

  Scenario: Full task - open an application
    Given the user request is "Open the Settings app"
    And the device is on the home screen
    And the API returns the following sequence of actions:
      | step | action | coordinate | detail          |
      | 1    | click  | [500, 800] | Settings icon   |
      | 2    | terminate |         | status: success |
    When the agent executes the task
    Then the agent should complete in 2 cycles
    And the first cycle should tap at the normalized coordinates of [500, 800]
    And the second cycle should detect task completion
    And the final result should indicate success

  Scenario: Full task - search in browser
    Given the user request is "Open Chrome and search for weather in New York"
    And the API returns the following sequence of actions:
      | step | action | coordinate       | detail                |
      | 1    | click  | [250, 900]       | Chrome icon           |
      | 2    | click  | [500, 200]       | Search bar            |
      | 3    | type   |                  | weather in New York   |
      | 4    | click  | [900, 200]       | Search button         |
      | 5    | terminate |               | status: success       |
    When the agent executes the task with max_cycles 15
    Then the agent should complete in 5 cycles
    And the agent should have captured 5 screenshots
    And each API call should include the updated action history
    And the final result should indicate success

  Scenario: Action history accumulates across cycles
    Given the user request is "Open Chrome and search for weather"
    When the agent completes cycle 1 with action tap at [250, 900]
    And the agent starts cycle 2
    Then the API request for cycle 2 should include:
      | step | action | elementName |
      | 1    | tap    | (from cycle 1 observation) |
    When the agent completes cycle 2 with action tap at [500, 200]
    And the agent starts cycle 3
    Then the API request for cycle 3 should include 2 previous actions

  # --------------------------------------------------------------------------
  # Screenshot -> ADB pipeline
  # --------------------------------------------------------------------------

  Scenario: Screenshot is captured and stored correctly
    When the agent captures a screenshot
    Then the ADB command "shell screencap -p /sdcard/screenshot.png" should be executed
    And the ADB command "pull /sdcard/screenshot.png {local_path}" should be executed
    And the ADB command "shell rm /sdcard/screenshot.png" should be executed
    And the local screenshot file should exist
    And the screenshot path should be added to the context

  Scenario: Screenshot filename follows session convention
    Given the session ID is "20260302_143000"
    When the agent captures a screenshot at timestamp 1741000000
    Then the screenshot should be saved as "screenshots/screen_20260302_143000_1741000000.png"

  # --------------------------------------------------------------------------
  # Action execution via ADB
  # --------------------------------------------------------------------------

  Scenario: Execute tap action on device
    Given the screen resolution is 1080x2340
    And the API returns a tap action with normalized coordinates [0.500, 0.751]
    When the action is executed
    Then the ADB command should be "shell input tap 540 1757"
    And the coordinates should be clamped to screen bounds

  Scenario: Execute swipe action on device
    Given the screen resolution is 1080x2340
    And the API returns a swipe action with direction "up"
    When the action is executed
    Then the ADB command should contain "shell input swipe"
    And the swipe should go from center upward
    And the swipe duration should be 300ms

  Scenario: Execute type action on device
    Given the API returns a type action with text "hello world"
    When the action is executed
    Then the ADB command should contain 'shell input text'
    And spaces should be escaped as "%s"

  Scenario: Execute wait action
    Given the API returns a wait action with waitTime 2500
    When the action is executed
    Then the agent should pause for 2.5 seconds
    And no ADB command should be sent

  Scenario: Step delay applied after each action
    Given the step_delay is configured as 1.5 seconds
    When a tap action is executed
    Then the agent should wait 1.5 seconds after the ADB command
    And then proceed to the next cycle

  # --------------------------------------------------------------------------
  # Task completion detection via API
  # --------------------------------------------------------------------------

  Scenario: Task completes when API returns terminate with success
    Given the user request is "Open Settings"
    And during cycle 3 the API returns a terminate action with status "success"
    When the agent processes the action
    Then the task should be marked as complete
    And no further cycles should execute
    And the result should show success True and cycles 3

  Scenario: Task completes when API returns terminate with failure
    Given the user request is "Open a non-existent app"
    And during cycle 2 the API returns a terminate action with status "failure"
    When the agent processes the action
    Then the task should be marked as complete
    And the result should show task_complete True
    And the log should indicate the task failed

  Scenario: Task hits max cycles and performs completion check
    Given the user request is "Perform a complex multi-step task"
    And max_cycles is set to 5
    And the API never returns a terminate action during regular cycles
    When the agent reaches cycle 5 without completion
    Then the agent should capture a final screenshot
    And the agent should call check_task_completion via the API
    And if the completion check returns success, the task should be marked complete
    And the result should show cycles 5

  Scenario: Max cycles reached and completion check says incomplete
    Given the user request is "Perform a complex task"
    And max_cycles is set to 3
    And the API never returns a terminate action
    And the completion check returns status "failure"
    When the agent finishes
    Then the result should show success False
    And the result should show task_complete False
    And the log should indicate "TASK INCOMPLETE after 3 cycles"

  # --------------------------------------------------------------------------
  # Error recovery during execution
  # --------------------------------------------------------------------------

  Scenario: API error during a cycle does not abort the entire task
    Given the user request is "Open Settings"
    And the API fails on cycle 2 but succeeds on cycle 3
    When the agent executes the task with max_retries 3
    Then the agent should retry after the failure
    And the agent should wait 2 seconds before retrying
    And the task should continue from cycle 3

  Scenario: ADB command failure during action execution
    Given the user request is "Tap on something"
    And the API returns a valid tap action
    And the ADB tap command fails with a CalledProcessError
    When the action is executed
    Then the result should show success False
    And the error message should be captured
    And the task should continue to the next cycle if retries remain

  Scenario: Consecutive failures exhaust max retries
    Given the user request is "Do something"
    And max_retries is set to 3
    And the API fails on every cycle
    When the agent executes the task
    Then the agent should stop after 3 cycles
    And the result should show success False
    And the log should indicate "Max retries exceeded"

  Scenario: Screenshot capture failure
    Given the user request is "Open Chrome"
    And the ADB screenshot command fails
    When the agent attempts a cycle
    Then the cycle should raise an exception
    And the error should be logged
    And the task should attempt retry if retries remain

  # --------------------------------------------------------------------------
  # Context and state management
  # --------------------------------------------------------------------------

  Scenario: Context is initialized for a new task
    When a new task "Open Settings" is started
    Then the context should contain:
      | field            | value          |
      | task_request     | Open Settings  |
      | previous_actions | []             |
      | current_app      | Home           |
    And a new session_id should be generated
    And the screenshots list should be empty

  Scenario: Context resets between tasks
    Given the agent has completed a task with 5 actions recorded
    When a new task is started
    Then the previous_actions list should be empty
    And a new session_id should be generated
    And the screenshots list should be empty

  Scenario: Keyboard interrupt stops execution gracefully
    Given the user request is "Open Settings"
    And the task is running
    When a KeyboardInterrupt is raised during execution
    Then the task should stop immediately
    And the interrupt should propagate to the caller
    And the log should indicate "Task interrupted by user"

  # --------------------------------------------------------------------------
  # End-to-end in Docker
  # --------------------------------------------------------------------------

  Scenario: Full task execution inside Docker container
    Given PhoneDriver is running inside a Docker container
    And ADB is connected via host.docker.internal:5037
    And the API server is reachable from the container
    And the Gradio UI is accessible on port 7860
    When a user submits task "Open Chrome" through the Gradio UI
    Then the agent should capture screenshots via the forwarded ADB connection
    And the agent should send screenshots to the API server
    And the agent should execute actions via the forwarded ADB connection
    And the task progress should be visible in the Gradio log panel
    And screenshots should be visible in the Gradio image panel

  Scenario: Multiple sequential tasks via Gradio UI
    Given the agent has completed a task
    When a new task is submitted through the Gradio UI
    Then the agent context should be reset
    And the agent should reuse the existing API client
    And the new task should execute independently of the previous one

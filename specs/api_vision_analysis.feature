Feature: API-based Vision Analysis
  As a PhoneDriver automation agent
  I want to analyze phone screenshots via an OpenAI-compatible API
  So that I can determine the next action without requiring a local GPU

  Background:
    Given the API client is configured with:
      | setting    | value                          |
      | base_url   | http://localhost:8000/v1       |
      | api_key    | test-key-123                   |
      | model      | Qwen/Qwen3-VL-8B-Instruct     |
    And the system prompt contains the mobile_use tool definition
    And the coordinate space is 999x999

  # --------------------------------------------------------------------------
  # Screenshot encoding and submission
  # --------------------------------------------------------------------------

  Scenario: Encode screenshot as base64 for API submission
    Given a screenshot file exists at "screenshots/screen_test.png"
    And the screenshot has dimensions 1080x2340
    When the screenshot is prepared for the API request
    Then the image should be base64-encoded as a data URI with prefix "data:image/png;base64,"
    And the encoded payload should be a valid PNG image when decoded

  Scenario: Resize oversized screenshot before encoding
    Given a screenshot file exists at "screenshots/screen_large.png"
    And the screenshot has dimensions 2160x4680
    When the screenshot is prepared for the API request
    Then the image should be resized so the maximum dimension is 1280 pixels
    And the aspect ratio should be preserved
    And the resized image should be base64-encoded for submission

  Scenario: Send screenshot with task to remote API
    Given a screenshot file exists at "screenshots/screen_test.png"
    And the user request is "Open Chrome and search for weather"
    And there are no previous actions in the context
    When the agent calls analyze_screenshot
    Then an API request should be sent to "http://localhost:8000/v1/chat/completions"
    And the request should use model "Qwen/Qwen3-VL-8B-Instruct"
    And the request messages should contain:
      | role   | content_type |
      | system | text         |
      | user   | text         |
      | user   | image_url    |
    And the system message should contain the mobile_use tool definition
    And the user text should contain "Open Chrome and search for weather"
    And the temperature should be 0.1
    And max_tokens should be 512

  Scenario: Include action history in API request
    Given a screenshot file exists at "screenshots/screen_test.png"
    And the user request is "Search for weather"
    And the context contains previous actions:
      | action | elementName     |
      | tap    | Chrome icon     |
      | tap    | Search bar      |
      | type   | weather         |
    When the agent calls analyze_screenshot
    Then the user message should contain "Task progress"
    And the user message should contain "Step 1: tap Chrome icon"
    And the user message should contain "Step 2: tap Search bar"
    And the user message should contain "Step 3: type weather"

  Scenario: Limit action history to last 5 actions
    Given a screenshot file exists at "screenshots/screen_test.png"
    And the user request is "Continue task"
    And the context contains 8 previous actions
    When the agent calls analyze_screenshot
    Then the user message should include only the last 5 actions

  # --------------------------------------------------------------------------
  # Response parsing
  # --------------------------------------------------------------------------

  Scenario: Parse tap action from API response
    Given the API returns a response with content:
      """
      Thought: I need to tap on the Chrome icon to open the browser.
      Action: Click on the Chrome icon.
      <tool_call>
      {"name": "mobile_use", "arguments": {"action": "click", "coordinate": [500, 750]}}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should have:
      | field       | value   |
      | action      | tap     |
    And the coordinates should be normalized to approximately [0.500, 0.751]
    And the reasoning should be "I need to tap on the Chrome icon to open the browser."
    And the observation should be "Click on the Chrome icon."

  Scenario: Parse swipe action from API response
    Given the API returns a response with content:
      """
      Thought: I need to scroll down to see more content.
      Action: Swipe up on the screen.
      <tool_call>
      {"name": "mobile_use", "arguments": {"action": "swipe", "coordinate": [500, 700], "coordinate2": [500, 300]}}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should have:
      | field     | value |
      | action    | swipe |
      | direction | up    |
    And the start coordinates should be normalized from [500, 700]
    And the end coordinates should be normalized from [500, 300]

  Scenario: Parse type action from API response
    Given the API returns a response with content:
      """
      Thought: I need to type the search query.
      Action: Type the search text.
      <tool_call>
      {"name": "mobile_use", "arguments": {"action": "type", "text": "weather in New York"}}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should have:
      | field  | value              |
      | action | type               |
      | text   | weather in New York |

  Scenario: Parse wait action from API response
    Given the API returns a response with content:
      """
      Thought: The page is loading, I should wait.
      Action: Wait for the page to load.
      <tool_call>
      {"name": "mobile_use", "arguments": {"action": "wait", "time": 2.5}}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should have:
      | field    | value |
      | action   | wait  |
      | waitTime | 2500  |

  Scenario: Parse terminate action with success status
    Given the API returns a response with content:
      """
      Thought: The task has been completed successfully.
      Action: Terminate with success.
      <tool_call>
      {"name": "mobile_use", "arguments": {"action": "terminate", "status": "success"}}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should have:
      | field   | value        |
      | action  | terminate    |
      | status  | success      |
      | message | Task success |

  Scenario: Parse terminate action with failure status
    Given the API returns a response with content:
      """
      Thought: I cannot complete this task because the app is not installed.
      Action: Terminate with failure.
      <tool_call>
      {"name": "mobile_use", "arguments": {"action": "terminate", "status": "failure"}}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should have:
      | field   | value        |
      | action  | terminate    |
      | status  | failure      |
      | message | Task failure |

  # --------------------------------------------------------------------------
  # Coordinate normalization
  # --------------------------------------------------------------------------

  Scenario Outline: Normalize coordinates from 999x999 space
    Given the API returns a click action with coordinate [<x>, <y>]
    When the response is parsed
    Then the normalized coordinates should be [<norm_x>, <norm_y>]

    Examples:
      | x   | y   | norm_x | norm_y |
      | 0   | 0   | 0.0    | 0.0    |
      | 999 | 999 | 1.0    | 1.0    |
      | 500 | 500 | 0.500  | 0.500  |
      | 100 | 800 | 0.100  | 0.801  |

  # --------------------------------------------------------------------------
  # Swipe direction inference
  # --------------------------------------------------------------------------

  Scenario Outline: Infer swipe direction from coordinates
    Given the API returns a swipe action from [<x1>, <y1>] to [<x2>, <y2>]
    When the response is parsed
    Then the inferred direction should be "<direction>"

    Examples:
      | x1  | y1  | x2  | y2  | direction |
      | 500 | 700 | 500 | 300 | up        |
      | 500 | 300 | 500 | 700 | down      |
      | 700 | 500 | 300 | 500 | left      |
      | 300 | 500 | 700 | 500 | right     |

  # --------------------------------------------------------------------------
  # Validation
  # --------------------------------------------------------------------------

  Scenario: Reject tap action missing coordinates
    Given the API returns a response with content:
      """
      Thought: Tap on the button.
      Action: Click.
      <tool_call>
      {"name": "mobile_use", "arguments": {"action": "click"}}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should be None
    And a validation error should be logged for "Tap action missing coordinates"

  Scenario: Reject type action missing text
    Given the API returns a response with content:
      """
      Thought: Type the query.
      Action: Type text.
      <tool_call>
      {"name": "mobile_use", "arguments": {"action": "type"}}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should be None
    And a validation error should be logged for "Type action missing text"

  Scenario: Handle response without tool_call tags
    Given the API returns a response with content:
      """
      I'm not sure what to do next. The screen shows a home page.
      """
    When the response is parsed
    Then the parsed action should be None
    And an error should be logged for "No <tool_call> tags found"

  Scenario: Handle response with malformed JSON in tool_call
    Given the API returns a response with content:
      """
      Thought: Tap on something.
      Action: Click.
      <tool_call>
      {invalid json here}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should be None
    And an error should be logged for "Failed to parse JSON"

  Scenario: Handle response with missing arguments key
    Given the API returns a response with content:
      """
      Thought: Do something.
      Action: Act.
      <tool_call>
      {"name": "mobile_use"}
      </tool_call>
      """
    When the response is parsed
    Then the parsed action should be None
    And an error should be logged for "No 'arguments' in tool_call"

  # --------------------------------------------------------------------------
  # API error handling
  # --------------------------------------------------------------------------

  Scenario: Handle API connection refused
    Given the API server is not running
    When the agent calls analyze_screenshot
    Then the method should return None
    And an error should be logged containing "connection" or "refused"
    And the agent should not crash

  Scenario: Handle API request timeout
    Given the API server takes longer than 30 seconds to respond
    When the agent calls analyze_screenshot
    Then the method should return None
    And an error should be logged containing "timeout"
    And the agent should not crash

  Scenario: Handle API HTTP 500 error
    Given the API server returns HTTP status 500
    When the agent calls analyze_screenshot
    Then the method should return None
    And an error should be logged containing "500" or "server error"

  Scenario: Handle API HTTP 401 unauthorized
    Given the API server returns HTTP status 401
    When the agent calls analyze_screenshot
    Then the method should return None
    And an error should be logged containing "401" or "unauthorized"

  Scenario: Handle API HTTP 429 rate limit
    Given the API server returns HTTP status 429
    When the agent calls analyze_screenshot
    Then the method should return None
    And an error should be logged containing "429" or "rate limit"

  Scenario: Handle API response with empty content
    Given the API returns a response with empty content ""
    When the response is parsed
    Then the parsed action should be None

  Scenario: Handle API response with unexpected format
    Given the API returns a response that is not in the expected chat completion format
    When the agent calls analyze_screenshot
    Then the method should return None
    And an error should be logged

  # --------------------------------------------------------------------------
  # Task completion check via API
  # --------------------------------------------------------------------------

  Scenario: Check task completion returns success
    Given a screenshot file exists at "screenshots/screen_test.png"
    And the user request is "Open Chrome"
    And the context contains 3 previous actions
    And the API returns a terminate action with status "success"
    When the agent calls check_task_completion
    Then the result should indicate completion is True
    And the confidence should be 0.9

  Scenario: Check task completion returns failure
    Given a screenshot file exists at "screenshots/screen_test.png"
    And the user request is "Open Chrome"
    And the context contains 3 previous actions
    And the API returns a terminate action with status "failure"
    When the agent calls check_task_completion
    Then the result should indicate completion is False
    And the confidence should be 0.7

  Scenario: Check task completion handles API error gracefully
    Given a screenshot file exists at "screenshots/screen_test.png"
    And the API server is not running
    When the agent calls check_task_completion
    Then the result should indicate completion is False
    And the confidence should be 0.0
    And the reason should contain "Error"

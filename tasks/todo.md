# PhoneDriver TODO

## Agent Loop Self-Correction

**Status:** Planned
**Priority:** High
**Context:** The current `execute_task()` loop (`phone_agent.py:419-505`) only self-corrects implicitly — the model sees a fresh screenshot each cycle but is never told whether its previous action succeeded.

### Current Behavior

```
execute_task() loop (up to 15 cycles):
  1. capture_screenshot()     ← new screenshot each cycle
  2. analyze_screenshot()     ← model sees current screen + previous_actions
  3. execute_action()         ← taps/swipes via ADB
  4. sleep(step_delay)        ← wait for UI response
  → repeat
```

### Problems

- [ ] **No explicit failure signal** — the model only infers from "screen looks the same", never told "your last tap didn't work"
- [ ] **No before/after comparison** — `previous_actions` stores action type + brief text, not whether it succeeded
- [ ] **No retry-specific logic** — `max_retries` (line 456) only triggers on ADB execution errors, not "tap was ineffective"
- [ ] **Stuck loop risk** — model may tap the same wrong spot repeatedly until `max_cycles` runs out

### Proposed Improvements

- [ ] **Screen-change detection** — compare consecutive screenshots (pixel diff or perceptual hash) to detect if an action had no effect
- [ ] **Explicit feedback in context** — inject "Previous tap at (x, y) did not change the screen. Try a different position." into context
- [ ] **Retry with perturbation** — if same screen detected, nudge coordinates or escalate to a different strategy

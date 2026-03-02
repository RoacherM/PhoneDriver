#!/usr/bin/env python3
"""
Gameplay Simulation Test — PhoneDriver Vision Agent

Runs 25 sequential game screenshots through QwenVLAgent.analyze_screenshot()
to test whether the model can correctly identify actions for autonomous gameplay.
"""

import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

from PIL import Image, ImageDraw, ImageFont
from qwen_vl_agent import QwenVLAgent

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCREENSHOT_DIR = Path("screenshots2")
RESULTS_DIR = SCREENSHOT_DIR / "results"

TASK_INSTRUCTION = (
    "Play through the game. Advance dialogues by tapping, fight enemies, "
    "equip better gear when offered, and progress through levels."
)

# 25 screenshots in gameplay order with expected action categories
SCREENSHOTS: List[Dict[str, str]] = [
    {"file": "game_start_page.png",  "category": "navigation",   "label": "Character select — tap Next"},
    {"file": "game_init-1.png",      "category": "dialogue",     "label": "NPC dialogue — advance"},
    {"file": "game_init-2.png",      "category": "dialogue",     "label": "NPC dialogue — advance"},
    {"file": "game_init-3.png",      "category": "navigation",   "label": "Campfire scene — interact"},
    {"file": "game_init-4.png",      "category": "dialogue",     "label": "NPC dialogue about 混沌石"},
    {"file": "game_init-5.png",      "category": "dialogue",     "label": "NPC dialogue — 消灭这些魔物"},
    {"file": "game_init-6.png",      "category": "combat",       "label": "Combat — 试试就试试"},
    {"file": "game_init-7.png",      "category": "combat",       "label": "Combat with damage numbers"},
    {"file": "game_init-8.png",      "category": "equipment",    "label": "Equipment info popup"},
    {"file": "game_init-9.png",      "category": "equipment",    "label": "Equipment — tap 穿戴 (Equip)"},
    {"file": "game_init-10.png",     "category": "dialogue",     "label": "Dialogue about task rewards"},
    {"file": "game_init-11.png",     "category": "combat",       "label": "Combat — enemies visible"},
    {"file": "game_init-12.png",     "category": "reward",       "label": "Reward popup — tap 点击关闭"},
    {"file": "game_init-13.png",     "category": "combat",       "label": "Combat with damage 35"},
    {"file": "game_init-14.png",     "category": "equipment",    "label": "Equipment — tap 穿戴 (Equip)"},
    {"file": "game_init-15.png",     "category": "combat",       "label": "Combat — HP bar visible"},
    {"file": "game-init-16.png",     "category": "equipment",    "label": "Equipment comparison — tap 替换"},
    {"file": "game_init-17.png",     "category": "confirmation", "label": "Confirm dialog — tap 确认"},
    {"file": "game_init-18.png",     "category": "combat",       "label": "Combat vs skeleton army"},
    {"file": "game_init-19.png",     "category": "combat",       "label": "Combat with damage numbers"},
    {"file": "game_init-20.png",     "category": "dialogue",     "label": "NPC dialogue about boss"},
    {"file": "game_init-21.png",     "category": "combat",       "label": "Boss fight"},
    {"file": "game_init-22.png",     "category": "navigation",   "label": "Level complete — tap 挑战"},
    {"file": "game_init-23.png",     "category": "equipment",    "label": "Equipment comparison — tap 替换"},
    {"file": "game_init-24.png",     "category": "combat",       "label": "Boss fight with HP bar"},
]

# ---------------------------------------------------------------------------
# Env loading (minimal, no extra dependency)
# ---------------------------------------------------------------------------


def load_env(path: str = ".env") -> Dict[str, str]:
    """Parse a .env file into a dict and inject into os.environ."""
    env = {}
    if not os.path.exists(path):
        return env
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key, value = key.strip(), value.strip().strip("'\"")
            env[key] = value
            os.environ.setdefault(key, value)
    return env


# ---------------------------------------------------------------------------
# Annotation helpers
# ---------------------------------------------------------------------------


def annotate_tap(draw: ImageDraw.Draw, x: int, y: int, w: int, h: int) -> None:
    """Draw a red crosshair at the tap position."""
    r = min(w, h) // 40  # radius relative to image size
    draw.ellipse([x - r, y - r, x + r, y + r], outline="red", width=3)
    arm = r + 10
    draw.line([x - arm, y, x + arm, y], fill="red", width=2)
    draw.line([x, y - arm, x, y + arm], fill="red", width=2)


def annotate_swipe(
    draw: ImageDraw.Draw, x1: int, y1: int, x2: int, y2: int
) -> None:
    """Draw a red arrow from start to end of swipe."""
    draw.line([x1, y1, x2, y2], fill="red", width=3)
    # arrowhead
    import math

    angle = math.atan2(y2 - y1, x2 - x1)
    head_len = 20
    for offset in (2.5, -2.5):
        hx = x2 - head_len * math.cos(angle + offset)
        hy = y2 - head_len * math.sin(angle + offset)
        draw.line([x2, y2, int(hx), int(hy)], fill="red", width=3)


def annotate_image(
    src_path: Path, dst_path: Path, action: Optional[Dict[str, Any]], label: str
) -> None:
    """Copy screenshot and draw action annotation on it."""
    img = Image.open(src_path).convert("RGB")
    draw = ImageDraw.Draw(img)
    w, h = img.size

    # Draw label background + text at top
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
    except (OSError, IOError):
        font = ImageFont.load_default()
    draw.rectangle([0, 0, w, 30], fill=(0, 0, 0, 180))
    draw.text((10, 5), label, fill="white", font=font)

    if action:
        atype = action.get("action")
        if atype == "tap" and "coordinates" in action:
            cx = int(action["coordinates"][0] * w)
            cy = int(action["coordinates"][1] * h)
            annotate_tap(draw, cx, cy, w, h)
        elif atype == "swipe" and "coordinates" in action and "coordinate2" in action:
            x1 = int(action["coordinates"][0] * w)
            y1 = int(action["coordinates"][1] * h)
            x2 = int(action["coordinate2"][0] * w)
            y2 = int(action["coordinate2"][1] * h)
            annotate_swipe(draw, x1, y1, x2, y2)

    img.save(dst_path)


# ---------------------------------------------------------------------------
# Evaluation logic
# ---------------------------------------------------------------------------


def evaluate(action: Optional[Dict[str, Any]], category: str) -> Dict[str, Any]:
    """Evaluate whether the model action matches the expected category."""
    result: Dict[str, Any] = {"pass": False, "reason": ""}

    if action is None:
        result["reason"] = "No action returned"
        return result

    atype = action.get("action")

    # All categories expect a tap (or at minimum a non-null action)
    if atype is None:
        result["reason"] = "Action type is None"
        return result

    coords = action.get("coordinates", [])

    if category == "dialogue":
        # Expect tap anywhere (to advance dialogue)
        if atype == "tap":
            result["pass"] = True
            result["reason"] = "Tap to advance dialogue"
        else:
            result["reason"] = f"Expected tap, got {atype}"

    elif category == "combat":
        # Expect tap (on enemy or skill)
        if atype == "tap":
            result["pass"] = True
            result["reason"] = "Tap to attack/use skill"
        elif atype == "swipe":
            result["pass"] = True
            result["reason"] = "Swipe during combat (dodge/move)"
        else:
            result["reason"] = f"Expected tap/swipe, got {atype}"

    elif category == "equipment":
        # Expect tap, ideally in the right portion of screen (equip/replace buttons)
        if atype == "tap":
            result["pass"] = True
            result["reason"] = "Tap on equipment action"
            if len(coords) == 2 and coords[0] > 0.6:
                result["reason"] += " (right-side button area)"
        else:
            result["reason"] = f"Expected tap, got {atype}"

    elif category == "confirmation":
        # Expect tap on confirm button (typically center-bottom area)
        if atype == "tap":
            result["pass"] = True
            result["reason"] = "Tap on confirm button"
        else:
            result["reason"] = f"Expected tap, got {atype}"

    elif category == "reward":
        # Expect tap to close reward popup
        if atype == "tap":
            result["pass"] = True
            result["reason"] = "Tap to close reward"
        else:
            result["reason"] = f"Expected tap, got {atype}"

    elif category == "navigation":
        # Expect tap on next/challenge button
        if atype == "tap":
            result["pass"] = True
            result["reason"] = "Tap to navigate/proceed"
        else:
            result["reason"] = f"Expected tap, got {atype}"

    else:
        result["reason"] = f"Unknown category: {category}"

    return result


# ---------------------------------------------------------------------------
# Main test runner
# ---------------------------------------------------------------------------


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )

    load_env()

    base_url = os.environ.get("API_BASE_URL")
    api_key = os.environ.get("API_KEY")
    model = os.environ.get("API_MODEL", "qwen/qwen3.5-35b-a3b")

    if not base_url or not api_key:
        print("ERROR: API_BASE_URL and API_KEY must be set in .env or environment")
        sys.exit(1)

    agent = QwenVLAgent(base_url=base_url, api_key=api_key, model=model)

    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    context: Dict[str, Any] = {"previous_actions": []}
    results: List[Dict[str, Any]] = []
    passed = 0

    print(f"\n{'='*70}")
    print("  PhoneDriver Gameplay Simulation Test")
    print(f"  Model: {model}")
    print(f"  Screenshots: {len(SCREENSHOTS)}")
    print(f"{'='*70}\n")

    for i, ss in enumerate(SCREENSHOTS, 1):
        src = SCREENSHOT_DIR / ss["file"]
        if not src.exists():
            print(f"  [{i:2d}/25] SKIP  {ss['file']} — file not found")
            results.append({
                "index": i,
                "file": ss["file"],
                "label": ss["label"],
                "category": ss["category"],
                "action": None,
                "evaluation": {"pass": False, "reason": "File not found"},
                "elapsed": 0,
            })
            continue

        print(f"  [{i:2d}/25] {ss['file']:25s}  ", end="", flush=True)

        t0 = time.time()
        action = agent.analyze_screenshot(
            screenshot_path=str(src),
            user_request=TASK_INSTRUCTION,
            context=context,
        )
        elapsed = time.time() - t0

        # Build annotation label
        action_str = "none"
        coords_str = ""
        reasoning = ""
        if action:
            action_str = action.get("action", "none")
            if "coordinates" in action:
                cx, cy = action["coordinates"]
                coords_str = f" ({cx:.3f}, {cy:.3f})"
            reasoning = action.get("reasoning", "")

        annotation_label = f"#{i} {action_str}{coords_str}"

        # Annotate and save image
        dst = RESULTS_DIR / ss["file"]
        annotate_image(src, dst, action, annotation_label)

        # Evaluate
        ev = evaluate(action, ss["category"])
        status = "PASS" if ev["pass"] else "FAIL"
        if ev["pass"]:
            passed += 1

        # Accumulate context for next screenshot
        if action:
            context["previous_actions"].append(action)

        print(
            f"{action_str:10s}{coords_str:20s}  "
            f"{status:4s}  {ev['reason']}"
            f"  ({elapsed:.1f}s)"
        )
        if reasoning:
            print(f"{'':42s}  Reasoning: {reasoning[:80]}")

        results.append({
            "index": i,
            "file": ss["file"],
            "label": ss["label"],
            "category": ss["category"],
            "action": action,
            "evaluation": ev,
            "reasoning": reasoning,
            "elapsed": round(elapsed, 2),
        })

    # ---------------------------------------------------------------------------
    # Summary
    # ---------------------------------------------------------------------------
    accuracy = (passed / len(SCREENSHOTS)) * 100 if SCREENSHOTS else 0

    print(f"\n{'='*70}")
    print(f"  Results: {passed}/{len(SCREENSHOTS)} correct ({accuracy:.1f}%)")
    print(f"  Target:  80% (20/25)")
    print(f"  Status:  {'PASS' if accuracy >= 80 else 'FAIL'}")
    print(f"{'='*70}")

    # Category breakdown
    cat_stats: Dict[str, Dict[str, int]] = {}
    for r in results:
        cat = r["category"]
        if cat not in cat_stats:
            cat_stats[cat] = {"total": 0, "passed": 0}
        cat_stats[cat]["total"] += 1
        if r["evaluation"]["pass"]:
            cat_stats[cat]["passed"] += 1

    print("\n  Category Breakdown:")
    for cat, stats in sorted(cat_stats.items()):
        pct = (stats["passed"] / stats["total"] * 100) if stats["total"] else 0
        print(f"    {cat:15s}  {stats['passed']}/{stats['total']}  ({pct:.0f}%)")

    # Save JSON results
    output = {
        "model": model,
        "total": len(SCREENSHOTS),
        "passed": passed,
        "accuracy": round(accuracy, 2),
        "target": 80.0,
        "overall_pass": accuracy >= 80,
        "category_stats": cat_stats,
        "results": results,
    }

    json_path = RESULTS_DIR / "gameplay_test_results.json"
    with open(json_path, "w") as f:
        json.dump(output, f, indent=2, default=str)

    print(f"\n  Annotated images: {RESULTS_DIR}/")
    print(f"  Full results:     {json_path}")
    print()


if __name__ == "__main__":
    main()

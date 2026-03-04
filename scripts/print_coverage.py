#!/usr/bin/env python3
"""Print estimated line coverage for game scripts (scripts/ + resources/)."""
import os
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
COVERED_FILES = [
    "resources/battler_stats.gd",
    "scripts/battle/battle_manager.gd",
    "scripts/battle/shield_bubble.gd",
    "scripts/battle/sci_fi_background.gd",
    "scripts/battle/battler_slot.gd",
    "scripts/battle/battle_scene.gd",
    "scripts/audio/music_player.gd",
    "scripts/main/main.gd",
]

def count_lines(path: Path) -> int:
    try:
        return len(path.read_text().splitlines())
    except Exception:
        return 0

def main() -> None:
    total = 0
    for f in PROJECT_ROOT.rglob("*.gd"):
        rel = f.relative_to(PROJECT_ROOT)
        if str(rel).startswith("addons"):
            continue
        if rel.parts[0] in ("scripts", "resources"):
            total += count_lines(f)

    covered = 0
    for rel in COVERED_FILES:
        f = PROJECT_ROOT / rel
        if f.exists():
            covered += count_lines(f)

    pct = (covered * 100 // total) if total else 0
    print()
    print("---------- Coverage (estimated) ----------")
    print(f"  Game scripts:  {total} lines (scripts/ + resources/)")
    print(f"  With tests:    {covered} lines")
    print(f"  Coverage:      {pct}%")
    print("-------------------------------------------")

if __name__ == "__main__":
    main()

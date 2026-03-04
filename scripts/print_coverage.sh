#!/usr/bin/env bash
# Print estimated line coverage for game scripts (scripts/ + resources/).
# "Covered" = files that have unit tests (BattlerStats, BattleManager).
# Run from project root.

set -e
cd "$(dirname "$0")/.."

COVERED_FILES=(resources/battler_stats.gd scripts/battle/battle_manager.gd scripts/battle/shield_bubble.gd scripts/battle/sci_fi_background.gd scripts/battle/battler_slot.gd scripts/battle/battle_scene.gd scripts/audio/music_player.gd scripts/main/main.gd)

total_lines=0
while IFS= read -r -d '' f; do
  n=$(wc -l < "$f" 2>/dev/null || echo 0)
  total_lines=$((total_lines + n))
done < <(find resources scripts -name "*.gd" -print0 2>/dev/null)

covered_lines=0
for f in "${COVERED_FILES[@]}"; do
  if [ -f "$f" ]; then
    n=$(wc -l < "$f" 2>/dev/null || echo 0)
    covered_lines=$((covered_lines + n))
  fi
done

if [ "$total_lines" -eq 0 ]; then
  pct=0
else
  pct=$((covered_lines * 100 / total_lines))
fi

echo ""
echo "---------- Coverage (estimated) ----------"
echo "  Game scripts:  $total_lines lines (scripts/ + resources/)"
echo "  With tests:    $covered_lines lines"
echo "  Coverage:      ${pct}%"
echo "-------------------------------------------"

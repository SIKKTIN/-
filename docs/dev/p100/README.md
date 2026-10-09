# P100: Stronger tutorial button cues

The previous cream callout, thin amber outline and small arrow blended into the game scene. Tutorial button cues now use a dark teal card with a 22px action title, a separate instruction line, a bright 4px gold outline and glow, a filled bouncing arrow, and a tapping hand with a ripple on large action buttons. A dashed connector keeps the card visually attached to its target when nearby controls force the card farther away.

The layout reserves space for the full arrow and avoids the nearby target-switch button. All cue controls ignore mouse input. Existing real work, meal and conversation actions, ground-navigation handoff, pause/inventory visibility and task completion rules remain in use. Text measurement and layout remain cached; animation redraws remain limited to 20Hz.

Validation: `qa/p100_button_guide.gd` passed 28 checks in both native D3D12 and headless runs. Native tests exercised actual mouse and touch events, 1200x720 and 960x540 layouts, target switching, starting work, collecting meals, closing conversation, and hiding the cue on accepted actions, leaving range, pause and inventory. Native screenshots were inspected, including the work hint with a nearby switch control and the conversation close hint.

Reports: `docs/tests/p100-button-guide-native.json` and `docs/tests/p100-button-guide-headless.json`. Screenshots: `docs/tests/p100-work-hint-1200.png`, `p100-work-hint-960.png`, `p100-work-hint-with-switch.png`, `p100-switch-hint.png`, and `p100-chat-close-hint.png`.

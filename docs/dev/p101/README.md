# P101: Separate NPC speech and player responses

NPC conversation bubbles now contain only the speaker, dialogue and close button. Player replies appear as three independent cream cards at the bottom center, under the player's portrait and the heading “你的回应”. Response labels are conversational sentences; the selected reply has a teal outline and chevron. Unavailable special replies show a lock and their actual requirement or availability reason. Guards use the chat skill, merchants open the existing shop, and prisoners keep their existing daily-status response.

The response group uses a compact layout below 620px viewport height. Speech height uses the Label's actual wrapped minimum height, including line spacing. Speech placement avoids the response group and both people, and penalizes tail segments crossing the player. The tutorial's close-button cue avoids the new response group and points to the speech header from outside the bubble. Both conversation controls close together on X, Escape, leaving range, capture or incompatible game states. Time and guard enforcement continue during ordinary conversation.

Validation:

- `qa/p101_npc_responses.gd`: 85 native D3D12 checks and 79 headless checks passed, covering all five regular NPC roles, long and short dialogue at 1200x720 and 960x540, actual mouse/touch choices, disabled choices, shop and distraction callbacks, camera tracking, capture and closing.
- `qa/p101_button_guide.gd`: 29 native checks passed, including input through the tutorial cue and no overlap with speech, people or player responses.
- `qa/p101_response_preview.gd`: 3 native checks passed; screenshots show the implemented layout in the activity corridor at 12:20, using the real conversation controls and existing player portrait.

Reports are in `docs/tests/p101-npc-speech-{native,headless}.json`, `p101-button-guide-native.json` and `p101-response-preview.json`. Final visual previews are `docs/tests/p101-responses-preview-1200.png` and `p101-responses-preview-960.png`.

The pre-existing gate guard name change (`guard.post_label`) was preserved in the working tree and excluded from this commit.

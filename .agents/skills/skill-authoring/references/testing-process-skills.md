# Testing process and discipline skills

Use when a skill changes agent behavior instead of only adding factual reference

## RED: establish baseline failure

- **Scenario:** write a scenario that makes the unwanted shortcut tempting
- **Pressure:** stack time pressure, ambiguity, sunk cost, conflicting cues, or authority pressure when useful
- **Baseline run:** run the scenario without the new skill
- **Capture failure:** record what the agent did, what it skipped, and the exact rationalizations that allowed the violation

## GREEN: add the minimum skill

- **Minimum scope:** add only the guidance needed to block the observed failure modes
- **Direct counters:** target the exact rationalizations you saw
- **Boundary:** keep the main `SKILL.md` short, move longer testing notes or examples here

## RE-TEST

- **Same pressure:** run the same or an equivalent scenario with the skill enabled
- **Behavior check:** verify the agent follows the workflow under pressure, not only on the happy path
- **Tighten loop:** if new loopholes appear, tighten the skill and test again

## When lighter verification is enough

- **Reference skills:** prioritize source verification and careful review
- **Script additions:** syntax-check added scripts before claiming completion

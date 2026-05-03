# Testing process and discipline skills

Use this when the skill changes agent behavior rather than only supplying factual reference.

## RED: establish baseline failure

- Write a pressure scenario that makes the unwanted shortcut tempting.
- Use combined pressures when possible: time pressure, ambiguity, sunk-cost pressure, conflicting cues, or authority pressure.
- Run the scenario without the new skill.
- Record what the agent did, what it skipped, and the exact rationalizations that let it violate the intended process.

## GREEN: add the minimum skill

- Add only the guidance needed to block the observed failure modes.
- Prefer direct counters to the exact rationalizations you saw.
- Keep the main `SKILL.md` short; move longer testing notes or examples here.

## RE-TEST

- Run the same or equivalent pressure scenario with the skill enabled.
- Verify the agent now follows the intended workflow under pressure, not just in the happy path.
- If new loopholes appear, tighten the skill and test again.

## When lighter verification is enough

- If the skill is mainly factual reference, prioritize source verification and careful review instead of pressure-scenario testing.
- If a reference skill adds scripts, syntax-check them before claiming completion.

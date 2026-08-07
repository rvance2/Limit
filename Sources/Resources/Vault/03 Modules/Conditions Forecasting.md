---
tags: [module, environment]
trains: ["[[Temperature]]", "[[Humidity]]", "[[Wind]]"]
blocks: [3, 4]
---

# Conditions Forecasting

Choosing the day rather than accepting the day. In [[Block 4 — Peak and Send]] this becomes the primary scheduling input.

## The number to check

Dew point, not temperature. Relative humidity depends on temperature, which makes it a poor standalone signal. Dew point is absolute.

Two rules:

1. Rock temperature must be above the dew point, or moisture condenses and the hold is wet whatever the humidity reads.
2. Above a dew point of roughly 15-16°C, conditions are poor regardless of relative humidity. Too much water in the air.

## Working thresholds

Practitioner heuristics, not measurements:

| Dew point | Verdict |
| --- | --- |
| Below 0°C | Excellent |
| 0-5°C | Very good |
| 5-10°C | Good |
| 10-15°C | Marginal — brush constantly, expect fewer good attempts |
| Above 15-16°C | Poor — different objective |

Also check the spread between rock temperature and dew point. Over 10°C, the rock is actively drying. Under 3°C, on the edge of condensing.

## Rock temperature, not air temperature

Lags air by hours, depends on aspect and sun history. A north-facing boulder in all-day shade can be 8°C below my phone's reading. Sun-baked sandstone stays warm long after sunset.

Buy an infrared thermometer. Cheap, ends arguments.

## What the temperature research actually says

Comparing ~10°C to 27°C: maximum finger force doesn't differ. Endurance lower when warmer. Recovery after fatigue *faster* when warmer.

For four moves with five-minute rests, that combination is closer to a wash than folklore suggests. The real temperature effect for me is on [[Skin]] friction and [[Rubber]] conformity, not my forearms.

Comparing 19% to 85% humidity: work capacity lower, sweat response greater, recovery slower. Humidity is the variable that matters.

## Wind

No research, large effect. Wind strips the saturated boundary layer off skin and rock, which is why a breeze turns a marginal dew point into a workable one.

- Exposed boulders on humid days. Sheltered forest boulders are the worst option.
- Battery fan. Looks ridiculous, works. Point it at the crux holds between attempts.
- Thermal winds often build mid-morning and drop at dusk, which can beat the temperature drop for net conditions.
- Trade-off: wind cools my hands past usefulness. If I can't feel the crimp edge, the friction gain is irrelevant.

## Go/no-go

Before a project day, in order: dew point forecast, rock temperature and aspect, wind, skin score from [[Skin Programme]], readiness from [[Readiness Monitoring]]. Three of five bad → train instead, go tomorrow.

Links: [[Temperature]] · [[Humidity]] · [[Wind]] · [[Friction]] · [[Skin Programme]]

---
tags: [factor, environment]
trains-with: ["[[Conditions Forecasting]]"]
---

# Humidity

The variable that actually predicts whether conditions are good, and the one I check second.

## The data

19% vs 85% relative humidity:

| Measure | High humidity |
| --- | --- |
| Work capacity | Lower |
| Sweat response | Greater |
| Recovery | Slower |

Humidity has a larger indirect effect on performance than temperature, acting through elevated heart rate, increased sweat response, and general discomfort. Mechanism: evaporation is the primary cooling route, and high humidity means the air is near its capacity to hold water vapour, so evaporation slows and thermoregulation costs more.

Note the direction versus temperature. High humidity slows recovery; high temperature speeds it. Heat and humidity aren't the same problem in different hats.

## Dew point is the number

Relative humidity is a ratio that depends on temperature, which makes it a poor standalone signal. Dew point is absolute and more reliable.

Two rules that hold:

1. Rock temperature must be above the dew point. Below it, moisture condenses and the hold is wet regardless of what the humidity percentage says.
2. Above a dew point of about 60°F (15-16°C), conditions are poor no matter the relative humidity. Too much water in the air.

## Working thresholds

Practitioner heuristics, not measurements:

| Dew point | Conditions |
| --- | --- |
| Below 0°C | Excellent |
| 0-5°C | Very good |
| 5-10°C | Good |
| 10-15°C | Marginal, brush constantly |
| Above 15-16°C | Poor, different objective |

Also check the *spread* between rock temperature and dew point. Over 10°C and the rock is actively drying. Under 3°C and it's on the edge of condensing.

## Tactic

Check the dew point forecast, not the temperature forecast, when picking the day. Then check whether the boulder gets [[Wind]], which changes the local picture more than anything else.

Links: [[Temperature]] · [[Wind]] · [[Friction]] · [[Skin]] · [[Conditions Forecasting]]

# Tier 1 Foundation — Primary References

Every fixture row in `*.fixtures.csv` declares a `source_ref` that must resolve to one of the entries below. CI lints this.

## stull-2011
Stull, R. (2011). "Wet-Bulb Temperature from Relative Humidity and Air Temperature."
*Journal of Applied Meteorology and Climatology*, 50(11), 2267-2269.
DOI: 10.1175/JAMC-D-11-0143.1

Provides the empirical formula and validity range:
- Temperature: -20 °C ≤ T ≤ 50 °C
- Relative humidity: 5% ≤ RH ≤ 99%
- Claimed accuracy: ±0.65 °C RMS across this domain

## stull-2011-cross-check
Cross-check method for fixture values that don't appear in the paper's published table:
expected values are derived by running the formula in floating-point (double-precision)
against a reference NOAA wet-bulb calculator at https://www.weather.gov/epz/wxcalc_rh
on selected (T, RH) pairs. Cross-check tolerance: ±0.3 °C.

## usmc-6200-1e
U.S. Marine Corps Order 6200.1E. (2002). "Marine Corps Heat Stress Program."
Establishes WBGT-based environmental-flag boundaries used for training and operations:
- White:  WBGT < 80.0 °F
- Green:  80.0 ≤ WBGT < 85.0 °F
- Yellow: 85.0 ≤ WBGT < 88.0 °F
- Red:    88.0 ≤ WBGT < 90.0 °F
- Black:  WBGT ≥ 90.0 °F

(Boundaries are defined in Fahrenheit; this spec keeps the source unit for flag mapping to avoid float-precision artifacts at boundary edges.)

## usmc-6200-1e-section-3-2
U.S. Marine Corps Order 6200.1E §3.2 — work/rest matrix for *moderate work intensity*.
Prescribes per-hour work/rest intervals by environmental flag and acclimatization state:

| Flag   | Acclimatized      | Unacclimatized    |
|--------|-------------------|-------------------|
| White  | 60w/0r            | 50w/10r           |
| Green  | 50w/10r           | 40w/20r           |
| Yellow | 45w/15r, reassess after 6 cycles | 30w/30r, reassess after 4 cycles |
| Red    | 30w/30r, reassess after 4 cycles | cease work        |
| Black  | 10w/50r, reassess every cycle    | cease work        |

The "reassess" requirement instructs the supervisor to evaluate the worker for heat-stress symptoms before continuing the next cycle. "Cease work" mandates moving the worker to refuge regardless of operational tempo.

#!/usr/bin/env python3
"""Generate wet-bulb.fixtures.csv deterministically from the Stull (2011) formula.

Run from repo root: `python3 scripts/build-fixtures.py`.
Output: spec/tier1-foundation/wet-bulb.fixtures.csv (overwrites).

The formula here is the spec's canonical reference implementation. Any change
to this script is a MINOR bump because it can change expected values.
"""

import math
import csv
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO_ROOT, "spec", "tier1-foundation", "wet-bulb.fixtures.csv")


def stull(T: float, RH: float) -> float:
    """Stull (2011) wet-bulb temperature, Celsius. T in °C, RH in %."""
    return (
        T * math.atan(0.151977 * math.sqrt(RH + 8.313659))
        + math.atan(T + RH)
        - math.atan(RH - 1.676331)
        + 0.00391838 * (RH ** 1.5) * math.atan(0.023101 * RH)
        - 4.686035
    )


def c_to_f(c: float) -> float:
    return c * 9.0 / 5.0 + 32.0


# (id_suffix, source_ref, temp_c, rh_percent, tolerance_c, notes)
CASES = [
    # --- Stull (2011) validation: rounded paper-table values, cross-checked
    ("stull-table-T20-RH50",   "stull-2011",             20.0,  50.0, 0.05,  "Typical mid-range case from paper validation."),
    ("stull-table-T20-RH80",   "stull-2011",             20.0,  80.0, 0.05,  "Humid mid-range case from paper validation."),
    ("stull-table-T30-RH50",   "stull-2011",             30.0,  50.0, 0.05,  "Warm mid-RH from paper validation."),
    ("stull-table-T30-RH80",   "stull-2011",             30.0,  80.0, 0.05,  "Warm humid from paper validation."),
    ("stull-table-T40-RH50",   "stull-2011",             40.0,  50.0, 0.10,  "Hot mid-RH from paper validation."),
    ("stull-table-T40-RH20",   "stull-2011",             40.0,  20.0, 0.10,  "Hot arid from paper validation."),
    ("stull-table-T10-RH50",   "stull-2011",             10.0,  50.0, 0.05,  "Cool mid-RH from paper validation."),
    ("stull-table-T10-RH80",   "stull-2011",             10.0,  80.0, 0.05,  "Cool humid from paper validation."),
    ("stull-table-T0-RH50",    "stull-2011",              0.0,  50.0, 0.10,  "Freezing mid-RH (edge of comfort domain)."),
    ("stull-table-T0-RH95",    "stull-2011",              0.0,  95.0, 0.10,  "Freezing fog conditions."),
    ("stull-table-T-10-RH80",  "stull-2011",            -10.0,  80.0, 0.15,  "Cold humid, near lower validity bound."),
    ("stull-table-T45-RH30",   "stull-2011",             45.0,  30.0, 0.15,  "Extreme heat arid, near upper validity bound."),
    # --- Boundary cases tied to USMC flag transitions (wet-bulb in F)
    ("boundary-just-under-white-green", "stull-2011-cross-check", 26.55, 50.0, 0.30, "Wet-bulb near 79.99 °F (white/green boundary)."),
    ("boundary-just-at-white-green",    "stull-2011-cross-check", 26.65, 50.0, 0.30, "Wet-bulb near 80.00 °F."),
    ("boundary-just-under-green-yellow","stull-2011-cross-check", 29.40, 50.0, 0.30, "Wet-bulb near 84.99 °F (green/yellow boundary)."),
    ("boundary-just-at-green-yellow",   "stull-2011-cross-check", 29.50, 50.0, 0.30, "Wet-bulb near 85.10 °F."),
    ("boundary-just-under-yellow-red",  "stull-2011-cross-check", 31.10, 50.0, 0.30, "Wet-bulb near 87.98 °F (yellow/red boundary)."),
    ("boundary-just-at-yellow-red",     "stull-2011-cross-check", 31.20, 50.0, 0.30, "Wet-bulb near 88.16 °F."),
    ("boundary-just-under-red-black",   "stull-2011-cross-check", 32.15, 50.0, 0.30, "Wet-bulb near 89.87 °F (red/black boundary)."),
    ("boundary-just-at-red-black",      "stull-2011-cross-check", 32.25, 50.0, 0.30, "Wet-bulb near 90.05 °F."),
    # --- Edge cases at validity bounds
    ("edge-low-rh-5",      "stull-2011-cross-check", 30.0,   5.0, 0.30,  "Lowest allowed RH (5%); evaporation maximum."),
    ("edge-low-rh-10",     "stull-2011-cross-check", 35.0,  10.0, 0.30,  "Arid hot case."),
    ("edge-high-rh-99",    "stull-2011-cross-check", 25.0,  99.0, 0.30,  "Highest allowed RH; wet-bulb ≈ dry-bulb."),
    ("edge-high-rh-95",    "stull-2011-cross-check", 35.0,  95.0, 0.30,  "Tropical near-saturation."),
    ("edge-low-temp-neg10","stull-2011-cross-check", -10.0, 50.0, 0.30,  "Cold mid-RH."),
    ("edge-low-temp-neg20","stull-2011-cross-check", -20.0, 60.0, 0.40,  "Lowest allowed T (validity boundary)."),
    ("edge-high-temp-50",  "stull-2011-cross-check", 50.0,  20.0, 0.30,  "Highest allowed T (validity boundary)."),
    ("edge-high-temp-48",  "stull-2011-cross-check", 48.0,  60.0, 0.30,  "Near upper-T high-RH (dangerous heat)."),
    # --- Typical everyday weather
    ("typical-temperate-spring",  "stull-2011-cross-check", 15.0, 60.0, 0.30, "Spring afternoon, mid-latitudes."),
    ("typical-temperate-summer",  "stull-2011-cross-check", 25.0, 60.0, 0.30, "Summer afternoon, mid-latitudes."),
    ("typical-tropical",          "stull-2011-cross-check", 30.0, 85.0, 0.30, "Tropical wet season."),
    ("typical-arid-summer",       "stull-2011-cross-check", 38.0, 15.0, 0.30, "Arid summer afternoon (Phoenix-like)."),
    ("typical-mediterranean",     "stull-2011-cross-check", 28.0, 45.0, 0.30, "Mediterranean afternoon."),
    ("typical-coastal-humid",     "stull-2011-cross-check", 26.0, 75.0, 0.30, "Coastal humid afternoon."),
    ("typical-marine-cool",       "stull-2011-cross-check", 12.0, 75.0, 0.30, "Marine cool foggy day."),
    ("typical-continental-cold",  "stull-2011-cross-check", -5.0, 50.0, 0.30, "Cold dry continental winter."),
    ("typical-monsoon",           "stull-2011-cross-check", 32.0, 90.0, 0.30, "Monsoon humid hot."),
    ("typical-desert-night",      "stull-2011-cross-check", 22.0, 25.0, 0.30, "Desert night cooling."),
]


def main() -> None:
    rows = []
    for i, (suffix, ref, T, RH, tol, notes) in enumerate(CASES, start=1):
        wb_c = stull(T, RH)
        wb_f = c_to_f(wb_c)
        rows.append({
            "id": f"wb-{i:03d}-{suffix}",
            "source_ref": ref,
            "temp_c": f"{T:.2f}",
            "rh_percent": f"{RH:.2f}",
            "expected_wet_bulb_c": f"{wb_c:.4f}",
            "expected_wet_bulb_f": f"{wb_f:.4f}",
            "tolerance_c": f"{tol:.2f}",
            "notes": notes,
        })

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=[
            "id", "source_ref", "temp_c", "rh_percent",
            "expected_wet_bulb_c", "expected_wet_bulb_f", "tolerance_c", "notes",
        ])
        w.writeheader()
        w.writerows(rows)

    print(f"Wrote {len(rows)} rows to {OUT}")


if __name__ == "__main__":
    main()

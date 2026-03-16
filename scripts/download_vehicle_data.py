#!/usr/bin/env python3
"""
Download car makes & models from NHTSA API and save as a local JSON asset.
Run this script once to generate assets/vehicle_data.json for the Flutter app.

Usage:
    python3 scripts/download_vehicle_data.py
"""

import json
import time
import urllib.request
import urllib.error
import sys
import os

NHTSA_MAKES_URL = "https://vpic.nhtsa.dot.gov/api/vehicles/getallmakes?format=json"
NHTSA_MODELS_URL = "https://vpic.nhtsa.dot.gov/api/vehicles/getmodelsformake/{make}?format=json"

# Popular / well-known makes to include (covers ~99% of real-world usage).
# All other makes from the NHTSA list are included in the makes dropdown
# but will fall back to a live API call when the user selects them.
POPULAR_MAKES = [
    "Acura", "Alfa Romeo", "Aston Martin", "Audi", "Bentley", "BMW",
    "Bugatti", "Buick", "Cadillac", "Chevrolet", "Chrysler", "Citroen",
    "Dodge", "Ferrari", "Fiat", "Ford", "Genesis", "GMC", "Honda",
    "Hummer", "Hyundai", "Infiniti", "Jaguar", "Jeep", "Kia", "Lamborghini",
    "Land Rover", "Lexus", "Lincoln", "Lotus", "Maserati", "Maybach",
    "Mazda", "McLaren", "Mercedes-Benz", "MINI", "Mitsubishi", "Nissan",
    "Oldsmobile", "Opel", "Peugeot", "Plymouth", "Pontiac", "Porsche",
    "RAM", "Renault", "Rivian", "Rolls-Royce", "Saturn", "Scion",
    "Skoda", "Smart", "Subaru", "Suzuki", "Tesla", "Toyota", "Volkswagen",
    "Volvo", "Lucid", "Polestar", "BYD", "Mahindra", "Tata", "Maruti Suzuki",
    "Hero", "Royal Enfield", "Bajaj",
]


def fetch_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode())


def fetch_all_makes() -> list[str]:
    print("Fetching all makes from NHTSA...")
    data = fetch_json(NHTSA_MAKES_URL)
    results = data.get("Results", [])
    makes = sorted(
        {r["Make_Name"].strip() for r in results if r.get("Make_Name", "").strip()},
        key=str.casefold,
    )
    print(f"  Found {len(makes)} makes total.")
    return makes


def fetch_models_for_make(make: str) -> list[str]:
    url = NHTSA_MODELS_URL.format(make=urllib.parse.quote(make))
    data = fetch_json(url)
    results = data.get("Results", [])
    return sorted(
        {r["Model_Name"].strip() for r in results if r.get("Model_Name", "").strip()},
        key=str.casefold,
    )


def main():
    import urllib.parse  # needed inside fetch_models_for_make

    # 1. Fetch all makes
    all_makes = fetch_all_makes()

    # 2. Determine which popular makes exist in the NHTSA list (case-insensitive)
    all_makes_lower = {m.lower(): m for m in all_makes}
    makes_to_fetch = []
    for pm in POPULAR_MAKES:
        canonical = all_makes_lower.get(pm.lower())
        if canonical:
            makes_to_fetch.append(canonical)
        else:
            # Not in NHTSA list; still include the name we provided
            makes_to_fetch.append(pm)
    makes_to_fetch = sorted(set(makes_to_fetch), key=str.casefold)

    # 3. Fetch models for each popular make
    models_map: dict[str, list[str]] = {}
    total = len(makes_to_fetch)
    for i, make in enumerate(makes_to_fetch, 1):
        sys.stdout.write(f"\r  Fetching models: {i}/{total}  ({make})          ")
        sys.stdout.flush()
        try:
            models = fetch_models_for_make(make)
            if models:
                models_map[make] = models
        except Exception as e:
            print(f"\n  Warning: could not fetch models for '{make}': {e}")
        time.sleep(0.15)  # be polite to the public API

    print(f"\n  Fetched models for {len(models_map)} makes.")

    # 4. Build output
    output = {
        "makes": all_makes,
        "models": models_map,
    }

    # 5. Write to assets/vehicle_data.json (relative to repo root)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    out_path = os.path.join(repo_root, "flutter_app", "assets", "vehicle_data.json")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, separators=(",", ":"))

    size_kb = os.path.getsize(out_path) / 1024
    print(f"\nSaved to: {out_path}")
    print(f"File size: {size_kb:.1f} KB")
    print(f"Makes: {len(all_makes)}, Makes with models: {len(models_map)}")
    print("\nDone! Now run `flutter pub get` and rebuild the app.")


if __name__ == "__main__":
    main()

"""
Mappls (MapmyIndia) API Service — Nearby Vehicle Service Centers.

Search flow:
  1. OAuth Text Search (atlas.mappls.com/api/places/search/json)
     – sortBy=dist:asc, filter results within 50 km of user
  2. For each result: Route API (REST key) with eLoc as destination
     – gives actual driving distance, duration AND exact place coordinates
       from waypoints[1].location

Other helpers:
  – reverse_geocode   → REST key rev_geocode (human-readable address from coords)
  – get_place_detail  → OAuth placedetail (phone number by eLoc)
"""

import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)

_cached_token = None
_token_expiry = 0

MAX_DIST_M = 50_000   # ignore results farther than 50 km in text search


# ──────────────────────────────────────────────────────────
# OAuth token
# ──────────────────────────────────────────────────────────

def _get_access_token():
    global _cached_token, _token_expiry
    import time

    if _cached_token and time.time() < _token_expiry - 60:
        return _cached_token

    try:
        resp = requests.post(
            "https://outpost.mappls.com/api/security/oauth/token",
            data={
                "grant_type": "client_credentials",
                "client_id": settings.MAPPLS_CLIENT_ID,
                "client_secret": settings.MAPPLS_CLIENT_SECRET,
            },
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        _cached_token = data["access_token"]
        _token_expiry = time.time() + data.get("expires_in", 3600)
        logger.info("Mappls OAuth token obtained.")
        return _cached_token
    except Exception as e:
        logger.error(f"Mappls OAuth token failed: {e}")
        return None


# ──────────────────────────────────────────────────────────
# Route API  (REST key)
# ──────────────────────────────────────────────────────────

def _build_instruction(mtype, modifier, road):
    """Convert maneuver type + modifier into a human-readable instruction."""
    road_part = f" onto {road}" if road else ""
    if mtype == "depart":
        return f"Head{road_part}"
    if mtype == "arrive":
        return "Arrive at destination"
    if mtype == "turn":
        if "slight" in modifier:
            side = "left" if "left" in modifier else "right"
            return f"Keep {side}{road_part}"
        if "sharp" in modifier:
            side = "left" if "left" in modifier else "right"
            return f"Sharp turn {side}{road_part}"
        if modifier == "uturn":
            return f"Make a U-turn{road_part}"
        if modifier in ("left", "right"):
            return f"Turn {modifier}{road_part}"
        return f"Turn{road_part}"
    if mtype == "merge":
        return f"Merge {modifier}{road_part}" if modifier else f"Merge{road_part}"
    if mtype in ("on ramp",):
        return f"Take the ramp{road_part}"
    if mtype in ("off ramp",):
        return f"Take the exit{road_part}"
    if mtype in ("fork", "end of road"):
        side = "left" if "left" in modifier else "right"
        return f"Keep {side}{road_part}"
    if mtype in ("rotary", "roundabout", "roundabout turn"):
        return f"Enter the roundabout{road_part}"
    return f"Continue{road_part}"


def get_route(origin_lat, origin_lng, dest_eloc=None,
              dest_lat=None, dest_lng=None):
    """
    Full route with turn-by-turn steps and overview polyline from Mappls Route API.

    Destination priority: eLoc > lat/lng coordinates.

    Returns dict:
      distance_m, duration_s, distance_text, duration_text,
      overview_polyline, destination_lat, destination_lng,
      steps: [{instruction, distance_m, duration_s, distance_text,
               maneuver_type, maneuver_modifier, road_name}]
    or {} on failure.
    """
    rest_key = getattr(settings, "MAPPLS_REST_API_KEY", "")
    if not rest_key:
        return {}

    destination = dest_eloc if dest_eloc else (
        f"{dest_lng},{dest_lat}" if dest_lat is not None and dest_lng is not None
        else None
    )
    if not destination:
        return {}

    try:
        url = (
            f"https://apis.mappls.com/advancedmaps/v1/{rest_key}"
            f"/route_adv/driving/{origin_lng},{origin_lat};{destination}"
        )
        resp = requests.get(
            url,
            params={"steps": "true", "geometries": "polyline", "overview": "full"},
            timeout=15,
        )
        logger.info(f"GetRoute status={resp.status_code}")

        if resp.status_code != 200 or not resp.text.strip():
            return {}

        data = resp.json()
        if data.get("code") != "Ok":
            logger.warning(f"GetRoute code={data.get('code')}")
            return {}

        route      = data["routes"][0]
        leg        = route["legs"][0]
        waypoints  = data.get("waypoints", [])

        dist_m  = float(route.get("distance", 0))
        dur_s   = float(route.get("duration",  0))
        dist_km = dist_m / 1000.0
        dur_min = int(dur_s / 60)

        dist_text = f"{dist_km:.1f} km" if dist_km >= 1 else f"{int(dist_m)} m"
        dur_text  = (f"{dur_min} min" if dur_min < 60
                     else f"{dur_min // 60}h {dur_min % 60}m")

        # Destination coordinates from waypoints[1].location = [lng, lat]
        dest_coord_lat, dest_coord_lng = dest_lat, dest_lng
        if len(waypoints) >= 2:
            loc = waypoints[1].get("location", [])
            if len(loc) == 2:
                dest_coord_lng = float(loc[0])
                dest_coord_lat = float(loc[1])

        steps = []
        for s in leg.get("steps", []):
            m     = s.get("maneuver", {})
            mtype = m.get("type",     "")
            mmod  = m.get("modifier", "")
            road  = s.get("name", "") or s.get("ref", "")
            sdist = float(s.get("distance", 0))
            sdur  = float(s.get("duration",  0))
            sdist_text = (f"{sdist / 1000:.1f} km" if sdist >= 1000
                          else f"{int(sdist)} m")
            steps.append({
                "instruction":       _build_instruction(mtype, mmod, road),
                "distance_m":        sdist,
                "duration_s":        sdur,
                "distance_text":     sdist_text,
                "maneuver_type":     mtype,
                "maneuver_modifier": mmod,
                "road_name":         road,
            })

        return {
            "distance_m":        dist_m,
            "duration_s":        dur_s,
            "distance_text":     dist_text,
            "duration_text":     dur_text,
            "overview_polyline": route.get("geometry", ""),
            "steps":             steps,
            "destination_lat":   dest_coord_lat,
            "destination_lng":   dest_coord_lng,
        }

    except Exception as e:
        logger.error(f"GetRoute error: {e}")
        return {}


def _route_info(origin_lat, origin_lng, eloc):
    """
    Call Mappls Route API with eLoc as destination.
    Returns (distance_str, duration_str, place_lat, place_lng).
    All four values may be None on failure.
    """
    rest_key = getattr(settings, "MAPPLS_REST_API_KEY", "")
    if not rest_key or not eloc:
        return None, None, None, None

    try:
        # Coords are  lng,lat  order;  destination can be an eLoc string
        url = (
            f"https://apis.mappls.com/advancedmaps/v1/{rest_key}"
            f"/route_adv/driving/{origin_lng},{origin_lat};{eloc}"
        )
        resp = requests.get(url, params={"overview": "false"}, timeout=12)
        logger.info(f"Route [{eloc}] status={resp.status_code} body={resp.text[:300]}")

        if resp.status_code != 200 or not resp.text.strip():
            return None, None, None, None

        data = resp.json()
        routes = data.get("routes", [])
        waypoints = data.get("waypoints", [])

        dist_str = dur_str = place_lat = place_lng = None

        if routes:
            route = routes[0]
            dist_m = float(route.get("distance", 0))
            dur_s  = float(route.get("duration",  0))
            dist_km = dist_m / 1000.0
            dur_min = int(dur_s / 60)
            dist_str = f"{dist_km:.1f} km"
            dur_str  = (f"{dur_min} min" if dur_min < 60
                        else f"{dur_min // 60}h {dur_min % 60}m")

        # waypoints[1] is the destination; .location = [lng, lat]
        if len(waypoints) >= 2:
            loc = waypoints[1].get("location", [])
            if len(loc) == 2:
                place_lng = float(loc[0])
                place_lat = float(loc[1])

        return dist_str, dur_str, place_lat, place_lng

    except Exception as e:
        logger.warning(f"Route [{eloc}] error: {e}")
        return None, None, None, None


# ──────────────────────────────────────────────────────────
# Phone — OAuth Place Detail
# ──────────────────────────────────────────────────────────

def get_place_detail(eloc):
    """Return {'phone_number', 'latitude', 'longitude'} for an eLoc, or {}."""
    token = _get_access_token()
    if not token or not eloc:
        return {}

    # The placedetail endpoint is 404 for this plan; fall back to search-by-eLoc
    try:
        resp = requests.get(
            "https://atlas.mappls.com/api/places/search/json",
            params={"query": eloc, "region": "IND"},
            headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
            timeout=10,
        )
        if resp.status_code == 200 and resp.text.strip():
            locs = resp.json().get("suggestedLocations", [])
            if locs:
                p = locs[0]
                return {
                    "phone_number": p.get("telephone", "") or p.get("phone", ""),
                    "latitude": p.get("latitude"),
                    "longitude": p.get("longitude"),
                }
    except Exception as e:
        logger.warning(f"PlaceDetail [{eloc}]: {e}")

    return {}


# ──────────────────────────────────────────────────────────
# Reverse Geocode  (REST key)
# ──────────────────────────────────────────────────────────

def reverse_geocode(latitude, longitude):
    """Convert lat/lng → dict with locality, city, state, pincode, formatted_address."""
    rest_key = getattr(settings, "MAPPLS_REST_API_KEY", "")
    if not rest_key:
        return {}

    try:
        resp = requests.get(
            f"https://apis.mappls.com/advancedmaps/v1/{rest_key}/rev_geocode",
            params={"lat": latitude, "lng": longitude},
            timeout=10,
        )
        logger.info(f"RevGeocode status={resp.status_code} body={resp.text[:200]}")
        if resp.status_code == 200 and resp.text.strip():
            results = resp.json().get("results", [])
            if results:
                r = results[0]
                return {
                    "formatted_address": r.get("formattedAddress", ""),
                    "locality": r.get("locality") or r.get("subLocality", ""),
                    "city":     r.get("city", ""),
                    "state":    r.get("state", ""),
                    "pincode":  r.get("pincode", ""),
                    "poi":      r.get("poi", ""),
                }
    except Exception as e:
        logger.warning(f"RevGeocode ({latitude},{longitude}): {e}")

    return {}


# ──────────────────────────────────────────────────────────
# Text Search  (OAuth, sorted by distance)
# ──────────────────────────────────────────────────────────

def _text_search(token, keyword, latitude, longitude, radius_m):
    """
    Search places by keyword near user. Returns raw suggestedLocations list
    sorted by distance (metres), filtered to MAX_DIST_M.
    """
    try:
        resp = requests.get(
            "https://atlas.mappls.com/api/places/search/json",
            params={
                "query":    keyword,
                "location": f"{latitude},{longitude}",
                "radius":   radius_m,
                "sortBy":   "dist:asc",
                "region":   "IND",
            },
            headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
            timeout=15,
        )
        logger.info(f"TextSearch [{keyword}] status={resp.status_code} body={resp.text[:400]}")
        if resp.status_code != 200 or not resp.text.strip():
            return []

        locs = resp.json().get("suggestedLocations", [])
        # Sort by distance and drop anything beyond MAX_DIST_M
        locs.sort(key=lambda p: p.get("distance", 9_999_999))
        nearby = [p for p in locs if p.get("distance", 9_999_999) <= MAX_DIST_M]
        logger.info(f"TextSearch [{keyword}] → {len(nearby)} within 50 km (total {len(locs)})")
        return nearby

    except Exception as e:
        logger.warning(f"TextSearch [{keyword}]: {e}")
        return []


# ──────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────

def search_nearby_service_centers(latitude, longitude, keyword,
                                  radius_m=10000, limit=5):
    """
    Find nearby vehicle service centers sorted by driving distance.

    Steps:
      1. OAuth Text Search with sortBy=dist:asc — keyword + fallbacks
      2. For each result within 50 km:
           Route API (eLoc dest) → driving distance + duration + exact lat/lng
      3. Return list sorted by driving distance, capped at `limit`

    Args:
        latitude, longitude : user GPS coordinates (float)
        keyword             : search term from AI analysis
        radius_m            : search radius in metres (default 10 km)
        limit               : max results to return

    Returns:
        List of service-center dicts, [] on failure.
    """
    lat = float(latitude)
    lng = float(longitude)

    token = _get_access_token()
    if not token:
        logger.error("Cannot get Mappls token — aborting search.")
        return []

    # Try keyword variants until we get results
    keywords_to_try = list(dict.fromkeys([
        keyword,
        "car service center",
        "automobile workshop",
        "auto repair",
    ]))

    raw_places = []
    used_kw = keyword
    for kw in keywords_to_try:
        raw_places = _text_search(token, kw, lat, lng, radius_m)
        if raw_places:
            used_kw = kw
            break

    if not raw_places:
        logger.warning("All keyword variants returned no nearby results.")
        return []

    # ── Enrich each place with Route API ─────────────────
    results = []
    for place in raw_places:
        eloc = place.get("eLoc", "")
        if not eloc:
            continue

        # Route API → driving dist + duration + actual place lat/lng
        dist_str, dur_str, place_lat, place_lng = _route_info(lat, lng, eloc)

        # Fallback distance string from text-search distance field (metres)
        if not dist_str:
            raw_m = place.get("distance", 0)
            try:
                dist_str = f"{float(raw_m) / 1000.0:.1f} km"
            except (TypeError, ValueError):
                dist_str = "N/A"

        distance_display = f"{dist_str} ({dur_str} drive)" if dur_str else dist_str

        # Phone: text search rarely has it; skip extra API call to keep it fast
        phone = place.get("telephone", "") or place.get("phone", "")

        results.append({
            "name":           place.get("placeName", "Service Center"),
            "address":        place.get("placeAddress", ""),
            "phone_number":   phone,
            "rating":         0.0,
            "total_reviews":  0,
            "distance":       distance_display,
            # Use route waypoint coords; fall back to user coords only if unavailable
            "latitude":       place_lat if place_lat is not None else lat,
            "longitude":      place_lng if place_lng is not None else lng,
            "opening_hours":  "",
            "services_offered": used_kw,
            "place_id":       eloc,
        })

        if len(results) >= limit:
            break

    # Sort by numeric km value extracted from distance string
    def _km(r):
        try:
            return float(r["distance"].split(" km")[0])
        except Exception:
            return 9999.0

    results.sort(key=_km)
    logger.info(f"Returning {len(results)} service centers near ({lat},{lng}).")
    return results

"""
API Views for the Car Service Assistance Application.
"""

import logging
from rest_framework import status, generics, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.conf import settings

from .models import User, ScanHistory, ServiceCenter, Vehicle, ServiceRecord
from .serializers import (
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserProfileSerializer,
    ScanHistorySerializer,
    ScanUploadSerializer,
    ServiceCenterSerializer,
    VehicleSerializer,
    ServiceRecordSerializer,
)
from .ai_service import analyze_vehicle_image, get_service_search_keyword
from .mappls_service import search_nearby_service_centers, get_place_detail, reverse_geocode, get_route

logger = logging.getLogger(__name__)


# ============================================================
# Authentication Views
# ============================================================

@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    """Register a new user account."""
    serializer = UserRegistrationSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            "success": True,
            "message": "Account created successfully.",
            "data": {
                "user": UserProfileSerializer(user).data,
                "token": token.key,
            }
        }, status=status.HTTP_201_CREATED)
    return Response({
        "success": False,
        "message": "Registration failed.",
        "errors": serializer.errors,
    }, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@permission_classes([AllowAny])
def login(request):
    """Authenticate user and return token."""
    serializer = UserLoginSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.validated_data["user"]
        token, _ = Token.objects.get_or_create(user=user)
        return Response({
            "success": True,
            "message": "Login successful.",
            "data": {
                "user": UserProfileSerializer(user).data,
                "token": token.key,
            }
        })
    return Response({
        "success": False,
        "message": "Invalid credentials.",
        "errors": serializer.errors,
    }, status=status.HTTP_401_UNAUTHORIZED)


@api_view(["POST"])
@permission_classes([AllowAny])
def forgot_password(request):
    """
    Accept an email and generate a new temporary password for the user.
    In production replace the email section with a proper mail backend.
    """
    email = request.data.get("email", "").strip()
    if not email:
        return Response({
            "success": False,
            "message": "Email is required.",
        }, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        # Return success anyway to avoid user enumeration
        return Response({
            "success": True,
            "message": "If this email is registered, a reset link has been sent.",
        })

    # Generate a temporary password
    import secrets, string
    temp_password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(10))
    user.set_password(temp_password)
    user.save()

    # Log for development (replace with email sending in production)
    logger.info(f"Password reset for {email}. Temp password: {temp_password}")

    return Response({
        "success": True,
        "message": "If this email is registered, a reset link has been sent.",
    })


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def logout(request):
    """Logout user by deleting token."""
    try:
        request.user.auth_token.delete()
    except Exception:
        pass
    return Response({
        "success": True,
        "message": "Logged out successfully.",
    })


# ============================================================
# Profile Views
# ============================================================

@api_view(["GET", "PUT"])
@permission_classes([IsAuthenticated])
def profile(request):
    """Get or update user profile."""
    if request.method == "GET":
        serializer = UserProfileSerializer(request.user)
        return Response({
            "success": True,
            "data": serializer.data,
        })

    elif request.method == "PUT":
        serializer = UserProfileSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                "success": True,
                "message": "Profile updated successfully.",
                "data": serializer.data,
            })
        return Response({
            "success": False,
            "errors": serializer.errors,
        }, status=status.HTTP_400_BAD_REQUEST)


# ============================================================
# Scan / AI Analysis Views
# ============================================================

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def analyze_image(request):
    """
    Upload a vehicle image and get AI diagnosis.
    Also searches for nearby service centers.
    """
    serializer = ScanUploadSerializer(data=request.data)
    if not serializer.is_valid():
        return Response({
            "success": False,
            "message": "Invalid image upload.",
            "errors": serializer.errors,
        }, status=status.HTTP_400_BAD_REQUEST)

    # Save the scan record
    scan = serializer.save(user=request.user)

    # Run AI analysis
    image_path = scan.image.path
    user_description = scan.description or ""

    logger.info(f"Analyzing image: {image_path}")
    ai_result = analyze_vehicle_image(image_path, user_description)

    # Reject if no vehicle was detected in the image
    if ai_result.get("no_vehicle_detected") is True:
        scan.delete()
        return Response({
            "success": False,
            "message": "No vehicle detected in the image. Please upload a clear photo of your vehicle.",
        }, status=status.HTTP_400_BAD_REQUEST)

    # Update scan with AI results
    scan.detected_issue = ai_result.get("detected_issue", "Unknown Issue")
    scan.problem_explanation = ai_result.get("problem_explanation", "")
    scan.possible_causes = ai_result.get("possible_causes", "")
    scan.urgency_level = ai_result.get("urgency_level", "medium")
    scan.confidence_score = ai_result.get("confidence_score", 0)
    scan.recommended_service_type = ai_result.get("recommended_service_type", "")
    scan.ai_raw_response = ai_result.get("raw_response", "")
    scan.is_analyzed = True
    scan.save()

    # Search real nearby service centers using Mappls API
    service_keyword = get_service_search_keyword(scan.detected_issue)
    latitude = request.data.get("latitude")
    longitude = request.data.get("longitude")
    logger.info(f"Location received: lat={latitude}, lng={longitude}, keyword={service_keyword}")

    centers = []
    if latitude and longitude:
        try:
            centers = search_nearby_service_centers(
                latitude=float(latitude),
                longitude=float(longitude),
                keyword=service_keyword,
            )
        except (ValueError, TypeError) as e:
            logger.error(f"Location parse error: {e}")
    else:
        logger.warning("No location provided by client – skipping Mappls search.")

    if centers:
        for center_data in centers:
            ServiceCenter.objects.create(scan=scan, **center_data)
        logger.info(f"Saved {len(centers)} Mappls service centers for scan {scan.id}.")
    else:
        logger.warning("Mappls returned no results — no location or no nearby centers found.")

    # Return full result (pass request for absolute image URLs)
    result_serializer = ScanHistorySerializer(scan, context={"request": request})
    return Response({
        "success": True,
        "message": "Vehicle issue analyzed successfully.",
        "data": result_serializer.data,
    }, status=status.HTTP_200_OK)


# ============================================================
# Scan History Views
# ============================================================

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def scan_history(request):
    """Get all scan history for the authenticated user."""
    scans = ScanHistory.objects.filter(user=request.user)
    serializer = ScanHistorySerializer(scans, many=True, context={"request": request})
    return Response({
        "success": True,
        "data": serializer.data,
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def scan_detail(request, scan_id):
    """Get detailed scan result with service center recommendations."""
    try:
        scan = ScanHistory.objects.get(id=scan_id, user=request.user)
    except ScanHistory.DoesNotExist:
        return Response({
            "success": False,
            "message": "Scan not found.",
        }, status=status.HTTP_404_NOT_FOUND)

    serializer = ScanHistorySerializer(scan, context={"request": request})
    return Response({
        "success": True,
        "data": serializer.data,
    })


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def delete_scan(request, scan_id):
    """Delete a scan record."""
    try:
        scan = ScanHistory.objects.get(id=scan_id, user=request.user)
        scan.delete()
        return Response({
            "success": True,
            "message": "Scan deleted successfully.",
        })
    except ScanHistory.DoesNotExist:
        return Response({
            "success": False,
            "message": "Scan not found.",
        }, status=status.HTTP_404_NOT_FOUND)


# ============================================================
# Service Centers View
# ============================================================

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def service_centers(request, scan_id):
    """Get service centers for a specific scan."""
    try:
        scan = ScanHistory.objects.get(id=scan_id, user=request.user)
    except ScanHistory.DoesNotExist:
        return Response({
            "success": False,
            "message": "Scan not found.",
        }, status=status.HTTP_404_NOT_FOUND)

    centers = ServiceCenter.objects.filter(scan=scan)
    serializer = ServiceCenterSerializer(centers, many=True)
    return Response({
        "success": True,
        "data": serializer.data,
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def place_detail(request, eloc):
    """Fetch phone number and coordinates for a Mappls place by eLoc."""
    detail = get_place_detail(eloc)
    return Response({"success": True, "data": detail})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def reverse_geocode_view(request):
    """
    Reverse geocode lat/lng to a human-readable address using Mappls REST API.
    Query params: lat, lng
    """
    lat = request.query_params.get("lat")
    lng = request.query_params.get("lng")
    if not lat or not lng:
        return Response(
            {"success": False, "message": "lat and lng query params are required."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        result = reverse_geocode(float(lat), float(lng))
        return Response({"success": True, "data": result})
    except (ValueError, TypeError):
        return Response(
            {"success": False, "message": "Invalid lat/lng values."},
            status=status.HTTP_400_BAD_REQUEST,
        )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def route_directions(request):
    """
    Get turn-by-turn route from user location to a service center.

    Query params:
      origin_lat, origin_lng  — user's current GPS coordinates
      eloc                    — Mappls eLoc of destination (preferred)
      dest_lat, dest_lng      — fallback destination coordinates

    Returns steps[], overview_polyline, distance_text, duration_text.
    """
    origin_lat = request.query_params.get("origin_lat")
    origin_lng = request.query_params.get("origin_lng")
    eloc       = request.query_params.get("eloc", "").strip()
    dest_lat   = request.query_params.get("dest_lat")
    dest_lng   = request.query_params.get("dest_lng")

    if not origin_lat or not origin_lng:
        return Response(
            {"success": False, "message": "origin_lat and origin_lng are required."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not eloc and not (dest_lat and dest_lng):
        return Response(
            {"success": False, "message": "Provide eloc or dest_lat+dest_lng."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        result = get_route(
            origin_lat=float(origin_lat),
            origin_lng=float(origin_lng),
            dest_eloc=eloc or None,
            dest_lat=float(dest_lat) if dest_lat else None,
            dest_lng=float(dest_lng) if dest_lng else None,
        )
        if not result:
            return Response(
                {"success": False, "message": "Could not calculate route."},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response({"success": True, "data": result})
    except (ValueError, TypeError) as e:
        return Response(
            {"success": False, "message": f"Invalid parameters: {e}"},
            status=status.HTTP_400_BAD_REQUEST,
        )


# ============================================================
# Garage – Vehicle Views
# ============================================================

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def vehicle_list(request):
    """List all vehicles or add a new vehicle for the authenticated user."""
    if request.method == "GET":
        vehicles = Vehicle.objects.filter(user=request.user)
        serializer = VehicleSerializer(vehicles, many=True)
        return Response({"success": True, "data": serializer.data})

    serializer = VehicleSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save(user=request.user)
        return Response({"success": True, "data": serializer.data}, status=status.HTTP_201_CREATED)
    return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["GET", "PUT", "DELETE"])
@permission_classes([IsAuthenticated])
def vehicle_detail(request, vehicle_id):
    """Retrieve, update, or delete a vehicle."""
    try:
        vehicle = Vehicle.objects.get(id=vehicle_id, user=request.user)
    except Vehicle.DoesNotExist:
        return Response({"success": False, "message": "Vehicle not found."}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        serializer = VehicleSerializer(vehicle)
        return Response({"success": True, "data": serializer.data})

    if request.method == "PUT":
        serializer = VehicleSerializer(vehicle, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({"success": True, "data": serializer.data})
        return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

    vehicle.delete()
    return Response({"success": True, "message": "Vehicle deleted."})


# ============================================================
# Garage – Service Record Views
# ============================================================

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def service_record_list(request, vehicle_id):
    """List all service records or add one for a vehicle."""
    try:
        vehicle = Vehicle.objects.get(id=vehicle_id, user=request.user)
    except Vehicle.DoesNotExist:
        return Response({"success": False, "message": "Vehicle not found."}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        records = ServiceRecord.objects.filter(vehicle=vehicle)
        serializer = ServiceRecordSerializer(records, many=True, context={"request": request})
        return Response({"success": True, "data": serializer.data})

    serializer = ServiceRecordSerializer(data=request.data, context={"request": request})
    if serializer.is_valid():
        serializer.save(vehicle=vehicle)
        return Response({"success": True, "data": serializer.data}, status=status.HTTP_201_CREATED)
    return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["GET", "PUT", "DELETE"])
@permission_classes([IsAuthenticated])
def service_record_detail(request, vehicle_id, record_id):
    """Retrieve, update, or delete a service record."""
    try:
        vehicle = Vehicle.objects.get(id=vehicle_id, user=request.user)
        record = ServiceRecord.objects.get(id=record_id, vehicle=vehicle)
    except (Vehicle.DoesNotExist, ServiceRecord.DoesNotExist):
        return Response({"success": False, "message": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        serializer = ServiceRecordSerializer(record, context={"request": request})
        return Response({"success": True, "data": serializer.data})

    if request.method == "PUT":
        serializer = ServiceRecordSerializer(record, data=request.data, partial=True, context={"request": request})
        if serializer.is_valid():
            serializer.save()
            return Response({"success": True, "data": serializer.data})
        return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

    record.delete()
    return Response({"success": True, "message": "Service record deleted."})

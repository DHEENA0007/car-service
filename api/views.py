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

from .models import User, ScanHistory, ServiceCenter
from .serializers import (
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserProfileSerializer,
    ScanHistorySerializer,
    ScanUploadSerializer,
    ServiceCenterSerializer,
)
from .ai_service import analyze_vehicle_image, get_service_search_keyword

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

    # Generate mock nearby service centers based on the detected issue
    service_keyword = get_service_search_keyword(scan.detected_issue)
    _create_sample_service_centers(scan, service_keyword)

    # Return full result
    result_serializer = ScanHistorySerializer(scan)
    return Response({
        "success": True,
        "message": "Vehicle issue analyzed successfully.",
        "data": result_serializer.data,
    }, status=status.HTTP_200_OK)


def _create_sample_service_centers(scan, service_keyword):
    """
    Create sample service centers for the scan.
    In production, this would call Google Places API.
    For now, provides realistic sample data.
    """
    sample_centers = [
        {
            "name": "AutoCare Pro Service Center",
            "address": "123 Main Street, Near City Center, Bangalore 560001",
            "phone_number": "+91 9876543210",
            "rating": 4.7,
            "total_reviews": 342,
            "distance": "1.2 km",
            "latitude": 12.9716,
            "longitude": 77.5946,
            "opening_hours": "Mon-Sat: 8:00 AM - 8:00 PM, Sun: 9:00 AM - 5:00 PM",
            "services_offered": f"{service_keyword}, General maintenance, Oil change, Brake repair",
        },
        {
            "name": "Quick Fix Auto Workshop",
            "address": "456 MG Road, Koramangala, Bangalore 560034",
            "phone_number": "+91 9876543211",
            "rating": 4.5,
            "total_reviews": 218,
            "distance": "2.5 km",
            "latitude": 12.9352,
            "longitude": 77.6245,
            "opening_hours": "Mon-Sat: 7:30 AM - 9:00 PM",
            "services_offered": f"{service_keyword}, Engine diagnostics, Suspension repair",
        },
        {
            "name": "Mahindra First Choice Services",
            "address": "789 Outer Ring Road, HSR Layout, Bangalore 560102",
            "phone_number": "+91 9876543212",
            "rating": 4.4,
            "total_reviews": 567,
            "distance": "3.8 km",
            "latitude": 12.9141,
            "longitude": 77.6501,
            "opening_hours": "Mon-Sun: 8:00 AM - 8:00 PM",
            "services_offered": f"{service_keyword}, Multi-brand service, AC repair, Denting & painting",
        },
        {
            "name": "GoMechanic - Indiranagar",
            "address": "101 12th Main Road, Indiranagar, Bangalore 560038",
            "phone_number": "+91 9876543213",
            "rating": 4.3,
            "total_reviews": 892,
            "distance": "4.1 km",
            "latitude": 12.9784,
            "longitude": 77.6408,
            "opening_hours": "Mon-Sat: 9:00 AM - 7:00 PM",
            "services_offered": f"{service_keyword}, Periodic maintenance, Battery replacement, Tyre services",
        },
        {
            "name": "Bosch Car Service Center",
            "address": "202 Bannerghatta Road, JP Nagar, Bangalore 560078",
            "phone_number": "+91 9876543214",
            "rating": 4.2,
            "total_reviews": 445,
            "distance": "5.3 km",
            "latitude": 12.9081,
            "longitude": 77.5929,
            "opening_hours": "Mon-Fri: 8:30 AM - 6:30 PM, Sat: 9:00 AM - 4:00 PM",
            "services_offered": f"{service_keyword}, Electronic diagnostics, Clutch repair, Wheel alignment",
        },
    ]

    for center_data in sample_centers:
        ServiceCenter.objects.create(scan=scan, **center_data)


# ============================================================
# Scan History Views
# ============================================================

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def scan_history(request):
    """Get all scan history for the authenticated user."""
    scans = ScanHistory.objects.filter(user=request.user)
    serializer = ScanHistorySerializer(scans, many=True)
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

    serializer = ScanHistorySerializer(scan)
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

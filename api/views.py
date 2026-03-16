"""
API Views for the Car Service Assistance Application.
"""

import hmac
import hashlib
import logging
import razorpay
from django.utils import timezone
from rest_framework import status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.conf import settings

from .models import (
    User, ScanHistory, ServiceCenter, Vehicle, ServiceRecord,
    AgentProfile, Booking, ChargeSheet,
)
from .serializers import (
    UserRegistrationSerializer,
    UserLoginSerializer,
    UserProfileSerializer,
    ScanHistorySerializer,
    ScanHistoryAdminSerializer,
    ScanUploadSerializer,
    ServiceCenterSerializer,
    VehicleSerializer,
    ServiceRecordSerializer,
    AgentProfileSerializer,
    BookingSerializer,
    BookingCreateSerializer,
    ChargeSheetSerializer,
    ChargeSheetCreateSerializer,
    AdminUserSerializer,
)
from .ai_service import analyze_vehicle_image, get_service_search_keyword
from .mappls_service import search_nearby_service_centers, get_place_detail, reverse_geocode, get_route

logger = logging.getLogger(__name__)

RAZORPAY_KEY_ID = 'rzp_test_SL5EZ7JYyCLRiq'
RAZORPAY_KEY_SECRET = 'cbDPQrSE8K435CKCryZgsOuY'

razorpay_client = razorpay.Client(auth=(RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET))


def is_admin(user):
    return user.role == 'admin' or user.is_superuser


def is_agent(user):
    return user.role == 'agent'


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
    """Accept an email and generate a new temporary password."""
    email = request.data.get("email", "").strip()
    if not email:
        return Response({
            "success": False,
            "message": "Email is required.",
        }, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response({
            "success": True,
            "message": "If this email is registered, a reset link has been sent.",
        })

    import secrets, string
    temp_password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(10))
    user.set_password(temp_password)
    user.save()
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
    """Upload a vehicle image and get AI diagnosis. Also searches nearby service centers."""
    serializer = ScanUploadSerializer(data=request.data)
    if not serializer.is_valid():
        return Response({
            "success": False,
            "message": "Invalid image upload.",
            "errors": serializer.errors,
        }, status=status.HTTP_400_BAD_REQUEST)

    scan = serializer.save(user=request.user)
    image_path = scan.image.path
    user_description = scan.description or ""

    logger.info(f"Analyzing image: {image_path}")
    ai_result = analyze_vehicle_image(image_path, user_description)

    if ai_result.get("no_vehicle_detected") is True:
        scan.delete()
        return Response({
            "success": False,
            "message": "No vehicle detected in the image. Please upload a clear photo of your vehicle.",
        }, status=status.HTTP_400_BAD_REQUEST)

    scan.detected_issue = ai_result.get("detected_issue", "Unknown Issue")
    scan.problem_explanation = ai_result.get("problem_explanation", "")
    scan.possible_causes = ai_result.get("possible_causes", "")
    scan.urgency_level = ai_result.get("urgency_level", "medium")
    scan.confidence_score = ai_result.get("confidence_score", 0)
    scan.recommended_service_type = ai_result.get("recommended_service_type", "")
    scan.ai_raw_response = ai_result.get("raw_response", "")
    scan.is_analyzed = True
    scan.save()

    service_keyword = get_service_search_keyword(scan.detected_issue)
    latitude = request.data.get("latitude")
    longitude = request.data.get("longitude")

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

    if centers:
        for center_data in centers:
            ServiceCenter.objects.create(scan=scan, **center_data)

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
    scans = ScanHistory.objects.filter(user=request.user)
    serializer = ScanHistorySerializer(scans, many=True, context={"request": request})
    return Response({"success": True, "data": serializer.data})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def scan_detail(request, scan_id):
    try:
        scan = ScanHistory.objects.get(id=scan_id, user=request.user)
    except ScanHistory.DoesNotExist:
        return Response({"success": False, "message": "Scan not found."}, status=status.HTTP_404_NOT_FOUND)
    serializer = ScanHistorySerializer(scan, context={"request": request})
    return Response({"success": True, "data": serializer.data})


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def delete_scan(request, scan_id):
    try:
        scan = ScanHistory.objects.get(id=scan_id, user=request.user)
        scan.delete()
        return Response({"success": True, "message": "Scan deleted successfully."})
    except ScanHistory.DoesNotExist:
        return Response({"success": False, "message": "Scan not found."}, status=status.HTTP_404_NOT_FOUND)


# ============================================================
# Service Centers View
# ============================================================

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def service_centers(request, scan_id):
    try:
        scan = ScanHistory.objects.get(id=scan_id, user=request.user)
    except ScanHistory.DoesNotExist:
        return Response({"success": False, "message": "Scan not found."}, status=status.HTTP_404_NOT_FOUND)
    centers = ServiceCenter.objects.filter(scan=scan)
    serializer = ServiceCenterSerializer(centers, many=True)
    return Response({"success": True, "data": serializer.data})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def place_detail(request, eloc):
    detail = get_place_detail(eloc)
    return Response({"success": True, "data": detail})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def reverse_geocode_view(request):
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
            return Response({"success": False, "message": "Could not calculate route."}, status=status.HTTP_404_NOT_FOUND)
        return Response({"success": True, "data": result})
    except (ValueError, TypeError) as e:
        return Response({"success": False, "message": f"Invalid parameters: {e}"}, status=status.HTTP_400_BAD_REQUEST)


# ============================================================
# Garage – Vehicle Views
# ============================================================

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def vehicle_list(request):
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
    try:
        vehicle = Vehicle.objects.get(id=vehicle_id, user=request.user)
    except Vehicle.DoesNotExist:
        return Response({"success": False, "message": "Vehicle not found."}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        return Response({"success": True, "data": VehicleSerializer(vehicle).data})

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
    try:
        vehicle = Vehicle.objects.get(id=vehicle_id, user=request.user)
        record = ServiceRecord.objects.get(id=record_id, vehicle=vehicle)
    except (Vehicle.DoesNotExist, ServiceRecord.DoesNotExist):
        return Response({"success": False, "message": "Not found."}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        return Response({"success": True, "data": ServiceRecordSerializer(record, context={"request": request}).data})

    if request.method == "PUT":
        serializer = ServiceRecordSerializer(record, data=request.data, partial=True, context={"request": request})
        if serializer.is_valid():
            serializer.save()
            return Response({"success": True, "data": serializer.data})
        return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

    record.delete()
    return Response({"success": True, "message": "Service record deleted."})


# ============================================================
# Booking Views
# ============================================================

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def booking_list(request):
    """
    GET: User sees their bookings; Agent sees their accepted bookings.
    POST: User creates a new booking (broadcast to all agents).
    """
    if request.method == "GET":
        if is_agent(request.user):
            bookings = Booking.objects.filter(agent=request.user)
        else:
            bookings = Booking.objects.filter(user=request.user)
        serializer = BookingSerializer(bookings, many=True)
        return Response({"success": True, "data": serializer.data})

    # Create booking (users only)
    if is_agent(request.user):
        return Response({"success": False, "message": "Agents cannot create bookings."}, status=status.HTTP_403_FORBIDDEN)

    serializer = BookingCreateSerializer(data=request.data)
    if serializer.is_valid():
        booking = serializer.save(user=request.user)
        return Response({
            "success": True,
            "message": "Booking submitted. Waiting for an agent to pick it up.",
            "data": BookingSerializer(booking).data,
        }, status=status.HTTP_201_CREATED)
    return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def booking_available(request):
    """Agents only: list all pending bookings available for pickup."""
    if not is_agent(request.user):
        return Response({"success": False, "message": "Only agents can view available bookings."}, status=status.HTTP_403_FORBIDDEN)

    # Only show to approved agents
    try:
        agent_profile = request.user.agent_profile
        if not agent_profile.is_approved:
            return Response({"success": False, "message": "Your agent account is pending admin approval."}, status=status.HTTP_403_FORBIDDEN)
    except AgentProfile.DoesNotExist:
        return Response({"success": False, "message": "Agent profile not found."}, status=status.HTTP_404_NOT_FOUND)

    bookings = Booking.objects.filter(status='pending').select_related('user')
    serializer = BookingSerializer(bookings, many=True)
    return Response({"success": True, "data": serializer.data})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def booking_detail(request, booking_id):
    """Get booking detail. User sees own, agent sees assigned, admin sees all."""
    try:
        if is_admin(request.user):
            booking = Booking.objects.get(id=booking_id)
        elif is_agent(request.user):
            booking = Booking.objects.get(id=booking_id, agent=request.user)
        else:
            booking = Booking.objects.get(id=booking_id, user=request.user)
    except Booking.DoesNotExist:
        return Response({"success": False, "message": "Booking not found."}, status=status.HTTP_404_NOT_FOUND)

    serializer = BookingSerializer(booking)
    return Response({"success": True, "data": serializer.data})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def booking_accept(request, booking_id):
    """Agent accepts a pending booking."""
    if not is_agent(request.user):
        return Response({"success": False, "message": "Only agents can accept bookings."}, status=status.HTTP_403_FORBIDDEN)

    try:
        agent_profile = request.user.agent_profile
        if not agent_profile.is_approved:
            return Response({"success": False, "message": "Your account is pending admin approval."}, status=status.HTTP_403_FORBIDDEN)
    except AgentProfile.DoesNotExist:
        return Response({"success": False, "message": "Agent profile not found."}, status=status.HTTP_404_NOT_FOUND)

    try:
        booking = Booking.objects.get(id=booking_id, status='pending')
    except Booking.DoesNotExist:
        return Response({"success": False, "message": "Booking not found or already accepted."}, status=status.HTTP_404_NOT_FOUND)

    booking.agent = request.user
    booking.status = 'accepted'
    booking.accepted_at = timezone.now()
    booking.save()

    return Response({
        "success": True,
        "message": "Booking accepted successfully.",
        "data": BookingSerializer(booking).data,
    })


@api_view(["PUT"])
@permission_classes([IsAuthenticated])
def booking_update_status(request, booking_id):
    """Agent updates booking status: in_progress or completed."""
    if not is_agent(request.user):
        return Response({"success": False, "message": "Only agents can update booking status."}, status=status.HTTP_403_FORBIDDEN)

    try:
        booking = Booking.objects.get(id=booking_id, agent=request.user)
    except Booking.DoesNotExist:
        return Response({"success": False, "message": "Booking not found."}, status=status.HTTP_404_NOT_FOUND)

    new_status = request.data.get("status")
    allowed = ['in_progress', 'completed', 'cancelled']
    if new_status not in allowed:
        return Response({"success": False, "message": f"Status must be one of: {allowed}"}, status=status.HTTP_400_BAD_REQUEST)

    booking.status = new_status
    if new_status == 'completed':
        booking.completed_at = timezone.now()
        # Update agent stats
        try:
            agent_profile = request.user.agent_profile
            agent_profile.total_completed += 1
            agent_profile.save()
        except AgentProfile.DoesNotExist:
            pass
    booking.save()

    return Response({
        "success": True,
        "message": f"Booking status updated to {new_status}.",
        "data": BookingSerializer(booking).data,
    })


# ============================================================
# Charge Sheet Views
# ============================================================

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def charge_sheet_create(request):
    """Agent creates a charge sheet for a booking."""
    if not is_agent(request.user):
        return Response({"success": False, "message": "Only agents can create charge sheets."}, status=status.HTTP_403_FORBIDDEN)

    booking_id = request.data.get('booking_id')
    if not booking_id:
        return Response({"success": False, "message": "booking_id is required."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        booking = Booking.objects.get(id=booking_id, agent=request.user)
    except Booking.DoesNotExist:
        return Response({"success": False, "message": "Booking not found."}, status=status.HTTP_404_NOT_FOUND)

    if hasattr(booking, 'charge_sheet'):
        # Update existing
        serializer = ChargeSheetCreateSerializer(booking.charge_sheet, data=request.data, partial=True)
    else:
        serializer = ChargeSheetCreateSerializer(data=request.data)

    if serializer.is_valid():
        charge_sheet = serializer.save()
        return Response({
            "success": True,
            "data": ChargeSheetSerializer(charge_sheet).data,
        }, status=status.HTTP_201_CREATED)
    return Response({"success": False, "errors": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def charge_sheet_detail(request, booking_id):
    """Get charge sheet for a booking."""
    try:
        if is_agent(request.user):
            booking = Booking.objects.get(id=booking_id, agent=request.user)
        elif is_admin(request.user):
            booking = Booking.objects.get(id=booking_id)
        else:
            booking = Booking.objects.get(id=booking_id, user=request.user)
    except Booking.DoesNotExist:
        return Response({"success": False, "message": "Booking not found."}, status=status.HTTP_404_NOT_FOUND)

    if not hasattr(booking, 'charge_sheet'):
        return Response({"success": False, "message": "No charge sheet yet."}, status=status.HTTP_404_NOT_FOUND)

    serializer = ChargeSheetSerializer(booking.charge_sheet)
    return Response({"success": True, "data": serializer.data})


# ============================================================
# Payment Views (Razorpay)
# ============================================================

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def payment_create_order(request):
    """Create a Razorpay order for a booking's charge sheet."""
    booking_id = request.data.get('booking_id')
    if not booking_id:
        return Response({"success": False, "message": "booking_id is required."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        booking = Booking.objects.get(id=booking_id, user=request.user)
    except Booking.DoesNotExist:
        return Response({"success": False, "message": "Booking not found."}, status=status.HTTP_404_NOT_FOUND)

    if booking.is_paid:
        return Response({"success": False, "message": "This booking is already paid."}, status=status.HTTP_400_BAD_REQUEST)

    if not hasattr(booking, 'charge_sheet'):
        return Response({"success": False, "message": "Charge sheet not ready yet."}, status=status.HTTP_404_NOT_FOUND)

    amount_paise = int(float(booking.charge_sheet.total_amount) * 100)  # Razorpay uses paise

    try:
        order = razorpay_client.order.create({
            'amount': amount_paise,
            'currency': 'INR',
            'payment_capture': 1,
            'notes': {
                'booking_id': str(booking.id),
                'user': booking.user.username,
            }
        })
        booking.razorpay_order_id = order['id']
        booking.charge_sheet.razorpay_order_id = order['id']
        booking.save()
        booking.charge_sheet.save()

        return Response({
            "success": True,
            "data": {
                "order_id": order['id'],
                "amount": amount_paise,
                "currency": "INR",
                "key": RAZORPAY_KEY_ID,
                "booking_id": booking.id,
                "description": f"Car Service Booking #{booking.id}",
                "prefill": {
                    "name": booking.contact_name,
                    "contact": booking.contact_phone,
                    "email": booking.user.email,
                }
            }
        })
    except Exception as e:
        logger.error(f"Razorpay order creation failed: {e}")
        return Response({"success": False, "message": "Payment initiation failed."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def payment_verify(request):
    """Verify Razorpay payment signature and mark booking as paid."""
    booking_id = request.data.get('booking_id')
    razorpay_payment_id = request.data.get('razorpay_payment_id')
    razorpay_order_id = request.data.get('razorpay_order_id')
    razorpay_signature = request.data.get('razorpay_signature')

    if not all([booking_id, razorpay_payment_id, razorpay_order_id, razorpay_signature]):
        return Response({"success": False, "message": "All payment fields are required."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        booking = Booking.objects.get(id=booking_id, user=request.user)
    except Booking.DoesNotExist:
        return Response({"success": False, "message": "Booking not found."}, status=status.HTTP_404_NOT_FOUND)

    # Verify signature
    msg = f"{razorpay_order_id}|{razorpay_payment_id}"
    expected_signature = hmac.new(
        RAZORPAY_KEY_SECRET.encode('utf-8'),
        msg.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()

    if not hmac.compare_digest(expected_signature, razorpay_signature):
        return Response({"success": False, "message": "Payment verification failed. Invalid signature."}, status=status.HTTP_400_BAD_REQUEST)

    booking.is_paid = True
    booking.payment_id = razorpay_payment_id
    if booking.status != 'completed':
        booking.status = 'completed'
        booking.completed_at = timezone.now()
    booking.save()

    return Response({
        "success": True,
        "message": "Payment verified successfully.",
        "data": BookingSerializer(booking).data,
    })


# ============================================================
# Admin Views
# ============================================================

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def admin_stats(request):
    """Admin dashboard stats."""
    if not is_admin(request.user):
        return Response({"success": False, "message": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

    total_users = User.objects.filter(role='user').count()
    total_agents = User.objects.filter(role='agent').count()
    total_scans = ScanHistory.objects.count()
    total_bookings = Booking.objects.count()
    pending_bookings = Booking.objects.filter(status='pending').count()
    completed_bookings = Booking.objects.filter(status='completed').count()
    paid_bookings = Booking.objects.filter(is_paid=True).count()
    pending_agents = AgentProfile.objects.filter(is_approved=False).count()

    return Response({
        "success": True,
        "data": {
            "total_users": total_users,
            "total_agents": total_agents,
            "total_scans": total_scans,
            "total_bookings": total_bookings,
            "pending_bookings": pending_bookings,
            "completed_bookings": completed_bookings,
            "paid_bookings": paid_bookings,
            "pending_agents": pending_agents,
        }
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def admin_users(request):
    """Admin: list all users."""
    if not is_admin(request.user):
        return Response({"success": False, "message": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

    role_filter = request.query_params.get('role')
    users = User.objects.all()
    if role_filter:
        users = users.filter(role=role_filter)
    serializer = AdminUserSerializer(users, many=True)
    return Response({"success": True, "data": serializer.data})


@api_view(["PUT"])
@permission_classes([IsAuthenticated])
def admin_user_role(request, user_id):
    """Admin: update user role."""
    if not is_admin(request.user):
        return Response({"success": False, "message": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"success": False, "message": "User not found."}, status=status.HTTP_404_NOT_FOUND)

    new_role = request.data.get('role')
    if new_role not in ['user', 'agent', 'admin']:
        return Response({"success": False, "message": "Invalid role."}, status=status.HTTP_400_BAD_REQUEST)

    user.role = new_role
    user.save()

    if new_role == 'agent' and not hasattr(user, 'agent_profile'):
        AgentProfile.objects.create(user=user, is_approved=True)

    return Response({
        "success": True,
        "message": f"User role updated to {new_role}.",
        "data": AdminUserSerializer(user).data,
    })


@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
def admin_delete_user(request, user_id):
    """Admin: delete a user account."""
    if not is_admin(request.user):
        return Response({"success": False, "message": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

    if request.user.id == user_id:
        return Response({"success": False, "message": "You cannot delete your own account."}, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = User.objects.get(id=user_id)
    except User.DoesNotExist:
        return Response({"success": False, "message": "User not found."}, status=status.HTTP_404_NOT_FOUND)

    user.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def admin_agents(request):
    """Admin: list all agent profiles."""
    if not is_admin(request.user):
        return Response({"success": False, "message": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

    agents = AgentProfile.objects.select_related('user').all()
    serializer = AgentProfileSerializer(agents, many=True)
    return Response({"success": True, "data": serializer.data})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def admin_create_agent(request):
    """Admin: directly create a new agent user + approve them."""
    if not is_admin(request.user):
        return Response({"success": False, "message": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

    username = request.data.get('username', '').strip()
    email = request.data.get('email', '').strip()
    first_name = request.data.get('first_name', '').strip()
    last_name = request.data.get('last_name', '').strip()
    phone_number = request.data.get('phone_number', '').strip()
    password = request.data.get('password', '').strip()

    if not username or not password:
        return Response({"success": False, "message": "Username and password are required."}, status=status.HTTP_400_BAD_REQUEST)

    if User.objects.filter(username=username).exists():
        return Response({"success": False, "message": "Username already taken."}, status=status.HTTP_400_BAD_REQUEST)

    if email and User.objects.filter(email=email).exists():
        return Response({"success": False, "message": "Email already registered."}, status=status.HTTP_400_BAD_REQUEST)

    user = User(
        username=username,
        email=email,
        first_name=first_name,
        last_name=last_name,
        phone_number=phone_number,
        role='agent',
    )
    user.set_password(password)
    user.save()

    agent_profile = AgentProfile.objects.create(
        user=user,
        is_approved=True,  # Admin-created agents are auto-approved
    )

    return Response({
        "success": True,
        "message": f"Agent '{username}' created and approved.",
        "data": AgentProfileSerializer(agent_profile).data,
    }, status=status.HTTP_201_CREATED)


@api_view(["PUT"])
@permission_classes([IsAuthenticated])
def admin_agent_approve(request, agent_id):
    """Admin: approve or suspend an agent."""
    if not is_admin(request.user):
        return Response({"success": False, "message": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

    try:
        agent_profile = AgentProfile.objects.get(id=agent_id)
    except AgentProfile.DoesNotExist:
        return Response({"success": False, "message": "Agent not found."}, status=status.HTTP_404_NOT_FOUND)

    is_approved = request.data.get('is_approved')
    if is_approved is not None:
        agent_profile.is_approved = bool(is_approved)
        agent_profile.save()

    return Response({
        "success": True,
        "message": "Agent updated.",
        "data": AgentProfileSerializer(agent_profile).data,
    })


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def admin_scans(request):
    """Admin: list all scans."""
    if not is_admin(request.user):
        return Response({"success": False, "message": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

    scans = ScanHistory.objects.select_related('user').all()
    serializer = ScanHistoryAdminSerializer(scans, many=True, context={"request": request})
    return Response({"success": True, "data": serializer.data})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def admin_bookings(request):
    """Admin: list all bookings."""
    if not is_admin(request.user):
        return Response({"success": False, "message": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

    status_filter = request.query_params.get('status')
    bookings = Booking.objects.select_related('user', 'agent').all()
    if status_filter:
        bookings = bookings.filter(status=status_filter)
    serializer = BookingSerializer(bookings, many=True)
    return Response({"success": True, "data": serializer.data})

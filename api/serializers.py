from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import User, ScanHistory, ServiceCenter, Vehicle, ServiceRecord, AgentProfile, Booking, ChargeSheet


class UserRegistrationSerializer(serializers.ModelSerializer):
    """Serializer for user registration. Role is always 'user' — agents are assigned by admin."""
    password = serializers.CharField(write_only=True, min_length=6)
    confirm_password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = User
        fields = ["id", "username", "email", "first_name", "last_name",
                  "phone_number", "password", "confirm_password"]

    def validate(self, data):
        if data["password"] != data["confirm_password"]:
            raise serializers.ValidationError({"confirm_password": "Passwords do not match."})
        if User.objects.filter(email=data.get("email", "")).exists():
            raise serializers.ValidationError({"email": "Email already registered."})
        return data

    def create(self, validated_data):
        validated_data.pop("confirm_password")
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.role = 'user'  # Always user on self-registration
        user.set_password(password)
        user.save()
        return user


class UserLoginSerializer(serializers.Serializer):
    """Serializer for user login."""
    username = serializers.CharField()
    password = serializers.CharField()

    def validate(self, data):
        user = authenticate(username=data["username"], password=data["password"])
        if user is None:
            # Try with email
            try:
                user_obj = User.objects.get(email=data["username"])
                user = authenticate(username=user_obj.username, password=data["password"])
            except User.DoesNotExist:
                pass
        if user is None:
            raise serializers.ValidationError("Invalid credentials.")
        if not user.is_active:
            raise serializers.ValidationError("User account is disabled.")
        data["user"] = user
        return data


class UserProfileSerializer(serializers.ModelSerializer):
    """Serializer for user profile."""
    total_scans = serializers.ReadOnlyField()

    class Meta:
        model = User
        fields = ["id", "username", "email", "first_name", "last_name",
                  "phone_number", "role", "total_scans", "date_joined"]
        read_only_fields = ["id", "username", "date_joined", "role"]


class AgentProfileSerializer(serializers.ModelSerializer):
    """Serializer for agent profile details."""
    username = serializers.CharField(source='user.username', read_only=True)
    full_name = serializers.SerializerMethodField()
    email = serializers.CharField(source='user.email', read_only=True)
    phone_number = serializers.CharField(source='user.phone_number', read_only=True)
    user_id = serializers.IntegerField(source='user.id', read_only=True)

    class Meta:
        model = AgentProfile
        fields = ['id', 'user_id', 'username', 'full_name', 'email', 'phone_number',
                  'is_available', 'rating', 'total_completed', 'is_approved', 'created_at']
        read_only_fields = ['id', 'user_id', 'username', 'full_name', 'email',
                            'phone_number', 'rating', 'total_completed', 'created_at']

    def get_full_name(self, obj):
        return f"{obj.user.first_name} {obj.user.last_name}".strip() or obj.user.username


class ServiceCenterSerializer(serializers.ModelSerializer):
    """Serializer for service centers."""
    class Meta:
        model = ServiceCenter
        fields = ["id", "name", "address", "phone_number", "rating",
                  "total_reviews", "distance", "latitude", "longitude",
                  "place_id", "opening_hours", "services_offered", "photo_url"]


class ScanHistorySerializer(serializers.ModelSerializer):
    """Serializer for scan history."""
    service_centers = ServiceCenterSerializer(many=True, read_only=True)

    class Meta:
        model = ScanHistory
        fields = ["id", "image", "description", "detected_issue",
                  "problem_explanation", "possible_causes", "urgency_level",
                  "confidence_score", "recommended_service_type",
                  "is_analyzed", "created_at", "service_centers"]
        read_only_fields = ["detected_issue", "problem_explanation",
                           "possible_causes", "urgency_level",
                           "confidence_score", "recommended_service_type",
                           "is_analyzed", "created_at"]


class ScanHistoryAdminSerializer(serializers.ModelSerializer):
    """Scan history serializer for admin with user info."""
    username = serializers.CharField(source='user.username', read_only=True)
    service_centers = ServiceCenterSerializer(many=True, read_only=True)

    class Meta:
        model = ScanHistory
        fields = ["id", "username", "image", "description", "detected_issue",
                  "urgency_level", "confidence_score", "recommended_service_type",
                  "is_analyzed", "created_at", "service_centers"]


class ScanUploadSerializer(serializers.ModelSerializer):
    """Serializer for uploading scan images."""
    class Meta:
        model = ScanHistory
        fields = ["image", "description"]


# ============================================================
# Garage Serializers
# ============================================================

class ServiceRecordSerializer(serializers.ModelSerializer):
    """Serializer for a single service record."""
    class Meta:
        model = ServiceRecord
        fields = [
            "id", "service_name", "description", "cost", "service_date",
            "mileage", "service_center_name", "bill_image", "notes",
            "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class VehicleSerializer(serializers.ModelSerializer):
    """Serializer for vehicle list/create."""
    total_service_records = serializers.ReadOnlyField()
    total_service_cost = serializers.ReadOnlyField()

    class Meta:
        model = Vehicle
        fields = [
            "id", "make", "model", "year", "color", "license_plate", "vin",
            "total_service_records", "total_service_cost", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


# ============================================================
# Booking Serializers
# ============================================================

class BookingSerializer(serializers.ModelSerializer):
    """Serializer for bookings."""
    user_name = serializers.CharField(source='user.username', read_only=True)
    agent_name = serializers.SerializerMethodField()
    has_charge_sheet = serializers.SerializerMethodField()
    charge_sheet_total = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = [
            'id', 'user_name', 'agent_name',
            'contact_name', 'contact_phone', 'contact_address',
            'detected_issue', 'description',
            'vehicle_make', 'vehicle_model_name', 'vehicle_year',
            'service_center_name', 'service_center_address',
            'service_center_phone', 'service_center_lat', 'service_center_lng',
            'status', 'accepted_at', 'completed_at',
            'is_paid', 'payment_id', 'razorpay_order_id',
            'has_charge_sheet', 'charge_sheet_total',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'user_name', 'agent_name', 'accepted_at',
                            'completed_at', 'is_paid', 'payment_id',
                            'razorpay_order_id', 'created_at', 'updated_at']

    def get_agent_name(self, obj):
        if obj.agent:
            return f"{obj.agent.first_name} {obj.agent.last_name}".strip() or obj.agent.username
        return None

    def get_has_charge_sheet(self, obj):
        return hasattr(obj, 'charge_sheet')

    def get_charge_sheet_total(self, obj):
        if hasattr(obj, 'charge_sheet'):
            return float(obj.charge_sheet.total_amount)
        return None


class BookingCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating a booking."""
    scan_id = serializers.IntegerField(required=False, allow_null=True, write_only=True)

    class Meta:
        model = Booking
        fields = [
            'scan_id',
            'contact_name', 'contact_phone', 'contact_address',
            'detected_issue', 'description',
            'vehicle_make', 'vehicle_model_name', 'vehicle_year',
            'service_center_name', 'service_center_address',
            'service_center_phone', 'service_center_lat', 'service_center_lng',
        ]

    def create(self, validated_data):
        scan_id = validated_data.pop('scan_id', None)
        scan = None
        if scan_id:
            try:
                scan = ScanHistory.objects.get(id=scan_id)
            except ScanHistory.DoesNotExist:
                pass
        return Booking.objects.create(scan=scan, **validated_data)


class ChargeSheetSerializer(serializers.ModelSerializer):
    """Serializer for charge sheets."""
    booking_id = serializers.IntegerField(source='booking.id', read_only=True)

    class Meta:
        model = ChargeSheet
        fields = ['id', 'booking_id', 'items', 'subtotal', 'tax', 'total_amount',
                  'notes', 'razorpay_order_id', 'created_at', 'updated_at']
        read_only_fields = ['id', 'booking_id', 'razorpay_order_id', 'created_at', 'updated_at']


class ChargeSheetCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating/updating a charge sheet."""
    booking_id = serializers.IntegerField(write_only=True)

    class Meta:
        model = ChargeSheet
        fields = ['booking_id', 'items', 'tax', 'notes']

    def validate_items(self, items):
        if not isinstance(items, list):
            raise serializers.ValidationError("Items must be a list.")
        for item in items:
            if 'name' not in item or 'amount' not in item:
                raise serializers.ValidationError("Each item must have 'name' and 'amount'.")
        return items

    def create(self, validated_data):
        booking_id = validated_data.pop('booking_id')
        booking = Booking.objects.get(id=booking_id)
        items = validated_data.get('items', [])
        tax = validated_data.get('tax', 0)
        subtotal = sum(float(item.get('amount', 0)) for item in items)
        total = subtotal + float(tax)
        return ChargeSheet.objects.create(
            booking=booking,
            subtotal=subtotal,
            total_amount=total,
            **validated_data,
        )

    def update(self, instance, validated_data):
        validated_data.pop('booking_id', None)
        items = validated_data.get('items', instance.items)
        tax = validated_data.get('tax', instance.tax)
        subtotal = sum(float(item.get('amount', 0)) for item in items)
        total = subtotal + float(tax)
        instance.items = items
        instance.tax = tax
        instance.subtotal = subtotal
        instance.total_amount = total
        instance.notes = validated_data.get('notes', instance.notes)
        instance.save()
        return instance


# ============================================================
# Admin Serializers
# ============================================================

class AdminUserSerializer(serializers.ModelSerializer):
    """Serializer for admin user management."""
    total_scans = serializers.ReadOnlyField()
    total_bookings = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name',
                  'phone_number', 'role', 'is_active', 'total_scans',
                  'total_bookings', 'date_joined']
        read_only_fields = ['id', 'username', 'email', 'total_scans',
                            'total_bookings', 'date_joined']

    def get_total_bookings(self, obj):
        return obj.bookings.count()

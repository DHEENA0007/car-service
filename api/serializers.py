from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import User, ScanHistory, ServiceCenter, Vehicle, ServiceRecord


class UserRegistrationSerializer(serializers.ModelSerializer):
    """Serializer for user registration."""
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
                  "phone_number", "total_scans", "date_joined"]
        read_only_fields = ["id", "username", "date_joined"]


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

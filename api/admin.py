from django.contrib import admin
from .models import User, ScanHistory, ServiceCenter


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ["username", "email", "phone_number", "total_scans", "date_joined"]
    search_fields = ["username", "email", "phone_number"]


@admin.register(ScanHistory)
class ScanHistoryAdmin(admin.ModelAdmin):
    list_display = ["user", "detected_issue", "urgency_level", "confidence_score", "is_analyzed", "created_at"]
    list_filter = ["urgency_level", "is_analyzed", "created_at"]
    search_fields = ["detected_issue", "problem_explanation"]


@admin.register(ServiceCenter)
class ServiceCenterAdmin(admin.ModelAdmin):
    list_display = ["name", "rating", "total_reviews", "distance", "phone_number"]
    list_filter = ["rating"]
    search_fields = ["name", "address"]

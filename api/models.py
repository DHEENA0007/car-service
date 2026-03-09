from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """Custom user model with additional fields for the car service app."""
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    profile_picture = models.ImageField(upload_to="profiles/", blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.email or self.username

    @property
    def total_scans(self):
        return self.scans.count()


class ScanHistory(models.Model):
    """Stores each vehicle issue scan performed by users."""
    URGENCY_CHOICES = [
        ("low", "Low Priority"),
        ("medium", "Medium Priority"),
        ("high", "High Priority"),
        ("critical", "Critical - Immediate Action Required"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="scans")
    image = models.ImageField(upload_to="scans/")
    description = models.TextField(blank=True, null=True, help_text="Optional user description")

    # AI Analysis Results
    detected_issue = models.CharField(max_length=255, blank=True, null=True)
    problem_explanation = models.TextField(blank=True, null=True)
    possible_causes = models.TextField(blank=True, null=True)
    urgency_level = models.CharField(max_length=20, choices=URGENCY_CHOICES, blank=True, null=True)
    confidence_score = models.FloatField(blank=True, null=True)
    recommended_service_type = models.CharField(max_length=255, blank=True, null=True)

    # AI raw response
    ai_raw_response = models.TextField(blank=True, null=True)

    # Status
    is_analyzed = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name_plural = "Scan Histories"

    def __str__(self):
        return f"Scan by {self.user.username} - {self.detected_issue or 'Pending'}"


class ServiceCenter(models.Model):
    """Stores recommended service centers for each scan."""
    scan = models.ForeignKey(ScanHistory, on_delete=models.CASCADE, related_name="service_centers")

    name = models.CharField(max_length=255)
    address = models.TextField()
    phone_number = models.CharField(max_length=50, blank=True, null=True)
    rating = models.FloatField(default=0.0)
    total_reviews = models.IntegerField(default=0)
    distance = models.CharField(max_length=50, blank=True, null=True)
    latitude = models.FloatField(blank=True, null=True)
    longitude = models.FloatField(blank=True, null=True)
    place_id = models.CharField(max_length=255, blank=True, null=True)
    opening_hours = models.TextField(blank=True, null=True)
    services_offered = models.TextField(blank=True, null=True)
    photo_url = models.URLField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-rating", "distance"]

    def __str__(self):
        return f"{self.name} - Rating: {self.rating}"

from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """Custom user model with role-based access for users, agents, and admins."""
    ROLE_CHOICES = [
        ('user', 'User'),
        ('agent', 'Agent'),
        ('admin', 'Admin'),
    ]
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='user')
    phone_number = models.CharField(max_length=20, blank=True, null=True)
    profile_picture = models.ImageField(upload_to="profiles/", blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.email or self.username

    @property
    def total_scans(self):
        return self.scans.count()


class AgentProfile(models.Model):
    """Extended profile for agents."""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='agent_profile')
    is_available = models.BooleanField(default=True)
    rating = models.FloatField(default=0.0)
    total_completed = models.IntegerField(default=0)
    is_approved = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Agent: {self.user.username}"


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


class Vehicle(models.Model):
    """A vehicle owned by the user."""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="vehicles")
    make = models.CharField(max_length=100)
    model = models.CharField(max_length=100)
    year = models.IntegerField()
    color = models.CharField(max_length=50, blank=True, null=True)
    license_plate = models.CharField(max_length=20, blank=True, null=True)
    vin = models.CharField(max_length=50, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.year} {self.make} {self.model} ({self.user.username})"

    @property
    def total_service_records(self):
        return self.service_records.count()

    @property
    def total_service_cost(self):
        from django.db.models import Sum
        result = self.service_records.aggregate(total=Sum("cost"))["total"]
        return float(result) if result else 0.0


class ServiceRecord(models.Model):
    """A service/maintenance record for a vehicle."""
    vehicle = models.ForeignKey(Vehicle, on_delete=models.CASCADE, related_name="service_records")
    service_name = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    cost = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    service_date = models.DateField()
    mileage = models.IntegerField(blank=True, null=True)
    service_center_name = models.CharField(max_length=255, blank=True, null=True)
    bill_image = models.ImageField(upload_to="bills/", blank=True, null=True)
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-service_date"]

    def __str__(self):
        return f"{self.service_name} – {self.vehicle}"


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


class Booking(models.Model):
    """A service booking created by a user, fulfilled by an agent."""
    STATUS_CHOICES = [
        ('pending', 'Pending - Waiting for agent'),
        ('accepted', 'Accepted - Agent picked up'),
        ('in_progress', 'In Progress - Service ongoing'),
        ('completed', 'Completed - Service done'),
        ('cancelled', 'Cancelled'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='bookings')
    agent = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name='agent_bookings'
    )
    scan = models.ForeignKey(ScanHistory, on_delete=models.SET_NULL, null=True, blank=True)

    # Contact details
    contact_name = models.CharField(max_length=255)
    contact_phone = models.CharField(max_length=20)
    contact_address = models.TextField(blank=True)

    # Issue details
    detected_issue = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True)
    vehicle_make = models.CharField(max_length=100, blank=True)
    vehicle_model_name = models.CharField(max_length=100, blank=True)
    vehicle_year = models.IntegerField(null=True, blank=True)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    accepted_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    # Selected service center details
    service_center_name = models.CharField(max_length=255, blank=True)
    service_center_address = models.TextField(blank=True)
    service_center_phone = models.CharField(max_length=50, blank=True)
    service_center_lat = models.FloatField(null=True, blank=True)
    service_center_lng = models.FloatField(null=True, blank=True)

    # Payment
    is_paid = models.BooleanField(default=False)
    payment_id = models.CharField(max_length=255, blank=True)
    razorpay_order_id = models.CharField(max_length=255, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Booking #{self.id} by {self.user.username} - {self.status}"


class ChargeSheet(models.Model):
    """Bill/charge sheet created by agent for a booking."""
    booking = models.OneToOneField(Booking, on_delete=models.CASCADE, related_name='charge_sheet')
    items = models.JSONField(default=list)  # [{"name": "Labor", "amount": 500.0}, ...]
    subtotal = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    tax = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    notes = models.TextField(blank=True)
    razorpay_order_id = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"ChargeSheet for Booking #{self.booking.id} - ₹{self.total_amount}"

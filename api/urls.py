from django.urls import path
from . import views

urlpatterns = [
    # Authentication
    path("auth/register/", views.register, name="register"),
    path("auth/login/", views.login, name="login"),
    path("auth/logout/", views.logout, name="logout"),

    # Profile
    path("auth/profile/", views.profile, name="profile"),

    # Scan / AI Analysis
    path("scan/analyze/", views.analyze_image, name="analyze_image"),
    path("scan/history/", views.scan_history, name="scan_history"),
    path("scan/<int:scan_id>/", views.scan_detail, name="scan_detail"),
    path("scan/<int:scan_id>/delete/", views.delete_scan, name="delete_scan"),

    # Service Centers
    path("scan/<int:scan_id>/service-centers/", views.service_centers, name="service_centers"),
]

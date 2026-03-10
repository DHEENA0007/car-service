from django.urls import path
from . import views

urlpatterns = [
    # Authentication
    path("auth/register/", views.register, name="register"),
    path("auth/login/", views.login, name="login"),
    path("auth/logout/", views.logout, name="logout"),
    path("auth/forgot-password/", views.forgot_password, name="forgot_password"),

    # Profile
    path("auth/profile/", views.profile, name="profile"),

    # Scan / AI Analysis
    path("scan/analyze/", views.analyze_image, name="analyze_image"),
    path("scan/history/", views.scan_history, name="scan_history"),
    path("scan/<int:scan_id>/", views.scan_detail, name="scan_detail"),
    path("scan/<int:scan_id>/delete/", views.delete_scan, name="delete_scan"),

    # Service Centers
    path("scan/<int:scan_id>/service-centers/", views.service_centers, name="service_centers"),

    # Mappls Place Detail (phone + coordinates by eLoc)
    path("place-detail/<str:eloc>/", views.place_detail, name="place_detail"),

    # Mappls Reverse Geocoding (?lat=&lng=)
    path("reverse-geocode/", views.reverse_geocode_view, name="reverse_geocode"),

    # Mappls Route Directions (?origin_lat=&origin_lng=&eloc= or &dest_lat=&dest_lng=)
    path("route/", views.route_directions, name="route_directions"),

    # Garage – Vehicles
    path("garage/vehicles/", views.vehicle_list, name="vehicle_list"),
    path("garage/vehicles/<int:vehicle_id>/", views.vehicle_detail, name="vehicle_detail"),

    # Garage – Service Records
    path("garage/vehicles/<int:vehicle_id>/records/", views.service_record_list, name="service_record_list"),
    path("garage/vehicles/<int:vehicle_id>/records/<int:record_id>/", views.service_record_detail, name="service_record_detail"),
]

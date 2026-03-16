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

    # Mappls Place Detail
    path("place-detail/<str:eloc>/", views.place_detail, name="place_detail"),

    # Mappls Reverse Geocoding (?lat=&lng=)
    path("reverse-geocode/", views.reverse_geocode_view, name="reverse_geocode"),

    # Mappls Route Directions
    path("route/", views.route_directions, name="route_directions"),

    # Garage – Vehicles
    path("garage/vehicles/", views.vehicle_list, name="vehicle_list"),
    path("garage/vehicles/<int:vehicle_id>/", views.vehicle_detail, name="vehicle_detail"),

    # Garage – Service Records
    path("garage/vehicles/<int:vehicle_id>/records/", views.service_record_list, name="service_record_list"),
    path("garage/vehicles/<int:vehicle_id>/records/<int:record_id>/", views.service_record_detail, name="service_record_detail"),

    # Bookings (User creates, Agent picks up)
    path("bookings/", views.booking_list, name="booking_list"),
    path("bookings/available/", views.booking_available, name="booking_available"),
    path("bookings/<int:booking_id>/", views.booking_detail, name="booking_detail"),
    path("bookings/<int:booking_id>/accept/", views.booking_accept, name="booking_accept"),
    path("bookings/<int:booking_id>/status/", views.booking_update_status, name="booking_update_status"),

    # Charge Sheets
    path("charge-sheets/", views.charge_sheet_create, name="charge_sheet_create"),
    path("charge-sheets/<int:booking_id>/", views.charge_sheet_detail, name="charge_sheet_detail"),

    # Payments (Razorpay)
    path("payments/create-order/", views.payment_create_order, name="payment_create_order"),
    path("payments/verify/", views.payment_verify, name="payment_verify"),

    # Admin
    path("admin/stats/", views.admin_stats, name="admin_stats"),
    path("admin/users/", views.admin_users, name="admin_users"),
    path("admin/users/<int:user_id>/role/", views.admin_user_role, name="admin_user_role"),
    path("admin/users/<int:user_id>/delete/", views.admin_delete_user, name="admin_delete_user"),
    path("admin/agents/", views.admin_agents, name="admin_agents"),
    path("admin/agents/create/", views.admin_create_agent, name="admin_create_agent"),
    path("admin/agents/<int:agent_id>/approve/", views.admin_agent_approve, name="admin_agent_approve"),
    path("admin/scans/", views.admin_scans, name="admin_scans"),
    path("admin/bookings/", views.admin_bookings, name="admin_bookings"),
]

class BookingModel {
  final int id;
  final String userName;
  final String? agentName;
  final String contactName;
  final String contactPhone;
  final String contactAddress;
  final String detectedIssue;
  final String description;
  final String vehicleMake;
  final String vehicleModelName;
  final int? vehicleYear;
  final String serviceCenterName;
  final String serviceCenterAddress;
  final String serviceCenterPhone;
  final double? serviceCenterLat;
  final double? serviceCenterLng;
  final String status;
  final String? acceptedAt;
  final String? completedAt;
  final bool isPaid;
  final String? paymentId;
  final String? razorpayOrderId;
  final bool hasChargeSheet;
  final double? chargeSheetTotal;
  final String createdAt;

  BookingModel({
    required this.id,
    required this.userName,
    this.agentName,
    required this.contactName,
    required this.contactPhone,
    this.contactAddress = '',
    this.detectedIssue = '',
    this.description = '',
    this.vehicleMake = '',
    this.vehicleModelName = '',
    this.vehicleYear,
    this.serviceCenterName = '',
    this.serviceCenterAddress = '',
    this.serviceCenterPhone = '',
    this.serviceCenterLat,
    this.serviceCenterLng,
    required this.status,
    this.acceptedAt,
    this.completedAt,
    this.isPaid = false,
    this.paymentId,
    this.razorpayOrderId,
    this.hasChargeSheet = false,
    this.chargeSheetTotal,
    required this.createdAt,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] ?? 0,
      userName: map['user_name'] ?? '',
      agentName: map['agent_name'],
      contactName: map['contact_name'] ?? '',
      contactPhone: map['contact_phone'] ?? '',
      contactAddress: map['contact_address'] ?? '',
      detectedIssue: map['detected_issue'] ?? '',
      description: map['description'] ?? '',
      vehicleMake: map['vehicle_make'] ?? '',
      vehicleModelName: map['vehicle_model_name'] ?? '',
      vehicleYear: map['vehicle_year'],
      serviceCenterName: map['service_center_name'] ?? '',
      serviceCenterAddress: map['service_center_address'] ?? '',
      serviceCenterPhone: map['service_center_phone'] ?? '',
      serviceCenterLat: (map['service_center_lat'] as num?)?.toDouble(),
      serviceCenterLng: (map['service_center_lng'] as num?)?.toDouble(),
      status: map['status'] ?? 'pending',
      acceptedAt: map['accepted_at'],
      completedAt: map['completed_at'],
      isPaid: map['is_paid'] ?? false,
      paymentId: map['payment_id'],
      razorpayOrderId: map['razorpay_order_id'],
      hasChargeSheet: map['has_charge_sheet'] ?? false,
      chargeSheetTotal: map['charge_sheet_total'] != null
          ? (map['charge_sheet_total'] as num).toDouble()
          : null,
      createdAt: map['created_at'] ?? '',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Waiting for Agent';
      case 'accepted': return 'Agent Assigned';
      case 'in_progress': return 'Service in Progress';
      case 'completed': return 'Service Completed';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  String get statusEmoji {
    switch (status) {
      case 'pending': return '⏳';
      case 'accepted': return '✅';
      case 'in_progress': return '🔧';
      case 'completed': return '🎉';
      case 'cancelled': return '❌';
      default: return '•';
    }
  }

  String get dateString {
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }
}

class ChargeItemModel {
  final String name;
  final double amount;

  ChargeItemModel({required this.name, required this.amount});

  factory ChargeItemModel.fromMap(Map<String, dynamic> map) {
    return ChargeItemModel(
      name: map['name'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};
}

class ChargeSheetModel {
  final int id;
  final int bookingId;
  final List<ChargeItemModel> items;
  final double subtotal;
  final double tax;
  final double totalAmount;
  final String notes;
  final String? razorpayOrderId;
  final String createdAt;

  ChargeSheetModel({
    required this.id,
    required this.bookingId,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.totalAmount,
    this.notes = '',
    this.razorpayOrderId,
    required this.createdAt,
  });

  factory ChargeSheetModel.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List? ?? [];
    return ChargeSheetModel(
      id: map['id'] ?? 0,
      bookingId: map['booking_id'] ?? 0,
      items: rawItems.map((i) => ChargeItemModel.fromMap(i as Map<String, dynamic>)).toList(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (map['tax'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] ?? '',
      razorpayOrderId: map['razorpay_order_id'],
      createdAt: map['created_at'] ?? '',
    );
  }
}

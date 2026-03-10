class ServiceCenterModel {
  final int? id;
  final String name;
  final String address;
  final String? phoneNumber;
  final double rating;
  final int totalReviews;
  final String? distance;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? openingHours;
  final String? servicesOffered;
  final String? photoUrl;

  const ServiceCenterModel({
    this.id,
    required this.name,
    required this.address,
    this.phoneNumber,
    required this.rating,
    required this.totalReviews,
    this.distance,
    this.latitude,
    this.longitude,
    this.placeId,
    this.openingHours,
    this.servicesOffered,
    this.photoUrl,
  });

  factory ServiceCenterModel.fromMap(Map<String, dynamic> map) {
    return ServiceCenterModel(
      id: map['id'],
      name: map['name'] ?? 'Service Center',
      address: map['address'] ?? '',
      phoneNumber: map['phone_number'],
      rating: (map['rating'] ?? 0).toDouble(),
      totalReviews: map['total_reviews'] ?? 0,
      distance: map['distance'],
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      placeId: map['place_id'],
      openingHours: map['opening_hours'],
      servicesOffered: map['services_offered'],
      photoUrl: map['photo_url'],
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'phone_number': phoneNumber,
        'rating': rating,
        'total_reviews': totalReviews,
        'distance': distance,
        'latitude': latitude,
        'longitude': longitude,
        'place_id': placeId,
        'opening_hours': openingHours,
        'services_offered': servicesOffered,
        'photo_url': photoUrl,
      };
}

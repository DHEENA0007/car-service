class UserModel {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final int totalScans;
  final String dateJoined;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    required this.totalScans,
    required this.dateJoined,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials => fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? 0,
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      phoneNumber: map['phone_number'],
      totalScans: map['total_scans'] ?? 0,
      dateJoined: map['date_joined'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone_number': phoneNumber,
        'total_scans': totalScans,
        'date_joined': dateJoined,
      };
}

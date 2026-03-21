import 'package:cloud_firestore/cloud_firestore.dart';

class NGO {
  final String id;
  final String name;
  final String description;
  final String? logoUrl;
  final String? coverImageUrl;
  final String email;
  final String phone;
  final String? website;
  final String address;
  final Map<String, String> socialLinks;
  final String registrationNumber;
  final bool isVerified;
  final String ownerId;
  final List<String> followers;
  final List<String> members;
  final List<String> bookmarkedCampaignsIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  NGO({
    required this.id,
    required this.name,
    required this.description,
    this.logoUrl,
    this.coverImageUrl,
    required this.email,
    required this.phone,
    this.website,
    required this.address,
    required this.socialLinks,
    required this.registrationNumber,
    this.isVerified = false,
    required this.ownerId,
    required this.followers,
    this.members = const [],
    this.bookmarkedCampaignsIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory NGO.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return NGO(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      logoUrl: data['logoUrl'],
      coverImageUrl: data['coverImageUrl'],
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      website: data['website'],
      address: data['address'] ?? '',
      socialLinks: Map<String, String>.from(data['socialLinks'] ?? {}),
      registrationNumber: data['registrationNumber'] ?? '',
      isVerified: data['isVerified'] ?? false,
      ownerId: data['ownerId'] ?? '',
      followers: List<String>.from(data['followers'] ?? []),
      members: List<String>.from(data['members'] ?? []),
      bookmarkedCampaignsIds: List<String>.from(data['bookmarkedCampaignsIds'] ?? []),
      createdAt: (data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now()),
      updatedAt: (data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now()),
    );
  }
}

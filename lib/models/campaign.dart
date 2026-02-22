import 'package:cloud_firestore/cloud_firestore.dart';

class Campaign {
  final String id;
  final String organizerId;

  // Basic info
  final String title;
  final String description;

  // Location related fields
  // Automatically filled upon choosing a location on the map
  final String location;
  final double latitude;
  final double longitude;

  final String instructions; // Not required
  final int requiredVolunteers;
  final DateTime startDate;
  final DateTime endDate;
  final String imageUrl; // Optional image upload

  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> categories;
  final List<String> registeredVolunteersUids;
  final String status; // "active" by default

  Campaign({
    required this.id,
    required this.organizerId, 
    required this.title,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.requiredVolunteers,
    required this.startDate,
    required this.endDate,
    required this.imageUrl, 
    required this.createdAt,
    required this.updatedAt,
    required this.categories,
    this.instructions = '',
    this.registeredVolunteersUids = const [],
    this.status = 'active',
  });

  bool get isActive => status == 'active';

  factory Campaign.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Campaign(
      id: doc.id,
      organizerId: data['organizerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      latitude: (data['latitude'] ?? 43.217152).toDouble(), 
      longitude: (data['longitude'] ?? 27.939351).toDouble(),
      instructions: data['instructions'] ?? '',
      requiredVolunteers: data['requiredVolunteers'] ?? 0,
      startDate: data['startDate'] != null ? (data['startDate'] as Timestamp).toDate() : DateTime.now(),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : DateTime.now().add(Duration(hours: 2)),
      imageUrl: data['imageUrl'] ?? '',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now().subtract(Duration(days: 1)),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now(),
      categories: List<String>.from(data['categories'] ?? const []),
      registeredVolunteersUids: List<String>.from(data['registeredVolunteersUids'] ?? const []),
      status: data['status'] ?? 'active',
    );
  }

  // Method to get the duration of the campaign in hours
  int get durationInHours {
    final Duration duration = endDate.difference(startDate);
    return duration.inHours; 
  }
}
  
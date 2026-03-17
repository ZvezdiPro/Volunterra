import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerUser {

  // Required fields
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final List<String> interests;

  // Optional fields
  final String? bio;
  final String? avatarUrl;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;

  // Automatically created
  final int experiencePoints;
  final int userLevel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> bookmarkedCampaignsIds;

  // Constructor for temporary test and authentication
  VolunteerUser.forAuth({required this.uid})
    : email = '',
      firstName = '',
      lastName = '',
      interests = const [],
      experiencePoints = 0,
      userLevel = 1,
      createdAt = DateTime.now(),
      updatedAt = DateTime.now(),
      bio = null,
      avatarUrl = null,
      phoneNumber = null,
      dateOfBirth = null,
      lastKnownLatitude = null,
      lastKnownLongitude = null,
      bookmarkedCampaignsIds = const [];

  // Full Constructor
  VolunteerUser({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.interests, 
    this.experiencePoints = 0,
    this.userLevel = 1,
    required this.createdAt,
    required this.updatedAt,
    this.bio,
    this.avatarUrl,
    this.phoneNumber,
    this.dateOfBirth,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
    this.bookmarkedCampaignsIds = const [],
  });

  // Factory constructor to create a VolunteerUser from Firestore document
  factory VolunteerUser.fromFirestore(DocumentSnapshot doc) {
    // Get the data from the document as a map of kvpairs
    final Map data = doc.data() as Map<String, dynamic>;
    return VolunteerUser(
      uid: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      interests: List<String>.from(data['interests'] ?? []),
      experiencePoints: data['experiencePoints'] ?? 0,
      userLevel: data['userLevel'] ?? 1,
      createdAt: (data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now()),
      updatedAt: (data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now()),
      bio: data['bio'],
      avatarUrl: data['avatarUrl'],
      phoneNumber: data['phoneNumber'],
      dateOfBirth: data['dateOfBirth'] != null ? (data['dateOfBirth'] as Timestamp).toDate() : null,
      lastKnownLatitude: (data['lastKnownLatitude'] as num?)?.toDouble(),
      lastKnownLongitude: (data['lastKnownLongitude'] as num?)?.toDouble(),
      bookmarkedCampaignsIds: List<String>.from(data['bookmarkedCampaignsIds'] ?? []),
    );
  }
}
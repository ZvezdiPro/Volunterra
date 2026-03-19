import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/registration_data.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/models/campaign_data.dart';

class DatabaseService {
  final String? uid;
  DatabaseService({this.uid});

  final CollectionReference volunteerCollection = FirebaseFirestore.instance.collection('volunteers');
  final CollectionReference campaignCollection = FirebaseFirestore.instance.collection('campaigns');

  Future<void> updateUserData(
    RegistrationData data, {
    bool isOAuthLogin = false,
  }) async {
    final docRef = volunteerCollection.doc(uid);
    final documentSnapshot = await docRef.get();

    // If the doc exists and it's a Google/Facebook login, we check if the email is verified
    if (documentSnapshot.exists && isOAuthLogin) {
      bool isEmailVerified = true;
      final docData = documentSnapshot.data() as Map<String, dynamic>?;
      if (docData != null && docData.containsKey('isEmailVerified')) {
        isEmailVerified = docData['isEmailVerified'];
      }

      // If already verified, we skip overwriting the profile and just update timestamp
      if (isEmailVerified) {
        return await docRef.update({'updatedAt': DateTime.now()});
      }
      // If NOT verified, we will proceed below to overwrite their unverified profile with OAuth data!
    }

    // We create a dictionary to hold the user data
    Map<String, dynamic> userData = {
      'email': data.email,
      'firstName': data.firstName,
      'lastName': data.lastName,
      'updatedAt': DateTime.now(),
      'avatarUrl': data.avatarUrl,
    };

    // If it's an OAuth login, we are verifying the email implicitly
    if (isOAuthLogin) {
      userData['isEmailVerified'] = true;
    }

    // Optional fields
    if (data.bio != null && data.bio!.isNotEmpty) userData['bio'] = data.bio;
    if (data.phoneNumber != null && data.phoneNumber!.isNotEmpty) userData['phoneNumber'] = data.phoneNumber;
    if (data.dateOfBirth != null) userData['dateOfBirth'] = data.dateOfBirth;

    // If the document does not exist, we set the createdAt and other initial fields
    if (!documentSnapshot.exists) {
      userData['createdAt'] = DateTime.now();
      userData['experiencePoints'] = 0;
      userData['userLevel'] = 1;
      userData['interests'] = data.interests;
      if (!isOAuthLogin) {
        userData['isEmailVerified'] = false; // Fresh email registration is unverified
      }
      userData['isOrganizer'] = false;
      
      // If the user hasn't put values to these optional fields
      // Then we set them to default values (empty string or null)
      if (!userData.containsKey('bio')) {
        userData['bio'] = "";
      }
      if (!userData.containsKey('phoneNumber')) {
        userData['phoneNumber'] = null;
      }
      if (!userData.containsKey('dateOfBirth')) {
        userData['dateOfBirth'] = null;
      }
    }

    return await docRef.set(userData, SetOptions(merge: true));
  }

  // Mark email as verified
  Future<void> markEmailAsVerified() async {
    if (uid == null) return;
    return await volunteerCollection.doc(uid).update({
      'isEmailVerified': true,
      'updatedAt': DateTime.now(),
    });
  }

  // Method to create or update campaign data
  Future updateCampaignData(CampaignData data) async {
    DocumentReference docRef = campaignCollection.doc();
    String campaignId = docRef.id;
    return await campaignCollection.doc(campaignId).set({
      'title': data.title,
      'organizerId': uid,
      'description': data.description,
      'location': data.location,
      'latitude': data.latitude,
      'longitude': data.longitude,
      'instructions': data.instructions,
      'requiredVolunteers': data.requiredVolunteers,
      'startDate': data.startDate,
      'endDate': data.endDate,
      'imageUrl': data.imageUrl,
      'categories': data.categories,
      'createdAt': DateTime.now(),
      'updatedAt': DateTime.now(),
      'registeredVolunteersUids': const [],
      'status': 'active',
    });
  }

  Future<void> updateLastSeen() async {
    return await volunteerCollection.doc(uid).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Method to get volunteer user data as a VolunteerUser object
  Future<VolunteerUser?> getVolunteerUser() async {
    if (uid == null) return null;
    // Get the document snapshot for the user with the given uid
    DocumentSnapshot doc = await volunteerCollection.doc(uid).get();
    if (doc.exists) {
      // Uses the factory constructor to create a VolunteerUser from the document snapshot
      return VolunteerUser.fromFirestore(doc);
    } else {
      return null;
    }
  }

  // Method to get a single campaign as a Campaign object
  Future<Campaign?> getCampaign(String campaignId) async {
    DocumentSnapshot doc = await campaignCollection.doc(campaignId).get();
    if (doc.exists) {
      return Campaign.fromFirestore(doc);
    } else {
      return null;
    }
  }

  // Stream to get volunteer user data from Firestore constantly
  Stream<VolunteerUser> get volunteerUserData {
    return volunteerCollection.doc(uid).snapshots().map((doc) {
      return VolunteerUser.fromFirestore(doc);
    });
  }

  // Stream to get all campaigns from Firestore and filter out delisted ones
  Stream<List<Campaign>> get campaigns {
    return campaignCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Campaign.fromFirestore(doc))
          .where((c) => !c.isDelisted)
          .toList();
    });
  }

  // Stream campaigns the current user has registered for (For "My Campaigns" Screen)
  Stream<List<Campaign>> get registeredCampaigns {
    if (uid == null) return Stream.value([]);

    return campaignCollection
        .where('registeredVolunteersUids', arrayContains: uid)
        .snapshots()
        .map(_campaignListFromSnapshot);
  }

  // Stream campaigns the current user has created (For "My Campaigns" Screen)
  Stream<List<Campaign>> get createdCampaigns {
    if (uid == null) return Stream.value([]);

    return campaignCollection
        .where('organizerId', isEqualTo: uid)
        .snapshots()
        .map(_campaignListFromSnapshot);
  }

  // Stream campaigns where the user is either the organizer or a registered volunteer
  Stream<List<Campaign>> get userChats {
    if (uid == null) return Stream.value([]);

    return campaignCollection
        .where(
          Filter.or(
            Filter('organizerId', isEqualTo: uid),
            Filter('registeredVolunteersUids', arrayContains: uid),
          ),
        )
        .snapshots()
        .map(_campaignListFromSnapshot);
  }

  // Helper method to convert QuerySnapshot to List<Campaign>
  List<Campaign> _campaignListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      return Campaign.fromFirestore(doc);
    }).toList();
  }

  // Method for registering a volunteer for a campaign
  Future<void> registerUserForCampaign(String campaignId) async {
    DocumentReference campaignRef = campaignCollection.doc(campaignId);
    return await campaignRef.update({
      'registeredVolunteersUids': FieldValue.arrayUnion([uid]),
    });
  }

  // Method to check if a volunteer user exists
  Future<bool> checkUserExists() async {
    final docSnapshot = await volunteerCollection.doc(uid).get();
    return docSnapshot.exists;
  }

  // Edit user profile data (profile screen)
  Future<void> editUserProfileData({
    required String firstName,
    required String lastName,
    required String bio,
    required List<String> interests,
  }) async {
    return await volunteerCollection.doc(uid).update({
      'firstName': firstName,
      'lastName': lastName,
      'bio': bio,
      'interests': interests,
      'updatedAt': DateTime.now(),
    });
  }

  // Update user avatar URL
  Future<void> updateUserAvatar(String avatarUrl) async {
    return await volunteerCollection.doc(uid).update({'avatarUrl': avatarUrl});
  }

  // Update FCM token
  Future<void> updateFCMToken(String token) async {
    if (uid == null) return;
    return await volunteerCollection.doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  // Update user location
  Future<void> updateUserLocation(double latitude, double longitude) async {
    if (uid == null) return;
    return await volunteerCollection.doc(uid).update({
      'lastKnownLatitude': latitude,
      'lastKnownLongitude': longitude,
    });
  }

  // Upload image to Firebase Storage and return the download URL
  Future<String?> uploadImage(
    String path,
    XFile image,
    String? customFileName,
  ) async {
    try {
      final ref = FirebaseStorage.instance
          .ref(path)
          .child(customFileName ?? image.name);
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      // print(e.toString());
      return null;
    }
  }

  // Delete image from Firebase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      if (!imageUrl.contains('firebasestorage')) return;
      await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      // print("Old photo deleted successfully.");
    } catch (e) {
      // print("Error while deleting the photo: $e");
    }
  }

  Future<void> toggleCampaignBookmark(
    String campaignId,
    bool isCurrentlyBookmarked,
  ) async {
    if (uid == null) return;

    return await volunteerCollection.doc(uid).update({
      // If currently bookmarked, remove it; otherwise, add it
      'bookmarkedCampaignsIds': isCurrentlyBookmarked
          ? FieldValue.arrayRemove([campaignId])
          : FieldValue.arrayUnion([campaignId]),
    });
  }

  // Update campaign start and end dates
  Future updateCampaignDates(
    String campaignId,
    DateTime start,
    DateTime end,
  ) async {
    return await campaignCollection.doc(campaignId).update({
      'startDate': start,
      'endDate': end,
      'updatedAt': DateTime.now(),
    });
  }

  // Update campaign general information
  Future<void> updateCampaignGeneralInfo(
    String campaignId,
    Map<String, dynamic> data,
  ) async {
    data['updatedAt'] = DateTime.now();
    return await campaignCollection.doc(campaignId).update(data);
  }

  // Transfer campaign ownership
  Future<void> transferCampaignOwnership(
    String campaignId,
    String oldOwnerId,
    String newOwnerId,
  ) async {
    final docRef = campaignCollection.doc(campaignId);

    // Use a transaction to perform a single atomic update.
    // This ensures Cloud Functions only trigger once
    return await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      List<dynamic> volunteers = List.from(data['registeredVolunteersUids'] ?? []);
      
      // Remove new owner from volunteers, add old owner to volunteers
      volunteers.remove(newOwnerId);
      if (!volunteers.contains(oldOwnerId)) {
        volunteers.add(oldOwnerId);
      }

      transaction.update(docRef, {
        'organizerId': newOwnerId,
        'registeredVolunteersUids': volunteers,
        'updatedAt': DateTime.now(),
      });
    });
  }

  // Get list of volunteers for a campaign
  Future<List<VolunteerUser>> getVolunteersFromList(List<dynamic> uids) async {
    List<List<dynamic>> chunks = [];
    for (var i = 0; i < uids.length; i += 10) {
      chunks.add(uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10));
    }

    List<VolunteerUser> allVolunteers = [];

    List<QuerySnapshot> snapshots = await Future.wait(
      chunks.map((chunk) {
        return volunteerCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
      }),
    );

    for (var snapshot in snapshots) {
      allVolunteers.addAll(
        snapshot.docs.map((doc) => VolunteerUser.fromFirestore(doc)),
      );
    }

    return allVolunteers;
  }

  // Remove a volunteer from the campaign
  Future removeVolunteerFromCampaign(
    String campaignId,
    String volunteerUid,
  ) async {
    return await campaignCollection.doc(campaignId).update({
      'registeredVolunteersUids': FieldValue.arrayRemove([volunteerUid]),
    });
  }

  // End the campaign
  // Set campaign status to 'ended'
  Future<void> endCampaign(String campaignId) async {
    return await campaignCollection.doc(campaignId).update({
      'status': 'ended',
      'updatedAt': DateTime.now(),
    });
  }

  // Toggle delist status
  Future<void> toggleCampaignDelistStatus(String campaignId, bool currentStatus) async {
    return await campaignCollection.doc(campaignId).update({
      'isDelisted': !currentStatus,
      'updatedAt': DateTime.now(),
    });
  }

  // Leave a campaign (the volunteer removes themselves)
  Future<void> leaveCampaign(String campaignId) async {
    return await campaignCollection.doc(campaignId).update({
      'registeredVolunteersUids': FieldValue.arrayRemove([uid]),
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/loading.dart';
import 'package:volunteer_app/widgets/event_card.dart';

class SavedCampaignsScreen extends StatelessWidget {
  const SavedCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Object? userObj = Provider.of<Object?>(context);
    final bool isNgo = userObj is NGO;
    
    String? uid;
    if (userObj is NGO) {
      uid = userObj.id;
    } else if (userObj is VolunteerUser) {
      uid = userObj.uid;
    }
    
    final bool isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
    
    if (uid == null && !isGuest) return Container();

    return Scaffold(
      backgroundColor: backgroundGrey,
      // AppBar
      appBar: AppBar(
        title: const Text(
          'Запазени кампании', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        backgroundColor: backgroundGrey,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isGuest ? _buildGuestState(context) : StreamBuilder<dynamic>(
        stream: isNgo ? DatabaseService(uid: uid).ngoData : DatabaseService(uid: uid).volunteerUserData,
        builder: (context, userSnapshot) {
          
          if (!userSnapshot.hasData || userSnapshot.data == null) {
            return Center(child: Loading());
          }

          final dynamic userData = userSnapshot.data!;
          final List<String> bookmarkedIds = isNgo 
              ? List<String>.from((userData as NGO).bookmarkedCampaignsIds) 
              : List<String>.from((userData as VolunteerUser).bookmarkedCampaignsIds);

          if (bookmarkedIds.isEmpty) {
            return _buildEmptyState();
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('campaigns')
                .where(FieldPath.documentId, whereIn: bookmarkedIds)
                .snapshots(),
            builder: (context, campaignsSnapshot) {
              
              if (!campaignsSnapshot.hasData) {
                return Center(child: Loading());
              }

              // Convert the Firestore documents into a list of Campaign objects using the factory constructor
              final List<Campaign> campaigns = campaignsSnapshot.data!.docs
                  .map((doc) => Campaign.fromFirestore(doc))
                  .toList();

              if (campaigns.isEmpty) {
                 return _buildEmptyState();
              }

              // Use the CampaignCard widget to display each campaign in a ListView
              return SafeArea(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  itemCount: campaigns.length,
                  itemBuilder: (context, index) {
                    return CampaignCard(
                      campaign: campaigns[index],
                      showRegisterButton: true, 
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            'Нямате отбелязани кампании.',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 30.0, right: 30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text(
              'Тази функция е достъпна само за регистрирани потребители.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/screens/main/helper_screens/chat_screen.dart'; 
import 'package:volunteer_app/screens/main/helper_screens/ngo_chat_screen.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_app/models/ngo.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final userObj = Provider.of<Object?>(context);
    final bool isNgo = userObj is NGO;
    final NGO? ngoUser = isNgo ? userObj : null;

    // Fetch current user details
    return Scaffold(
      backgroundColor: backgroundGrey,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(isNgo ? 'ngos' : 'volunteers') 
            .doc(currentUid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
      
          if (userSnapshot.hasError) {
            return Center(child: Text("Error: ${userSnapshot.error}"));
          }
      
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(
              child: Text("Не можете да водите чатове в режим на гост!"),
            );
          }
      
          VolunteerUser currentUser;
          if (isNgo && ngoUser != null) {
            currentUser = VolunteerUser(
              uid: ngoUser.id,
              email: ngoUser.email,
              firstName: ngoUser.name,
              lastName: '',
              interests: [],
              createdAt: ngoUser.createdAt,
              updatedAt: ngoUser.updatedAt,
              avatarUrl: ngoUser.logoUrl,
              isOrganizer: true,
            );
          } else {
            currentUser = VolunteerUser.fromFirestore(userSnapshot.data!);
          }
      
          // Fetch campaigns using the DatabaseService logic
          return StreamBuilder<List<Campaign>>(
            stream: DatabaseService(uid: currentUid).userChats,
            builder: (context, campaignSnapshot) {
              return StreamBuilder<List<NGO>>(
                stream: DatabaseService(uid: currentUid).userNgos,
                builder: (context, ngoSnapshot) {
                  if (campaignSnapshot.connectionState == ConnectionState.waiting || 
                      ngoSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
          
                  final List<Campaign> allCampaigns = campaignSnapshot.data ?? [];
                  final activeCampaigns = allCampaigns.where((c) => c.isActive).toList();
          
                  final List<NGO> allNgos = ngoSnapshot.data ?? [];
                  final List<NGO> chatNgos = allNgos.where((n) {
                    return n.members.contains(currentUid) || n.admins.contains(currentUid);
                  }).toList();

                  if (isNgo && ngoUser != null) {
                    if (!chatNgos.any((n) => n.id == ngoUser.id)) {
                      chatNgos.insert(0, ngoUser);
                    }
                  }
          
                  if (activeCampaigns.isEmpty && chatNgos.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text("Нямате активни чатове.", style: TextStyle(color: Colors.grey)),
                            Text(isNgo ? "Създай кампания!" : "Запишете се за кампания или станете член на организация!", style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }
          
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      if (activeCampaigns.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text("Кампании", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                        ),
                        ...activeCampaigns.map((campaign) => Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: greenPrimary.withAlpha(50),
                              backgroundImage: campaign.imageUrl.isNotEmpty 
                                  ? NetworkImage(campaign.imageUrl) 
                                  : null,
                              child: campaign.imageUrl.isEmpty 
                                  ? Icon(Icons.group, color: greenPrimary) 
                                  : null,
                            ),
                            title: Text(
                              campaign.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Натисни за чат",
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: blueSecondary),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CampaignChatScreen(
                                    campaign: campaign,
                                    currentUser: currentUser,
                                  ),
                                ),
                              );
                            },
                          ),
                        )),
                      ],
                      if (chatNgos.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text("Организации", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                        ),
                        ...chatNgos.map((ngo) => Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: greenPrimary.withAlpha(50),
                              backgroundImage: ngo.logoUrl != null && ngo.logoUrl!.isNotEmpty 
                                  ? NetworkImage(ngo.logoUrl!) 
                                  : null,
                              child: (ngo.logoUrl == null || ngo.logoUrl!.isEmpty) 
                                  ? Icon(Icons.corporate_fare, color: greenPrimary) 
                                  : null,
                            ),
                            title: Text(
                              ngo.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "Натисни за чат",
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: blueSecondary),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NgoChatScreen(
                                    ngo: ngo,
                                    currentUser: currentUser,
                                  ),
                                ),
                              );
                            },
                          ),
                        )),
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
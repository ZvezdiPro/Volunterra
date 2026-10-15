import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/screens/main/helper_screens/chat_screen.dart';
import 'package:volunteer_app/screens/main/helper_screens/direct_chat_screen.dart';
import 'package:volunteer_app/screens/main/helper_screens/ngo_chat_screen.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/services/direct_chat_service.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_app/models/ngo.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen>
    with AutomaticKeepAliveClientMixin {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;

  Stream<DocumentSnapshot>? _userStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _directChatsStream;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final userObj = Provider.of<Object?>(context);
      final bool isNgo = userObj is NGO;

      _userStream = FirebaseFirestore.instance
          .collection(isNgo ? 'ngos' : 'volunteers')
          .doc(currentUid)
          .snapshots();
      _directChatsStream = DirectChatService().userChats(currentUid);

      _isInit = true;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userObj = Provider.of<Object?>(context);
    final bool isNgo = userObj is NGO;
    final NGO? ngoUser = isNgo ? userObj : null;

    // Fetch current user details
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundGrey,
        body: StreamBuilder<DocumentSnapshot>(
          stream: _userStream,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: greenPrimary),
              );
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
                    final List<Campaign> allCampaigns =
                        campaignSnapshot.data ?? [];
                    final activeCampaigns = allCampaigns
                        .where((c) => c.status == 'active')
                        .toList();
                    final endedCampaigns = allCampaigns
                        .where((c) => c.status == 'ended')
                        .toList();

                    final List<NGO> allNgos = ngoSnapshot.data ?? [];
                    final List<NGO> chatNgos = allNgos.where((n) {
                      return n.members.contains(currentUid) ||
                          n.admins.contains(currentUid);
                    }).toList();

                    if (isNgo && ngoUser != null) {
                      if (!chatNgos.any((n) => n.id == ngoUser.id)) {
                        chatNgos.insert(0, ngoUser);
                      }
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _directChatsStream,
                      builder: (context, directChatSnapshot) {
                        final directChats =
                            List<
                              QueryDocumentSnapshot<Map<String, dynamic>>
                            >.from(directChatSnapshot.data?.docs ?? []);
                        DateTime lastMessageDate(
                          QueryDocumentSnapshot<Map<String, dynamic>> chat,
                        ) {
                          return (chat.data()['lastMessageAt'] as Timestamp?)
                                  ?.toDate() ??
                              DateTime.fromMillisecondsSinceEpoch(0);
                        }

                        directChats.sort(
                          (a, b) =>
                              lastMessageDate(b).compareTo(lastMessageDate(a)),
                        );

                        return Column(
                          children: [
                            Material(
                              color: backgroundGrey,
                              child: TabBar(
                                labelColor: greenPrimary,
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: greenPrimary,
                                tabs: const [
                                  Tab(text: "Лични чатове"),
                                  Tab(text: "Кампании и организации"),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildDirectChats(
                                    directChats,
                                    directChatSnapshot.error,
                                    directChatSnapshot.connectionState ==
                                        ConnectionState.waiting,
                                    currentUid,
                                    currentUser,
                                  ),
                                  campaignSnapshot.connectionState ==
                                              ConnectionState.waiting &&
                                          ngoSnapshot.connectionState ==
                                              ConnectionState.waiting &&
                                          campaignSnapshot.data == null &&
                                          ngoSnapshot.data == null
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: greenPrimary,
                                          ),
                                        )
                                      : activeCampaigns.isEmpty &&
                                            chatNgos.isEmpty &&
                                            endedCampaigns.isEmpty &&
                                            !campaignSnapshot.hasError &&
                                            !ngoSnapshot.hasError
                                      ? _buildEmptyState(
                                          'Нямате чатове с кампании или организации.',
                                        )
                                      : ListView(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          children: [
                                            if (campaignSnapshot.hasError)
                                              _buildStreamError(
                                                'кампаниите',
                                                campaignSnapshot.error!,
                                              ),
                                            if (ngoSnapshot.hasError)
                                              _buildStreamError(
                                                'организациите',
                                                ngoSnapshot.error!,
                                              ),
                                            if (activeCampaigns.isNotEmpty) ...[
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  "Активни кампании",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              ...activeCampaigns.map(
                                                (campaign) => Card(
                                                  elevation: 2,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  child: ListTile(
                                                    leading: CircleAvatar(
                                                      backgroundColor:
                                                          greenPrimary
                                                              .withAlpha(50),
                                                      backgroundImage:
                                                          campaign
                                                              .imageUrl
                                                              .isNotEmpty
                                                          ? NetworkImage(
                                                              campaign.imageUrl,
                                                            )
                                                          : null,
                                                      child:
                                                          campaign
                                                              .imageUrl
                                                              .isEmpty
                                                          ? Icon(
                                                              Icons.group,
                                                              color:
                                                                  greenPrimary,
                                                            )
                                                          : null,
                                                    ),
                                                    title: Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            campaign.title,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        if (campaign.status ==
                                                            'ended') ...[
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 6,
                                                                  vertical: 2,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors.red
                                                                  .withAlpha(
                                                                    30,
                                                                  ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4,
                                                                  ),
                                                              border: Border.all(
                                                                color: Colors
                                                                    .red
                                                                    .withAlpha(
                                                                      100,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: const Text(
                                                              "прекратена",
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    subtitle: Text(
                                                      "Натисни за чат",
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    trailing: Icon(
                                                      Icons.arrow_forward_ios,
                                                      size: 16,
                                                      color: blueSecondary,
                                                    ),
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              CampaignChatScreen(
                                                                campaign:
                                                                    campaign,
                                                                currentUser:
                                                                    currentUser,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (chatNgos.isNotEmpty) ...[
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  "Организации",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              ...chatNgos.map(
                                                (ngo) => Card(
                                                  elevation: 2,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  child: ListTile(
                                                    leading: CircleAvatar(
                                                      backgroundColor:
                                                          greenPrimary
                                                              .withAlpha(50),
                                                      backgroundImage:
                                                          ngo.logoUrl != null &&
                                                              ngo
                                                                  .logoUrl!
                                                                  .isNotEmpty
                                                          ? NetworkImage(
                                                              ngo.logoUrl!,
                                                            )
                                                          : null,
                                                      child:
                                                          (ngo.logoUrl ==
                                                                  null ||
                                                              ngo
                                                                  .logoUrl!
                                                                  .isEmpty)
                                                          ? Icon(
                                                              Icons
                                                                  .corporate_fare,
                                                              color:
                                                                  greenPrimary,
                                                            )
                                                          : null,
                                                    ),
                                                    title: Text(
                                                      ngo.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    subtitle: Text(
                                                      "Натисни за чат",
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    trailing: Icon(
                                                      Icons.arrow_forward_ios,
                                                      size: 16,
                                                      color: blueSecondary,
                                                    ),
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              NgoChatScreen(
                                                                ngo: ngo,
                                                                currentUser:
                                                                    currentUser,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],

                                            if (endedCampaigns.isNotEmpty) ...[
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  "Прекратени кампании",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              ...endedCampaigns.map(
                                                (campaign) => Card(
                                                  elevation: 2,
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  child: ListTile(
                                                    leading: CircleAvatar(
                                                      backgroundColor: Colors
                                                          .grey
                                                          .withAlpha(50),
                                                      backgroundImage:
                                                          campaign
                                                              .imageUrl
                                                              .isNotEmpty
                                                          ? NetworkImage(
                                                              campaign.imageUrl,
                                                            )
                                                          : null,
                                                      child:
                                                          campaign
                                                              .imageUrl
                                                              .isEmpty
                                                          ? const Icon(
                                                              Icons.group,
                                                              color:
                                                                  Colors.grey,
                                                            )
                                                          : null,
                                                    ),
                                                    title: Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            campaign.title,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black54,
                                                                ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.red
                                                                .withAlpha(30),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                            border: Border.all(
                                                              color: Colors.red
                                                                  .withAlpha(
                                                                    100,
                                                                  ),
                                                            ),
                                                          ),
                                                          child: const Text(
                                                            "прекратена",
                                                            style: TextStyle(
                                                              color: Colors.red,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    subtitle: Text(
                                                      "Архивиран чат",
                                                      style: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    trailing: Icon(
                                                      Icons.arrow_forward_ios,
                                                      size: 16,
                                                      color: Colors.grey[400],
                                                    ),
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              CampaignChatScreen(
                                                                campaign:
                                                                    campaign,
                                                                currentUser:
                                                                    currentUser,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDirectChats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> directChats,
    Object? error,
    bool isLoading,
    String currentUid,
    VolunteerUser currentUser,
  ) {
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Грешка при зареждане на личните чатове: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: greenPrimary),
      );
    }

    if (directChats.isEmpty) {
      return _buildEmptyState('Нямате лични чатове.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: directChats.length,
      itemBuilder: (context, index) {
        final chat = directChats[index];
        final data = chat.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final recipientUid = participants.firstWhere(
          (uid) => uid != currentUid,
          orElse: () => '',
        );
        final participantDetails = Map<String, dynamic>.from(
          data['participantDetails'] ?? {},
        );
        final recipient = Map<String, dynamic>.from(
          participantDetails[recipientUid] ?? {},
        );
        final recipientName = recipient['name'] as String? ?? 'Потребител';
        final recipientAvatarUrl = recipient['avatarUrl'] as String?;
        final lastMessageAt = (data['lastMessageAt'] as Timestamp?)?.toDate();
        final currentName = '${currentUser.firstName} ${currentUser.lastName}'
            .trim();

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: greenPrimary.withAlpha(50),
              backgroundImage:
                  recipientAvatarUrl != null && recipientAvatarUrl.isNotEmpty
                  ? NetworkImage(recipientAvatarUrl)
                  : null,
              child: recipientAvatarUrl == null || recipientAvatarUrl.isEmpty
                  ? const Icon(Icons.person, color: greenPrimary)
                  : null,
            ),
            title: Text(
              recipientName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              data['lastMessage'] as String? ??
                  'Натисни за чат',
              maxLines: 1,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: lastMessageAt == null
                ? const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: blueSecondary,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(lastMessageAt),
                        style: const TextStyle(
                          color: blueSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('dd.MM').format(lastMessageAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                    ],
                  ),
            onTap: recipientUid.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DirectChatScreen(
                          chatId: chat.id,
                          currentUid: currentUid,
                          currentName: currentName,
                          currentAvatarUrl: currentUser.avatarUrl,
                          recipientUid: recipientUid,
                          recipientName: recipientName,
                          recipientAvatarUrl: recipientAvatarUrl,
                        ),
                      ),
                    );
                  },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamError(String label, Object error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        'Грешка при зареждане на $label: $error',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}

import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/screens/main/helper_screens/chat_screen.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/widgets/event_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onGoToEvents;

  const HomeScreen({super.key, required this.onGoToEvents});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _currentUid;
  late DatabaseService _dbService;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid ?? ''; 
    _dbService = DatabaseService(uid: _currentUid);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundGrey,
      // StreamBuilder for user's data
      child: StreamBuilder<VolunteerUser>(
        stream: _dbService.volunteerUserData,
        builder: (context, userSnapshot) {
          
          String firstName = 'доброволец';
          if (userSnapshot.hasData && userSnapshot.data != null) {
            firstName = userSnapshot.data!.firstName;
          }
          
          List<String> userInterests = [];
          if (userSnapshot.hasData && userSnapshot.data != null) {
            userInterests = userSnapshot.data!.interests;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Здравей, $firstName! 👋',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 25),

                // Campaign listener
                StreamBuilder<List<Campaign>>(
                  stream: _dbService.campaigns,
                  builder: (context, campaignSnapshot) {
                    if (campaignSnapshot.connectionState == ConnectionState.waiting && !campaignSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(child: CircularProgressIndicator(color: greenPrimary)),
                      );
                    }

                    if (campaignSnapshot.hasError) {
                      return Center(child: Text('Възникна грешка: ${campaignSnapshot.error}'));
                    }

                    if (!campaignSnapshot.hasData || campaignSnapshot.data!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Text('Все още няма активни кампании.', style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    }

                    List<Campaign> allCampaigns = campaignSnapshot.data!;

                    List<Campaign> activeCampaigns = allCampaigns
                        .where((campaign) => campaign.status == 'active' && campaign.endDate.isAfter(DateTime.now()))
                        .toList();

                    if (activeCampaigns.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Text('В момента няма активни кампании.', style: TextStyle(color: Colors.grey)),
                        ),
                      );
                    }

                    activeCampaigns.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    Campaign latestCampaign = activeCampaigns.first;

                    // If there are more than 1 active campaigns which the user's interested in
                    // pick a random one from the remaining list (excluding the latest)
                    Campaign? recommendedCampaign;

                    // Filter out campaigns the user is already registered for and the latest campaign
                    List<Campaign> eligibleCampaigns = activeCampaigns.where((campaign) {
                      if (campaign.id == latestCampaign.id) return false;
                      bool isAlreadyRegistered = campaign.registeredVolunteersUids.contains(_currentUid);
                      return !isAlreadyRegistered;
                    }).toList();

                    if (eligibleCampaigns.isNotEmpty) {
                      List<Campaign> matchingCampaigns = eligibleCampaigns.where((campaign) {
                        return campaign.categories.any((category) => userInterests.contains(category));
                      }).toList();
                      if (matchingCampaigns.isNotEmpty) {
                        // If there are campaigns matching the user's interests which they haven't registered for, pick a random one from that list
                        recommendedCampaign = matchingCampaigns[Random().nextInt(matchingCampaigns.length)];
                      } else {
                        // Otherwise, just pick a random campaign from the remaining active campaigns
                        recommendedCampaign = eligibleCampaigns[Random().nextInt(eligibleCampaigns.length)];
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Последно добавена кампания'),
                        SizedBox(
                          width: double.infinity,
                          child: CampaignCard(campaign: latestCampaign),
                        ),
                        const SizedBox(height: 30),

                        if (recommendedCampaign != null) ...[
                          _buildSectionTitle('Може да ти хареса'),
                          SizedBox(
                            width: double.infinity,
                            child: CampaignCard(campaign: recommendedCampaign),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ],
                    );
                  },
                ),

                // User's activity (placeholder for now)
                _buildSectionTitle('Твоята активност'),
                const SizedBox(height: 15),
                _buildActivitySection(userSnapshot.data),
                const SizedBox(height: 30),

                // Button to go to the Events page
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0), 
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: greenPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: widget.onGoToEvents,
                      child: const Text(
                        'Открий още кампании!',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
      ),
    );
  }

  Widget _buildActivitySection(VolunteerUser? currentUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      // StreamBuilders for registered campaigns and created campaigns
      child: StreamBuilder<List<Campaign>>(
        stream: _dbService.registeredCampaigns,
        builder: (context, registeredSnapshot) {
          
          return StreamBuilder<List<Campaign>>(
            stream: _dbService.createdCampaigns,
            builder: (context, createdSnapshot) {
              
              if (registeredSnapshot.connectionState == ConnectionState.waiting ||
                  createdSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: greenPrimary),
                  ),
                );
              }

              if (registeredSnapshot.hasError || createdSnapshot.hasError) {
                return const Center(
                  child: Text(
                    'Възникна грешка при зареждането на активността.',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              // Combine registered and created campaigns, ensuring no duplicates, then filter for active/upcoming ones
              List<Campaign> registered = registeredSnapshot.data ?? [];
              List<Campaign> created = createdSnapshot.data ?? [];

              List<Campaign> myCampaigns = [...created];
              for (var campaign in registered) {
                if (!myCampaigns.any((c) => c.title == campaign.title)) {
                  myCampaigns.add(campaign);
                }
              }

              List<Campaign> upcomingCampaigns = myCampaigns
                  .where((c) => c.status == 'active' && c.endDate.isAfter(DateTime.now()))
                  .toList();

              upcomingCampaigns.sort((a, b) => a.startDate.compareTo(b.startDate));

              // Placeholder if the user has no upcoming campaigns
              if (upcomingCampaigns.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: backgroundGrey,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey.withAlpha(30), shape: BoxShape.circle),
                        child: const Icon(Icons.event_busy, color: Colors.grey),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          'Нямаш предстоящи задачи. Време е да се запишеш!',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // List of upcoming campaigns the user is involved in
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundGrey,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(upcomingCampaigns.length, (index) {
                    Campaign campaign = upcomingCampaigns[index];
                    
                    bool isAdmin = campaign.organizerId == _currentUid; 
                    bool isLast = index == upcomingCampaigns.length - 1;

                    return _buildActivityItem(campaign, isAdmin, isLast, currentUser);
                  }),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(Campaign campaign, bool isAdmin, bool isLast, VolunteerUser? currentUser) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CampaignChatScreen(campaign: campaign, currentUser: currentUser!), 
          ),
        );
      },
      child: Column(
        children: [
          Row(
            children: [
              // Different icon for organizer and participant
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: greenPrimary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAdmin ? Icons.campaign : Icons.event,
                  color: greenPrimary,
                ),
              ),
              const SizedBox(width: 15),
              
              // Campaign title, date and location
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            campaign.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Admin badge, if the user is the organizer of the campaign
                        if (isAdmin)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Организатор',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Date and location
                    Text(
                      '${campaign.startDate.day}.${campaign.startDate.month}.${campaign.startDate.year} • ${campaign.location}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLast)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 1, color: Colors.black12),
            ),
        ],
      ),
    );
  }
}
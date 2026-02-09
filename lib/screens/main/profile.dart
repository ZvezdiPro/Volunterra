import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/screens/main/edit_profile_screen.dart';
import 'package:volunteer_app/screens/main/settings.dart';
import 'package:volunteer_app/screens/main/achievements.dart';
import 'package:volunteer_app/screens/main/saved_campaigns.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/widgets/campaign_details_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _campaignsCount = 0;
  int _volunteerHours = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData(); 
    });
  }

  // An async method that fetches the data from the DB
  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    final volunteer = Provider.of<VolunteerUser?>(context, listen: false);
    if (volunteer == null) return;
    
    final DatabaseService dbService = DatabaseService(uid: volunteer.uid);

    try {
      // Fetch both registered and created campaigns in parallel
      final results = await Future.wait([
        dbService.registeredCampaigns.first,
        dbService.createdCampaigns.first,
      ]);

      final allCampaigns = [...results[0], ...results[1]];

      setState(() {
        _campaignsCount = allCampaigns.length;
        _volunteerHours = allCampaigns.fold(0, (sum, campaign) => sum + campaign.durationInHours);
      });
    } catch (e) {
      // print('Грешка при зареждане на броя кампании: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final VolunteerUser? volunteer = Provider.of<VolunteerUser?>(context);

    // If volunteer is null, show a screen indicating the error
    if (volunteer == null) {
      return Scaffold(
        backgroundColor: backgroundGrey,
        body: Center(
          child: Text(
            'Потребителските данни не са налични.',
            style: TextStyle(fontSize: 18, color: Colors.black),
          ),
        ),
      );
    }
    
    final bool isGuest = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;

    return Scaffold(
      backgroundColor: backgroundGrey,
      body: isGuest 
        ? _buildProfileContent(VolunteerUser.forAuth(uid: volunteer.uid))
        : _buildProfileContent(volunteer),
    );
  }

  // UI elements for the profile page
  Widget _buildProfileContent(VolunteerUser volunteer) {
    final String memberSince = DateFormat('dd.MM.yyyy').format(volunteer.createdAt);

    return SingleChildScrollView(
          padding: EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Profile picture - either from URL or placeholder
              CircleAvatar(
                radius: 50.0,
                backgroundImage: (volunteer.avatarUrl != null && volunteer.avatarUrl!.isNotEmpty)
                  ? NetworkImage(volunteer.avatarUrl!) as ImageProvider
                  : const AssetImage('assets/images/profile_placeholder.png'),
                backgroundColor: Colors.transparent,
              ),
              SizedBox(height: 10.0),

              // Full name
              Text(
                volunteer.firstName.isNotEmpty && volunteer.lastName.isNotEmpty ? '${volunteer.firstName} ${volunteer.lastName}' : 'Временен гост',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 10.0),

              // Edit Profile Button
              if (volunteer.firstName.isNotEmpty && volunteer.lastName.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 45.0,
                child: ElevatedButton.icon(
                    icon: Icon(Icons.edit, color: Colors.white, size: 20),
                    label: Text(
                      'Редактирай профила',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueSecondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            key: UniqueKey(),
                            volunteer: volunteer
                          ),
                        ),
                      ).then((_) {
                        _loadProfileData(); 
                      });
                    },
                  ),
              ),

              SizedBox(height: 15.0),

              // Quick stats
              Container(
                padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15.0),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: Offset(0, 5)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('$_campaignsCount', 'Кампании'),
                    _buildVerticalDivider(),
                    _buildStatItem('$_volunteerHours', 'Часа'),
                    _buildVerticalDivider(),
                    _buildStatItem(memberSince, 'Член от'),
                  ],
                ),
              ),

              SizedBox(height: 10.0),

              // Achievements
              _buildMenuTile(
                Icons.emoji_events,
                'Моите Постижения',
                Colors.orange.shade100,
                accentAmber,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AchievementsPage()),
                  );
                },),

              SizedBox(height: 10.0),

              // Bookmarked campaigns
              _buildMenuTile(
                Icons.bookmark,
                'Запазени кампании',
                Colors.green.shade100,
                greenPrimary,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SavedCampaignsScreen()),
                  );
                },
              ),

              SizedBox(height: 10.0),

              // Settings
              _buildMenuTile(
                Icons.settings,
                'Настройки',
                Colors.blue.shade100,
                Colors.blue,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
              ),

              SizedBox(height: 20.0),

              // Recent activity
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Последна активност',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
              ),

              SizedBox(height: 10.0),

              // StreamBuilder for recent campaigns
              StreamBuilder<List<Campaign>>(
                stream: DatabaseService(uid: volunteer.uid).registeredCampaigns,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      padding: EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Text('Няма скорошна активност.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    );
                  }

                  final recentCampaigns = snapshot.data!.take(3).toList();

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 5, offset: Offset(0, 2)),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true, 
                      physics: NeverScrollableScrollPhysics(), 
                      itemCount: recentCampaigns.length,
                      separatorBuilder: (context, index) => Divider(height: 1, indent: 30, endIndent: 30),
                      itemBuilder: (context, index) {
                        final campaign = recentCampaigns[index];
                        
                        return ListTile(
                          leading: Icon(Icons.event_note, color: greenPrimary),
                          title: Text(
                            campaign.title, 
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          subtitle: Text(
                            'На: ${DateFormat('dd.MM.yyyy').format(campaign.startDate)}', 
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            // Go to more detailed screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CampaignDetailsScreen(
                                  campaign: campaign,
                                  showRegisterButton: false,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          )
        );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30.0,
      width: 1.0,
      color: Colors.grey[300],
    );
  }

  Widget _buildMenuTile(IconData icon, String title, Color bgColor, Color iconColor, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16.0, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 14.0, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
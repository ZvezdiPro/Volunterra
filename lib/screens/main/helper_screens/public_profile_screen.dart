import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/widgets/campaign_details_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final VolunteerUser volunteer;

  const PublicProfileScreen({super.key, required this.volunteer});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  int _campaignsCount = 0;
  int _volunteerHours = 0;
  List<Campaign> _recentCampaigns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVolunteerData();
  }

  Future<void> _loadVolunteerData() async {
    final DatabaseService dbService = DatabaseService(uid: widget.volunteer.uid);

    try {
      final results = await Future.wait([
        dbService.registeredCampaigns.first,
        dbService.createdCampaigns.first,
      ]);

      final allCampaigns = [...results[0], ...results[1]];
      
      allCampaigns.sort((a, b) => b.startDate.compareTo(a.startDate));

      if (mounted) {
        setState(() {
          _campaignsCount = allCampaigns.length;
          _volunteerHours = allCampaigns.fold(0, (sum, campaign) => sum + campaign.durationInHours);
          _recentCampaigns = allCampaigns.take(3).toList(); // Взимаме топ 3
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String memberSince = DateFormat('dd.MM.yyyy').format(widget.volunteer.createdAt);

    return Scaffold(
      backgroundColor: backgroundGrey, 
      appBar: AppBar(
        title: const Text('Профил на доброволец', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: greenPrimary)) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile picture
                CircleAvatar(
                  radius: 50.0,
                  backgroundImage: (widget.volunteer.avatarUrl != null && widget.volunteer.avatarUrl!.isNotEmpty)
                    ? NetworkImage(widget.volunteer.avatarUrl!) as ImageProvider
                    : const AssetImage('assets/images/profile_placeholder.png'),
                  backgroundColor: Colors.transparent,
                ),
                const SizedBox(height: 10.0),

                // Name and surname
                Text(
                  '${widget.volunteer.firstName} ${widget.volunteer.lastName}',
                  style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 20.0),

                // Stats
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: [
                      BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 5)),
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

                const SizedBox(height: 30.0),

                // Recent activity
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Последна активност',
                    style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 10.0),

                if (_recentCampaigns.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Няма скорошна активност.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 5, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentCampaigns.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 30, endIndent: 30),
                      itemBuilder: (context, index) {
                        final campaign = _recentCampaigns[index];
                        return ListTile(
                          leading: const Icon(Icons.event_note, color: greenPrimary),
                          title: Text(
                            campaign.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          subtitle: Text(
                            'На: ${DateFormat('dd.MM.yyyy').format(campaign.startDate)}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
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
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30.0, width: 1.0, color: Colors.grey[300]);
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.black)),
        Text(label, style: TextStyle(fontSize: 14.0, color: Colors.grey[600])),
      ],
    );
  }
}
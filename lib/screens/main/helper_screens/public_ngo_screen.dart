import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/screens/main/helper_screens/campaign_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicNgoScreen extends StatefulWidget {
  final NGO ngo;

  const PublicNgoScreen({super.key, required this.ngo});

  @override
  State<PublicNgoScreen> createState() => _PublicNgoScreenState();
}

class _PublicNgoScreenState extends State<PublicNgoScreen> {
  
  Future<void> _launchURL(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    String formattedUrl = urlString;
    if (!formattedUrl.startsWith('http')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final Uri url = Uri.parse(formattedUrl);
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Неуспешно отваряне на връзката: $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userObj = Provider.of<Object?>(context);
    
    return StreamBuilder<NGO?>(
      stream: DatabaseService(uid: widget.ngo.id).ngoData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: backgroundGrey,
            body: Center(child: CircularProgressIndicator(color: greenPrimary)),
          );
        }

        final NGO ngo = snapshot.data ?? widget.ngo;
        final bool isSameNgo = userObj is NGO && userObj.id == ngo.id;

        return Scaffold(
          backgroundColor: backgroundGrey,
          appBar: AppBar(
            backgroundColor: backgroundGrey,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Профил на НПО', style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // NGO Logo
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: ngo.logoUrl != null && ngo.logoUrl!.isNotEmpty
                        ? NetworkImage(ngo.logoUrl!)
                        : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider,
                  ),
                ),
                const SizedBox(height: 12),
                
                // NGO Name & Verification
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        ngo.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (ngo.isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 6.0),
                        child: Icon(Icons.verified, color: blueSecondary, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                if (!isSameNgo && userObj is VolunteerUser)
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Функцията за последване ще бъде налична скоро.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: greenPrimary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
                      label: const Text('Последвай НПО', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: greenPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                
                if (!isSameNgo && userObj is VolunteerUser)
                  const SizedBox(height: 20),

                // Impact Stats (Members, Campaigns, Followers)
                _buildImpactStats(ngo),
                
                const SizedBox(height: 10),

                // Description
                _buildSectionTitle('За нас'),
                _buildInfoCard(
                  child: Text(
                    ngo.description,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),

                // Contact Information
                _buildSectionTitle('Контакти'),
                _buildInfoCard(
                  child: Column(
                    children: [
                      _buildContactItem(Icons.email_outlined, 'Имейл', ngo.email),
                      const Divider(height: 20),
                      _buildContactItem(Icons.phone_outlined, 'Телефон', ngo.phone),
                      if (ngo.website != null && ngo.website!.isNotEmpty) ...[
                        const Divider(height: 20),
                        _buildContactItem(
                          Icons.language_outlined, 
                          'Уебсайт', 
                          ngo.website!,
                          onTap: () => _launchURL(ngo.website!),
                        ),
                      ],
                      const Divider(height: 20),
                      _buildContactItem(Icons.location_on_outlined, 'Адрес', ngo.address),
                    ],
                  ),
                ),

                // Social Links
                if (ngo.socialLinks.isNotEmpty) ...[
                  _buildSectionTitle('Социални мрежи'),
                  _buildSocialLinks(ngo.socialLinks),
                ],

                // Hosted Campaigns
                _buildSectionTitle('Създадени кампании'),
                _buildHostedCampaigns(ngo.id),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildImpactStats(NGO ngo) {
    return StreamBuilder<List<Campaign>>(
      stream: DatabaseService(uid: ngo.id).createdCampaigns,
      builder: (context, snapshot) {
        final campaignsCount = snapshot.hasData ? snapshot.data!.length : 0;
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.grey.shade300, blurRadius: 10, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(ngo.members.length.toString(), 'Членове'),
              _buildVerticalDivider(),
              _buildStatItem(campaignsCount.toString(), 'Кампании'),
              _buildVerticalDivider(),
              _buildStatItem(ngo.followers.length.toString(), 'Последователи'),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[200]);
  }

  Widget _buildContactItem(IconData icon, String label, String value, {VoidCallback? onTap}) {
    Widget content = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: greenPrimary.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: greenPrimary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildSocialLinks(Map<String, String> links) {
    final entries = links.entries.where((e) => e.value.trim().isNotEmpty).toList();
    if (entries.isEmpty) return const SizedBox();

    return _buildInfoCard(
      child: Column(
        children: List.generate(entries.length, (index) {
          final entry = entries[index];
          IconData icon;
          String label;
          switch (entry.key.toLowerCase()) {
            case 'facebook':
              icon = Icons.facebook;
              label = 'Facebook';
              break;
            case 'instagram':
              icon = Icons.camera_alt;
              label = 'Instagram';
              break;
            default:
              icon = Icons.link;
              label = entry.key.isEmpty ? '' : '${entry.key[0].toUpperCase()}${entry.key.substring(1)}';
          }
          
          String displayValue = entry.value.trim();
          displayValue = displayValue.replaceAll(RegExp(r'https?:\/\/(www\.)?(facebook|instagram)\.com\/', caseSensitive: false), '');
          if (displayValue.endsWith('/')) {
            displayValue = displayValue.substring(0, displayValue.length - 1);
          }
          if (displayValue.startsWith('@')) {
             displayValue = displayValue.substring(1);
          }
          
          return Column(
            children: [
              _buildContactItem(
                icon, 
                label, 
                '@$displayValue',
                onTap: () {
                  final handle = displayValue;
                  if (entry.key.toLowerCase() == 'facebook') {
                    _launchURL('https://facebook.com/$handle');
                  } else if (entry.key.toLowerCase() == 'instagram') {
                    _launchURL('https://instagram.com/$handle');
                  } else {
                    _launchURL(entry.value);
                  }
                }
              ),
              if (index < entries.length - 1)
                const Divider(height: 20),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHostedCampaigns(String ngoId) {
    return StreamBuilder<List<Campaign>>(
      stream: DatabaseService(uid: ngoId).createdCampaigns,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: greenPrimary));
        }
        
        final campaigns = snapshot.data ?? [];
        
        if (campaigns.isEmpty) {
          return _buildInfoCard(
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Все още няма създадени кампании.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          );
        }

        // Sort by date desc
        campaigns.sort((a, b) => b.startDate.compareTo(a.startDate));

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: campaigns.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final campaign = campaigns[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 5, offset: const Offset(0, 2)),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: campaign.imageUrl.isNotEmpty
                      ? Image.network(campaign.imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                      : Container(
                          width: 50,
                          height: 50,
                          color: greenPrimary.withAlpha(30),
                          child: const Icon(Icons.campaign, color: greenPrimary),
                        ),
                ),
                title: Text(campaign.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: Text(
                  '${DateFormat('dd.MM.yyyy').format(campaign.startDate)} • ${campaign.location}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
              ),
            );
          },
        );
      },
    );
  }
}

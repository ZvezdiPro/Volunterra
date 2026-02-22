import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class CampaignInfoScreen extends StatelessWidget {
  final Campaign campaign;

  const CampaignInfoScreen({super.key, required this.campaign});

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy', 'bg_BG').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'bg_BG').format(date);
  }

  // Open in Google Maps
  Future<void> _openMap(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open maps.';
      }
    } catch (e) {
      debugPrint("Error launching maps: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: const Text("Информация за кампанията", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: backgroundGrey,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Center(
              child: Text(
                campaign.title,
                style: mainHeadingStyle.copyWith(fontSize: 24),
              ),
            ),
            const SizedBox(height: 20),

            // Location Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on, color: Colors.blue, size: 30),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Локация", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              Text(
                                campaign.location,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _openMap(campaign.latitude, campaign.longitude),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text("Виж на картата"),
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Start and End Dates
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.calendar_today_outlined,
                    color: greenPrimary,
                    title: "Начало",
                    date: _formatDate(campaign.startDate),
                    time: _formatTime(campaign.startDate),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.event_available_outlined,
                    color: Colors.orange,
                    title: "Край",
                    date: _formatDate(campaign.endDate),
                    time: _formatTime(campaign.endDate),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // Details Section
            const Text("За кампанията", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: backgroundGrey,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: blueSecondary.withAlpha(100)),
              ),
              child: Text(
                campaign.description,
                style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
            ),

            const SizedBox(height: 25),

            // Instructions Section (if any)
            if (campaign.instructions.isNotEmpty) ...[
              const Text("Инструкции", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: backgroundGrey,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.withAlpha(100)),
                ),
                child: Text(
                  campaign.instructions,
                  style: TextStyle(fontSize: 15, height: 1.5, color: Colors.brown[900]),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  // Helper widget to build info date cards
  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String date,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundGrey,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: blueSecondary.withAlpha(100), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [ 
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
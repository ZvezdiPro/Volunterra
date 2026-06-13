import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:volunteer_app/screens/main/helper_screens/notification_settings.dart';
import 'package:volunteer_app/screens/main/helper_screens/profile_settings.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        backgroundColor: backgroundGrey,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Настройки', style: appBarHeadingStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardGrey,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 5, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.person,
                  title: 'Настройки на профила',
                  bgColor: Colors.green.shade100,
                  iconColor: greenPrimary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileSettingsPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 30, endIndent: 30),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.notifications,
                  title: 'Известия',
                  bgColor: Colors.blue.shade100,
                  iconColor: Colors.blue,
                  onTap: () {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationSettingsPage(uid: user.uid),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1, indent: 30, endIndent: 30),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.bug_report,
                  title: 'Докладвай бъг',
                  bgColor: Colors.amber.shade100,
                  iconColor: Colors.amber.shade800,
                  showArrow: false,
                  onTap: () async {
                    final Uri url = Uri.parse('https://docs.google.com/forms/d/e/1FAIpQLSeKRNV4sLmj01Y2J7yV_mpMXzXY-cZmusRzNL8guFPOl7Kf9Q/viewform?usp=header');
                    if (!await launchUrl(url)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Не може да се отвори връзката",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
    bool showArrow = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      leading: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: showArrow ? const Icon(Icons.arrow_forward_ios, size: 16.0, color: Colors.grey) : null,
      onTap: onTap,
    );
  }
}

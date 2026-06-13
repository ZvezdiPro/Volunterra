import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  Future<void> _resetPassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Имейл за смяна на парола е изпратен.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: greenPrimary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Възникна грешка: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isOrganizer = false;
    final organizerOrUser = await DatabaseService(uid: user.uid).getOrganizer();
    if (organizerOrUser is NGO) {
      isOrganizer = true;
    } else if (organizerOrUser is VolunteerUser) {
      isOrganizer = organizerOrUser.isOrganizer;
    }

    String warningText = 'Сигурни ли сте, че искате да закриете профила си? Това действие е необратимо и ще изтрие всички ваши данни.';
    if (isOrganizer) {
      warningText += ' Това включва и кампаниите, на които сте организатор.';
    }

    if (!context.mounted) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.red.shade50,
          title: const Text('Закриване на профила', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            warningText,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отказ', style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Закрий', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      try {
        final uid = user.uid;
        
        // Delete from Firestore
        await DatabaseService(uid: uid).deleteUserData();
        
        // Delete Auth User
        await user.delete();

        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } on FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login' && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Моля, влезте отново в профила си, за да извършите това действие.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.red,
              ),
            );
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Грешка: $e')),
            );
          }
        } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Грешка: $e')),
          );
        }
      }
    }
  }

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
        title: const Text('Настройки на профила', style: appBarHeadingStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardGrey,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                StreamBuilder<VolunteerUser>(
                  stream: DatabaseService(uid: FirebaseAuth.instance.currentUser?.uid).volunteerUserData,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox.shrink();
                    final bool isPublic = snapshot.data?.showEmailPublicly ?? false;
                    return Column(
                      children: [
                        SwitchListTile(
                          activeTrackColor: greenPrimary.withAlpha(100),
                          activeThumbColor: greenPrimary,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                          secondary: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(8.0)),
                            child: const Icon(Icons.email, color: Colors.blue),
                          ),
                          title: const Text('Публичен имейл', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Показване на имейла на други потребители', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          value: isPublic,
                          onChanged: (val) {
                            DatabaseService(uid: FirebaseAuth.instance.currentUser?.uid).updateEmailVisibility(val);
                          },
                        ),
                        const Divider(height: 1, indent: 30, endIndent: 30),
                      ]
                    );
                }
              ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.lock,
                  title: 'Смяна на парола',
                  bgColor: Colors.orange.shade100,
                  iconColor: Colors.orange,
                  showArrow: false,
                  onTap: () => _resetPassword(context),
                ),
                const Divider(height: 1, indent: 30, endIndent: 30),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.delete_forever,
                  title: 'Закриване на профила',
                  bgColor: Colors.red.shade100,
                  iconColor: Colors.red,
                  showArrow: false,
                  onTap: () => _deleteAccount(context),
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
    Color? textColor,
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
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      trailing: showArrow
          ? const Icon(Icons.arrow_forward_ios, size: 16.0, color: Colors.grey)
          : null,
      onTap: onTap,
    );
  }
}

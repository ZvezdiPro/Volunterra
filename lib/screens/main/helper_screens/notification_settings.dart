import 'package:flutter/material.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class NotificationSettingsPage extends StatefulWidget {
  final String uid;

  const NotificationSettingsPage({super.key, required this.uid});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  Map<String, bool> _settings = {};
  bool _isNgo = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final organizer = await DatabaseService(uid: widget.uid).getOrganizer();
    if (mounted) {
      setState(() {
        if (organizer is NGO) {
          _isNgo = true;
          _settings = Map.from(organizer.notificationSettings);
        } else if (organizer is VolunteerUser) {
          _isNgo = false;
          _settings = Map.from(organizer.notificationSettings);
        }
        _isLoading = false;
      });
    }
  }

  bool _getValue(String key) {
    return _settings[key] ?? true;
  }

  void _onSwitchChanged(String key, bool value) async {
    setState(() {
      _settings[key] = value;
    });

    await DatabaseService(uid: widget.uid).updateNotificationSettings(_settings, _isNgo);
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
          onPressed: () {
             Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: const Text('Настройки за известия', style: appBarHeadingStyle),
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: blueSecondary))
          : Stack(
          children: [
            ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildSection('Общи настройки', [
                  _buildSwitchTile('Нови кампании във вашия район', 'new_campaign'),
                  _buildSwitchTile('Напомняне за започващи кампании', 'starting_soon'),
                ]),
                if (!_isNgo)
                  _buildSection('Кампании, в които участвате', [
                    _buildSwitchTile('Промени в кампанията', 'campaign_update'),
                    _buildSwitchTile('Прекратяване на кампания', 'campaign_ended'),
                    _buildSwitchTile('Нови съобщения в чата', 'chat_message'),
                  ]),
                
                _buildSection('За организатори', [
                  _buildSwitchTile('Записване / отписване на доброволец', 'registration'),
                  _buildSwitchTile('Постигната цел брой доброволци', 'goal_reached'),
                  _buildSwitchTile('Променени права и собственост', 'role_update'),
                ]),

                if (_isNgo) 
                  _buildSection('За организации', [
                    _buildSwitchTile('Нови последователи', 'new_follower'),
                  ]),
              ],
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: blueSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    
    // Add dividers between items
    List<Widget> separatedChildren = [];
    for (int i = 0; i < children.length; i++) {
      separatedChildren.add(children[i]);
      if (i < children.length - 1) {
        separatedChildren.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 5),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: cardGrey,
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 5, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: separatedChildren,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String key) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      trailing: Transform.scale(
        scale: 0.75,
        child: Switch(
          value: _getValue(key),
          activeThumbColor: blueSecondary,
          onChanged: (value) => _onSwitchChanged(key, value),
        ),
      ),
      onTap: () => _onSwitchChanged(key, !_getValue(key)),
    );
  }
}

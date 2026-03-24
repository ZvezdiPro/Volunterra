import 'package:flutter/material.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:volunteer_app/screens/main/helper_screens/public_ngo_screen.dart';
import 'package:volunteer_app/screens/main/helper_screens/public_profile_screen.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';

class CampaignParticipantsScreen extends StatefulWidget {
  final Campaign campaign;

  const CampaignParticipantsScreen({super.key, required this.campaign});

  @override
  State<CampaignParticipantsScreen> createState() => _CampaignParticipantsScreenState();
}

class _CampaignParticipantsScreenState extends State<CampaignParticipantsScreen> {
  final DatabaseService _db = DatabaseService();
  List<VolunteerUser>? _volunteers;
  Object? _organizer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVolunteers();
  }

  Future<void> _loadVolunteers() async {
    try {
      final organizer = await DatabaseService(uid: widget.campaign.organizerId).getOrganizer();
      final volunteers = await _db.getVolunteersFromList(widget.campaign.registeredVolunteersUids);
      
      // Remove organizer from volunteers list to avoid duplicate
      volunteers.removeWhere((v) => v.uid == widget.campaign.organizerId);

      // Sort logic
      volunteers.sort((a, b) {
        final aIsCoorg = widget.campaign.coorganizersIds.contains(a.uid);
        final bIsCoorg = widget.campaign.coorganizersIds.contains(b.uid);
        
        if (aIsCoorg && !bIsCoorg) return -1;
        if (!aIsCoorg && bIsCoorg) return 1;
        
        return a.firstName.compareTo(b.firstName);
      });

      if (mounted) {
        setState(() {
          _organizer = organizer;
          _volunteers = volunteers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: const Text(
          "Участници",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: greenPrimary))
        : (_volunteers == null || _volunteers!.isEmpty)
            ? const Center(child: Text("Няма участници.", style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 0),
                itemCount: _volunteers!.length + (_organizer != null ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0 && _organizer != null) {
                    final isNgo = _organizer is NGO;
                    final isVolunteer = _organizer is VolunteerUser;
                    final String name = isNgo ? (_organizer as NGO).name : (isVolunteer ? "${(_organizer as VolunteerUser).firstName} ${(_organizer as VolunteerUser).lastName}" : "Неизвестен");
                    final String email = isNgo ? (_organizer as NGO).email : (isVolunteer ? (_organizer as VolunteerUser).email : "");
                    final String? avatarUrl = isNgo ? (_organizer as NGO).logoUrl : (isVolunteer ? (_organizer as VolunteerUser).avatarUrl : null);
                    final String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

                    return Container(
                      decoration: BoxDecoration(
                        color: backgroundGrey,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null ? Text(initial, style: const TextStyle(color: greenPrimary, fontWeight: FontWeight.bold)) : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: accentAmber.withAlpha(30), borderRadius: BorderRadius.circular(6)),
                              child: const Text("Организатор", style: TextStyle(color: accentAmber, fontSize: 10, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        subtitle: Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () {
                           if (isNgo) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => PublicNgoScreen(ngo: _organizer as NGO)));
                           } else if (isVolunteer) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfileScreen(volunteer: _organizer as VolunteerUser)));
                           }
                        },
                      ),
                    );
                  }

                  final userIndex = _organizer != null ? index - 1 : index;
                  final user = _volunteers![userIndex];
                  final isCoorganizer = widget.campaign.coorganizersIds.contains(user.uid);
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: backgroundGrey,
                      border: userIndex == _volunteers!.length - 1
                          ? null
                          : Border(
                              bottom: BorderSide(color: Colors.grey.shade300, width: 1.5),
                            ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 5,
                      ),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: user.avatarUrl != null
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Text(
                                user.firstName[0],
                                style: const TextStyle(
                                  color: greenPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${user.firstName} ${user.lastName}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCoorganizer)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: blueSecondary.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "Съорганизатор",
                                style: TextStyle(color: blueSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            )
                        ],
                      ),
                      subtitle: Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublicProfileScreen(volunteer: user),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
    );
  }
}

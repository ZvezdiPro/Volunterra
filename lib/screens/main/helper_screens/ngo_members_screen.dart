import 'package:flutter/material.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/screens/main/helper_screens/public_profile_screen.dart';

class NgoMembersScreen extends StatefulWidget {
  final NGO ngo;

  const NgoMembersScreen({super.key, required this.ngo});

  @override
  State<NgoMembersScreen> createState() => _NgoMembersScreenState();
}

class _NgoMembersScreenState extends State<NgoMembersScreen> {
  late Future<List<VolunteerUser>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  void _fetchMembers() {
    // Combine members and admins, making sure we don't have duplicates
    final Set<String> allUids = {};
    allUids.addAll(widget.ngo.admins);
    allUids.addAll(widget.ngo.members);
    
    // Ignore the NGO's own ID if it's in the list
    allUids.remove(widget.ngo.id);

    if (allUids.isEmpty) {
      _membersFuture = Future.value([]);
    } else {
      _membersFuture = DatabaseService().getVolunteersFromList(allUids.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: const Text('Членове', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: FutureBuilder<List<VolunteerUser>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: greenPrimary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Грешка при зареждане на членовете: ${snapshot.error}'));
          }

          final members = snapshot.data ?? [];

          if (members.isEmpty) {
            return const Center(
              child: Text('Няма намерени членове за тази огранизация.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          // Sort members: admins first, then alphabetically
          members.sort((a, b) {
            final aIsAdmin = widget.ngo.admins.contains(a.uid);
            final bIsAdmin = widget.ngo.admins.contains(b.uid);
            if (aIsAdmin && !bIsAdmin) return -1;
            if (!aIsAdmin && bIsAdmin) return 1;
            return '${a.firstName} ${a.lastName}'.toLowerCase().compareTo('${b.firstName} ${b.lastName}'.toLowerCase());
          });

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final String fullName = '${member.firstName} ${member.lastName}'.trim();
              final bool isAdmin = widget.ngo.admins.contains(member.uid);
              
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 16.0, right: 12.0, top: 4.0, bottom: 4.0),
                  leading: CircleAvatar(
                    backgroundColor: blueSecondary,
                    backgroundImage: member.avatarUrl != null && member.avatarUrl!.isNotEmpty 
                        ? NetworkImage(member.avatarUrl!) 
                        : null,
                    child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                        ? Text(member.firstName[0], style: const TextStyle(color: Colors.white))
                        : null,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          fullName.isEmpty ? 'Анонимен потребител' : fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isAdmin)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentAmber.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Администратор',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentAmber),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(member.email, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfileScreen(volunteer: member),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

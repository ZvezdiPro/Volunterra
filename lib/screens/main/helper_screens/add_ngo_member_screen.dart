import 'package:flutter/material.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/screens/main/helper_screens/public_profile_screen.dart';
import 'package:volunteer_app/shared/constants.dart';

class AddNgoMemberScreen extends StatefulWidget {
  final String ngoId;
  final List<String> currentMemberIds;
  
  const AddNgoMemberScreen({
    super.key,
    required this.ngoId,
    required this.currentMemberIds,
  });

  @override
  State<AddNgoMemberScreen> createState() => _AddNgoMemberScreenState();
}

class _AddNgoMemberScreenState extends State<AddNgoMemberScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<VolunteerUser> _searchResults = [];
  bool _isLoading = false;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() { _searchResults = []; _isLoading = false; });
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final results = await _db.searchVolunteers(query.trim());
      if (mounted) {
        setState(() {
          // Filter out users who are already members
          _searchResults = results.where((u) => !widget.currentMemberIds.contains(u.uid)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Грешка при търсене: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmAddMember(VolunteerUser user) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Добавяне на член"),
        content: Text("Искате ли да добавите ${user.firstName} ${user.lastName} към вашата организация?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Отказ"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Добави", style: TextStyle(color: greenPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      try {
        await DatabaseService(uid: widget.ngoId).addNgoMember(user.uid);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Успешно добавен член!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: greenPrimary,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate a member was added
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Грешка при добавяне: $e"), backgroundColor: Colors.red),
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
        title: const Text("Добави членове", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: searchBarInputDecoration.copyWith(
                hintText: "Търсене по име или имейл...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                ),
              ),
              onChanged: (value) {
                _performSearch(value);
              },
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty 
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? "Въведете име за търсене"
                              : "Няма намерени резултати",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 1,
                            child: ListTile(
                              contentPadding: const EdgeInsets.only(left: 16.0, right: 12.0, top: 4.0, bottom: 4.0),
                              leading: CircleAvatar(
                                backgroundColor: blueSecondary,
                                backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                                child: user.avatarUrl == null ? Text(user.firstName[0], style: const TextStyle(color: Colors.white)) : null,
                              ),
                              title: Text("${user.firstName} ${user.lastName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(user.email),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_add, color: greenPrimary),
                                onPressed: () => _confirmAddMember(user),
                              ),
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
          ),
        ],
      ),
    );
  }
}

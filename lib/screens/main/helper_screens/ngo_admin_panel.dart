import 'package:flutter/material.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';
import 'package:volunteer_app/screens/main/helper_screens/add_ngo_member_screen.dart';
import 'package:volunteer_app/screens/main/helper_screens/public_profile_screen.dart';

class NgoAdminPanel extends StatefulWidget {
  final NGO ngo;

  const NgoAdminPanel({super.key, required this.ngo});

  @override
  State<NgoAdminPanel> createState() => _NgoAdminPanelState();
}

class _NgoAdminPanelState extends State<NgoAdminPanel> {
  final DatabaseService _db = DatabaseService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _websiteController;
  late TextEditingController _fbController;
  late TextEditingController _igController;

  bool _hasChanges = false;
  bool _isSaving = false;
  
  List<VolunteerUser>? _members;
  bool _isLoadingMembers = true;
  late NGO _currentNgo;

  @override
  void initState() {
    super.initState();
    _currentNgo = widget.ngo;
    
    _nameController = TextEditingController(text: _currentNgo.name);
    _descriptionController = TextEditingController(text: _currentNgo.description);
    _emailController = TextEditingController(text: _currentNgo.email);
    _phoneController = TextEditingController(text: _currentNgo.phone);
    _addressController = TextEditingController(text: _currentNgo.address);
    _websiteController = TextEditingController(text: _currentNgo.website ?? '');
    
    _fbController = TextEditingController(text: _currentNgo.socialLinks['facebook'] ?? '');
    _igController = TextEditingController(text: _currentNgo.socialLinks['instagram'] ?? '');

    _loadMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _fbController.dispose();
    _igController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      if (_currentNgo.members.isEmpty) {
        if (mounted) setState(() { _members = []; _isLoadingMembers = false; });
        return;
      }
      List<VolunteerUser> users = await _db.getVolunteersFromList(_currentNgo.members);
      if (mounted) {
        setState(() {
          _members = users;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      Map<String, String> socialLinks = {};
      if (_fbController.text.trim().isNotEmpty) socialLinks['facebook'] = _fbController.text.trim();
      if (_igController.text.trim().isNotEmpty) socialLinks['instagram'] = _igController.text.trim();

      Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'website': _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        'socialLinks': socialLinks,
      };

      await DatabaseService(uid: _currentNgo.id).updateNgoInfo(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: greenPrimary,
            content: Center(child: Text("Промените са запазени успешно!", style: TextStyle(fontWeight: FontWeight.bold))),
          ),
        );
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Грешка: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Незапазени промени'),
        content: const Text('Имате незапазени промени. Сигурни ли сте, че искате да напуснете?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Отказ', style: TextStyle(color: Colors.black87))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Напусни', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  Future<void> _confirmRemoveMember(VolunteerUser user) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Премахване на член"),
        content: Text("Сигурни ли сте, че искате да премахнете ${user.firstName} от огранизацията?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Отказ")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Премахни", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      try {
        await DatabaseService(uid: _currentNgo.id).removeNgoMember(user.uid);
        setState(() {
          _members!.removeWhere((m) => m.uid == user.uid);
          _currentNgo.members.remove(user.uid);
        });
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Грешка: $e")));
      }
    }
  }

  void _navigateToAddMembers() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddNgoMemberScreen(
          ngoId: _currentNgo.id,
          currentMemberIds: _currentNgo.members,
        ),
      ),
    );

    if (result == true) {
      // Reload NGO to get new members and then reload members list
      final updatedNgo = await DatabaseService(uid: widget.ngo.id).getNgo();
      if (updatedNgo != null && mounted) {
        setState(() {
          _currentNgo = updatedNgo;
        });
        _loadMembers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldLeave = await _showExitConfirmationDialog();
        if (shouldLeave && context.mounted) {
          setState(() => _hasChanges = false);
          Navigator.of(context).pop();
        }
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: backgroundGrey,
          appBar: AppBar(
            title: const Text("Управлявай НПО", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: const IconThemeData(color: Colors.black87),
            bottom: const TabBar(
              labelColor: greenPrimary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: greenPrimary,
              tabs: [
                Tab(text: "Детайли"),
                Tab(text: "Членове"),
              ],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              children: [
                _buildGeneralTab(),
                _buildMembersTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Основна информация", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("Променете основните детайли на организацията", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 20),

            _buildTextField('Име на организацията', _nameController, "Напр. Фондация Заедно", maxLength: 50),
            _buildTextField('Описание', _descriptionController, "Кратко описание...", maxLines: 4, maxLength: 500),
            
            const SizedBox(height: 10),
            const Text("Контакти", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _buildTextField('Имейл', _emailController, "contact@example.com", keyboardType: TextInputType.emailAddress),
            _buildTextField('Телефон', _phoneController, "+359888888888", keyboardType: TextInputType.phone),
            _buildTextField('Адрес', _addressController, "Град, Улица..."),
            _buildTextField('Уебсайт', _websiteController, "https://example.com", isRequired: false),
            
            const SizedBox(height: 10),
            const Text("Социални мрежи", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildTextField('Facebook профил', _fbController, "Напр. volunteersBG", isRequired: false),
            _buildTextField('Instagram профил', _igController, "Напр. volunteersBG", isRequired: false),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_hasChanges && !_isSaving) ? _saveChanges : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Запази промените", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1, int? maxLength, bool isRequired = true, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textFormFieldHeading),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          decoration: textInputDecoration.copyWith(
            hintText: hint,
            counterText: "",
            fillColor: Colors.white,
          ),
          onChanged: (_) => _onFieldChanged(),
          validator: isRequired ? (val) {
            if (val == null || val.isEmpty) return 'Това поле е задължително';
            return null;
          } : null,
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildMembersTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Списък с членове", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          Expanded(
            child: _isLoadingMembers
              ? const Center(child: CircularProgressIndicator())
              : (_members == null || _members!.isEmpty)
                  ? Center(child: Text("Няма добавени членове.", style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                      itemCount: _members!.length,
                      itemBuilder: (context, index) {
                        final vol = _members![index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 1,
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(left: 16.0, right: 12.0, top: 4.0, bottom: 4.0),
                            leading: CircleAvatar(
                              backgroundColor: blueSecondary,
                              backgroundImage: vol.avatarUrl != null ? NetworkImage(vol.avatarUrl!) : null,
                              child: vol.avatarUrl == null ? Text(vol.firstName[0], style: const TextStyle(color: Colors.white)) : null,
                            ),
                            title: Text("${vol.firstName} ${vol.lastName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(vol.email),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_remove, color: Colors.red),
                              tooltip: "Премахни от организацията",
                              onPressed: () => _confirmRemoveMember(vol),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PublicProfileScreen(volunteer: vol),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _navigateToAddMembers,
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text("Добави членове", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: blueSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

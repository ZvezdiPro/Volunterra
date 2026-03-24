import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
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
  final ImagePicker _picker = ImagePicker();

  File? _newLogo;
  File? _newCoverImage;

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
  
  List<VolunteerUser>? _followers;
  bool _isLoadingFollowers = true;

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
    _loadFollowers();
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

  Future<void> _pickImage(bool isLogo) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        setState(() {
          if (isLogo) {
            _newLogo = File(image.path);
          } else {
            _newCoverImage = File(image.path);
          }
          _hasChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Грешка при избиране на изображение: $e")));
      }
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
      
      // Sort so admins are at the top
      users.sort((a, b) {
        final aIsAdmin = _currentNgo.admins.contains(a.uid);
        final bIsAdmin = _currentNgo.admins.contains(b.uid);
        if (aIsAdmin && !bIsAdmin) return -1;
        if (!aIsAdmin && bIsAdmin) return 1;
        return a.firstName.compareTo(b.firstName);
      });

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

  Future<void> _loadFollowers() async {
    setState(() => _isLoadingFollowers = true);
    try {
      if (_currentNgo.followers.isEmpty) {
        if (mounted) setState(() { _followers = []; _isLoadingFollowers = false; });
        return;
      }
      List<VolunteerUser> users = await _db.getVolunteersFromList(_currentNgo.followers);
      if (mounted) {
        setState(() {
          _followers = users;
          _isLoadingFollowers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFollowers = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasChanges) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      String? updatedLogoUrl;
      String? updatedCoverUrl;

      if (_newLogo != null) {
        Reference ref = FirebaseStorage.instance.ref().child('ngo_branding/${_currentNgo.id}/logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_newLogo!);
        updatedLogoUrl = await ref.getDownloadURL();
        
        if (_currentNgo.logoUrl != null && _currentNgo.logoUrl!.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(_currentNgo.logoUrl!).delete();
          } catch (e) {
            debugPrint("Error deleting old logo: $e");
          }
        }
      }

      if (_newCoverImage != null) {
        Reference ref = FirebaseStorage.instance.ref().child('ngo_branding/${_currentNgo.id}/cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_newCoverImage!);
        updatedCoverUrl = await ref.getDownloadURL();
        
        if (_currentNgo.coverImageUrl != null && _currentNgo.coverImageUrl!.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(_currentNgo.coverImageUrl!).delete();
          } catch (e) {
            debugPrint("Error deleting old cover: $e");
          }
        }
      }

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

      if (updatedLogoUrl != null) updateData['logoUrl'] = updatedLogoUrl;
      if (updatedCoverUrl != null) updateData['coverImageUrl'] = updatedCoverUrl;

      await DatabaseService(uid: _currentNgo.id).updateNgoInfo(updateData);
      
      final updatedNgo = await DatabaseService(uid: _currentNgo.id).getNgo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: greenPrimary,
            content: Center(child: Text("Промените са запазени успешно!", style: TextStyle(fontWeight: FontWeight.bold))),
          ),
        );
        setState(() {
          if (updatedNgo != null) {
            _currentNgo = updatedNgo;
          }
          _newLogo = null;
          _newCoverImage = null;
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
        
        // Also remove admin rights if they were removed from the org
        if (_currentNgo.admins.contains(user.uid)) {
          await DatabaseService(uid: _currentNgo.id).removeNgoAdmin(user.uid);
          _currentNgo.admins.remove(user.uid);
        }

        setState(() {
          _members!.removeWhere((m) => m.uid == user.uid);
          _currentNgo.members.remove(user.uid);
        });
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Грешка: $e")));
      }
    }
  }

  Future<void> _toggleAdminStatus(VolunteerUser user) async {
    if (user.uid == _currentNgo.ownerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не можете да промените правата на създателя на организацията.")),
      );
      return;
    }

    final bool isAdmin = _currentNgo.admins.contains(user.uid);
    final String actionText = isAdmin ? "премахнете администраторските права на" : "направите администратор";
    
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Промяна на права"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Сигурни ли сте, че искате да $actionText ${user.firstName}?"),
            if (!isAdmin) ...[
              const SizedBox(height: 10),
              const Text("Новият администратор ще може да:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text("• Добавя и премахва членове"),
              const SizedBox(height: 2),
              const Text("• Изпраща съобщения в инфо канала"),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Отказ", style: TextStyle(color: Colors.black87))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Потвърди", style: TextStyle(fontWeight: FontWeight.bold, color: greenPrimary))),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      try {
        if (isAdmin) {
          await DatabaseService(uid: _currentNgo.id).removeNgoAdmin(user.uid);
          setState(() {
            _currentNgo.admins.remove(user.uid);
          });
        } else {
          await DatabaseService(uid: _currentNgo.id).addNgoAdmin(user.uid);
          setState(() {
            _currentNgo.admins.add(user.uid);
          });
        }
        _loadMembers();
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
        length: 3,
        child: Scaffold(
          backgroundColor: backgroundGrey,
          appBar: AppBar(
            title: Text("Управлявай ${_currentNgo.name}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
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
                Tab(text: "Последователи"),
              ],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              children: [
                _buildGeneralTab(),
                _buildMembersTab(),
                _buildFollowersTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    final userObj = Provider.of<Object?>(context);
    final isNgoOwner = userObj is NGO && userObj.id == _currentNgo.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isNgoOwner) _buildBrandingSection(),
            const Text("Основна информация", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(isNgoOwner ? "Променете основните детайли на организацията" : "Основни детайли на организацията", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            
            if (!isNgoOwner) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Забележка: Редактирането на тези полета може да се извършва само от акаунта на организацията.",
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            _buildTextField('Име на организацията', _nameController, "Напр. Фондация Заедно", maxLength: 50, isEnabled: isNgoOwner),
            _buildTextField('Описание', _descriptionController, "Кратко описание...", maxLines: 4, maxLength: 500, isEnabled: isNgoOwner),
            
            const SizedBox(height: 10),
            const Text("Контакти", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _buildTextField('Имейл', _emailController, "contact@example.com", keyboardType: TextInputType.emailAddress, isEnabled: isNgoOwner),
            _buildTextField('Телефон', _phoneController, "+359888888888", keyboardType: TextInputType.phone, isEnabled: isNgoOwner),
            _buildTextField('Адрес', _addressController, "Град, Улица...", isEnabled: isNgoOwner),
            _buildTextField('Уебсайт', _websiteController, "https://example.com", isRequired: false, isEnabled: isNgoOwner),
            
            const SizedBox(height: 10),
            const Text("Социални мрежи", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildTextField('Facebook профил', _fbController, "Напр. volunteersBG", isRequired: false, isEnabled: isNgoOwner),
            _buildTextField('Instagram профил', _igController, "Напр. volunteersBG", isRequired: false, isEnabled: isNgoOwner),

            if (isNgoOwner) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_hasChanges && !_isSaving) ? _saveChanges : null,
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : const Icon(Icons.save, color: Colors.white),
                  label: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Запази промените",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greenPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Визия (лого и банер)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover Image
            GestureDetector(
              onTap: () => _pickImage(false),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: _newCoverImage != null
                      ? DecorationImage(image: FileImage(_newCoverImage!), fit: BoxFit.cover)
                      : (_currentNgo.coverImageUrl != null
                          ? DecorationImage(image: CachedNetworkImageProvider(_currentNgo.coverImageUrl!), fit: BoxFit.cover)
                          : null),
                ),
                child: (_newCoverImage == null && _currentNgo.coverImageUrl == null)
                    ? const Center(child: Icon(Icons.photo_size_select_actual_outlined, size: 40, color: Colors.grey))
                    : null,
              ),
            ),
            // Edit Overlay for Cover
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withAlpha(128),
                radius: 18,
                child: IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                  onPressed: () => _pickImage(false),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            // Logo Image
            Positioned(
              bottom: -40,
              left: 20,
              child: GestureDetector(
                onTap: () => _pickImage(true),
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ClipOval(
                        child: _newLogo != null
                            ? Image.file(_newLogo!, fit: BoxFit.cover)
                            : (_currentNgo.logoUrl != null
                                ? CachedNetworkImage(imageUrl: _currentNgo.logoUrl!, fit: BoxFit.cover)
                                : Container(
                                    color: Colors.grey[100],
                                    child: const Center(child: Icon(Icons.business, size: 40, color: greenPrimary)),
                                  )),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: blueSecondary,
                        radius: 14,
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 60), // Spacing for the overlapping logo
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1, int? maxLength, bool isRequired = true, TextInputType? keyboardType, bool isEnabled = true}) {
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
          enabled: isEnabled,
          decoration: textInputDecoration.copyWith(
            hintText: hint,
            counterText: "",
            fillColor: isEnabled ? Colors.white : Colors.grey[100],
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
    final userObj = Provider.of<Object?>(context);
    final isNgoOwner = userObj is NGO && userObj.id == _currentNgo.id;

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
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${vol.firstName} ${vol.lastName}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_currentNgo.admins.contains(vol.uid))
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: accentAmber.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "Администратор",
                                      style: TextStyle(color: accentAmber, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                              ],
                            ),
                            subtitle: Text(vol.email, style: TextStyle(color: Colors.grey[600])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isNgoOwner)
                                  IconButton(
                                    icon: Icon(
                                      _currentNgo.admins.contains(vol.uid) ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
                                      color: _currentNgo.admins.contains(vol.uid) ? accentAmber : Colors.grey,
                                    ),
                                    tooltip: _currentNgo.admins.contains(vol.uid) ? "Премахни администратор" : "Направи администратор",
                                    onPressed: () => _toggleAdminStatus(vol),
                                  ),
                                if (isNgoOwner || !_currentNgo.admins.contains(vol.uid))
                                  IconButton(
                                    icon: const Icon(Icons.person_remove, color: Colors.red),
                                    tooltip: "Премахни от организацията",
                                    onPressed: () => _confirmRemoveMember(vol),
                                  ),
                              ],
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
  Widget _buildFollowersTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Списък с последователи", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          Expanded(
            child: _isLoadingFollowers
              ? const Center(child: CircularProgressIndicator())
              : (_followers == null || _followers!.isEmpty)
                  ? Center(child: Text("Все още няма последователи.", style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                      itemCount: _followers!.length,
                      itemBuilder: (context, index) {
                        final vol = _followers![index];
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
        ],
      ),
    );
  }
}

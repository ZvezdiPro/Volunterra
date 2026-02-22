import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class EditProfileScreen extends StatefulWidget {
  final VolunteerUser volunteer;
  const EditProfileScreen({super.key, required this.volunteer});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers for form fields
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _bioController;
  late List<String> _interests;
  bool _isInitialized = false;

  // Image picker state
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  String? _newAvatarUrl;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.volunteer.firstName);
    _lastNameController = TextEditingController(text: widget.volunteer.lastName);
    _bioController = TextEditingController(text: widget.volunteer.bio);
    _interests = List<String>.from(widget.volunteer.interests);
  }

  void _initializeData(VolunteerUser user) {
    if (!_isInitialized) {
      _firstNameController = TextEditingController(text: user.firstName);
      _lastNameController = TextEditingController(text: user.lastName);
      _bioController = TextEditingController(text: user.bio);
      _interests = List<String>.from(user.interests);
      _isInitialized = true;
    }
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      await DatabaseService(uid: widget.volunteer.uid).editUserProfileData(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        bio: _bioController.text,
        interests: _interests,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(
            child: Text(
              'Промените са запазени успешно!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          backgroundColor: greenPrimary,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pop(context);
    }
  }

  Future<void> _handlePhotoChange() async {
    try {
      // If the user decides to upload a new photo, we delete the old one
      String? urlToDelete = _newAvatarUrl ?? widget.volunteer.avatarUrl;

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 50
      );
      
      if (pickedFile == null) return;
      
      if (!mounted) return;

      setState(() {
        _isUploadingImage = true;
      });

      String path = 'avatars/${widget.volunteer.uid}';
      String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      String? downloadUrl = await DatabaseService(uid: widget.volunteer.uid).uploadImage(path, pickedFile, fileName);

      if (!mounted) return;

      if (downloadUrl != null) {
        await DatabaseService(uid: widget.volunteer.uid).updateUserAvatar(downloadUrl);
        
        if (mounted) {
          setState(() {
            _newAvatarUrl = downloadUrl;
            _isUploadingImage = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Снимката е обновена!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
          );
        }
        
        if (urlToDelete != null && urlToDelete.isNotEmpty) {
          await DatabaseService(uid: widget.volunteer.uid).deleteImage(urlToDelete);
        }
      } else {
        throw Exception('Неуспешно качване');
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Грешка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> availableInterests = [
      'Образование', 'Екология', 'Животни', 'Грижа за деца', 'Спорт', 'Здраве',
      'Грижа за възрастни', 'Изкуство и култура', 'Помощ в извънредни ситуации'
    ];    

    return FutureBuilder<VolunteerUser?>(
      future: DatabaseService(uid: widget.volunteer.uid).getVolunteerUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isInitialized) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData) {
          _initializeData(snapshot.data!);
          
            return Scaffold(
            backgroundColor: backgroundGrey,

            // Edit Profile App Bar
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Редакция на профила', style: appBarHeadingStyle),
              centerTitle: true,
              backgroundColor: backgroundGrey,
              elevation: 0,
            ),

            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile picture and change button
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _newAvatarUrl != null
                                  ? NetworkImage(_newAvatarUrl!)
                                  : (widget.volunteer.avatarUrl != null && widget.volunteer.avatarUrl!.isNotEmpty)
                                      ? NetworkImage(widget.volunteer.avatarUrl!)
                                      : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider,
                                child: _isUploadingImage
                                  ? const CircularProgressIndicator(color: greenPrimary)
                                  : null,
                              ),
                              if (!_isUploadingImage)
                                GestureDetector(
                                  onTap: _handlePhotoChange,
                                  child: const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: greenPrimary,
                                    child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                  ),
                                ),
                            ],
                          ),
                          TextButton(
                            onPressed: _isUploadingImage ? null : _handlePhotoChange,
                            child: Text(
                              _isUploadingImage ? 'Качване...' : 'Смени снимката',
                              style: const TextStyle(color: greenPrimary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
            
                    // First and Last Name inputs
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Първо име', _firstNameController)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildTextField('Фамилия', _lastNameController)),
                      ],
                    ),
                    const SizedBox(height: 25),
            
                    // Bio input
                    const Text('Кратка биография', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 300,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
            
                    // Interests selection
                    const Text('Интереси', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      'Изберете до 5 области, в които искате да помагате:',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 15),
            
                    // The list of selectable interests
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: availableInterests.map((interest) {
                        final isSelected = _interests.contains(interest);
                        return FilterChip(
                          label: Text(interest),
                          selected: isSelected,
                          backgroundColor: Colors.grey[50],
                          selectedColor: greenPrimary,
                          showCheckmark: true,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? greenPrimary : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                if (_interests.length < 5) {
                                  _interests.add(interest);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Можете да изберете до 5 интереса!'),
                                      backgroundColor: greenPrimary,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } else {
                                _interests.remove(interest);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Save changes button
            bottomNavigationBar: SafeArea(
              top: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: greenPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _saveChanges,
                    child: const Text('Запази промените', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          );
        }

        return const Scaffold(body: Center(child: Text('Грешка при зареждането на данните.')));
      },
    );
  }

  // Text field builder
  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: (val) => val!.isEmpty ? 'Задължително' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
      ],
    );
  }
}
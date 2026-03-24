import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:volunteer_app/models/ngo_registration_data.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class NgoRegisterStepFour extends StatefulWidget {
  final NgoRegistrationData data;
  final GlobalKey<FormState> formKey;

  const NgoRegisterStepFour({
    super.key, 
    required this.data,
    required this.formKey
  });

  @override
  State<NgoRegisterStepFour> createState() => _NgoRegisterStepFourState();
}

class _NgoRegisterStepFourState extends State<NgoRegisterStepFour> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickLogo() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final String extension = image.path.split('.').last.toLowerCase();
      if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Моля, изберете изображение във формат JPG или PNG.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      File file = File(image.path);
      int sizeInBytes = file.lengthSync();
      if (sizeInBytes > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Логото е твърде голямо! Максималният размер е 5 MB.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() {
        widget.data.logoImage = image;
      });
    }
  }

  Future<void> _pickBanner() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final String extension = image.path.split('.').last.toLowerCase();
      if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Моля, изберете изображение във формат JPG или PNG.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      File file = File(image.path);
      int sizeInBytes = file.lengthSync();
      if (sizeInBytes > 10 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Банерът е твърде голям! Максималният размер е 10 MB.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      setState(() {
        widget.data.bannerImage = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 40.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 20.0),
            Text('Стъпка 4: Визия', style: mainHeadingStyle),
            SizedBox(height: 10.0),
            Text('Добавете лого и банер към профила си (може да ги пропуснете и добавите по-късно).', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
            SizedBox(height: 30.0),

            // Logo Picker
            Text('Лого', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 10),
            if (widget.data.logoImage != null)
              Container(
                height: 120,
                width: 120,
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: FileImage(File(widget.data.logoImage!.path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: Text(
                widget.data.logoImage == null ? 'Качете лого (Опционално)' : 'Смени лого', 
                style: const TextStyle(color: Colors.white)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: greenPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _pickLogo,
            ),
            
            SizedBox(height: 30.0),

            // Banner Picker
            Text('Банер', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 10),
            if (widget.data.bannerImage != null)
              Container(
                height: 150,
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: FileImage(File(widget.data.bannerImage!.path)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: Text(
                widget.data.bannerImage == null ? 'Качете банер (Опционално)' : 'Смени банер', 
                style: const TextStyle(color: Colors.white)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: greenPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _pickBanner,
            ),

            SizedBox(height: 40.0),
          ]
        )
      )
    );
  }
}

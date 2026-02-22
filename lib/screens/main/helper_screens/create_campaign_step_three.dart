import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/models/campaign_data.dart';
import 'package:volunteer_app/shared/constants.dart';


class CreateCampaignStepThree extends StatefulWidget {
  final CampaignData data;
  final GlobalKey<FormState> formKey;

  const CreateCampaignStepThree({
    super.key,
    required this.data,
    required this.formKey,
  });

  @override
  State<CreateCampaignStepThree> createState() => _CreateCampaignStepThreeState();
}

class _CreateCampaignStepThreeState extends State<CreateCampaignStepThree> {

  TextEditingController? _volunteerController;

  // State for image handling
  File? _displayImage; 
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _volunteerController?.dispose();
    super.dispose();
  }

  // Function to handle Picking and Uploading images
  Future<void> _handleImageUpload() async {
    try {
      // Pick Image
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile == null) return;

      setState(() {
        _isUploading = true;
        _displayImage = File(pickedFile.path);
      });

      // Upload to Firebase Storage
      String uniquePath = 'campaign_uploads/${DateTime.now().millisecondsSinceEpoch}';
      
      String? downloadUrl = await DatabaseService().uploadImage(uniquePath, pickedFile, null);

      if (!mounted) return;
      
      // Update Campaign Data
      if (downloadUrl != null) {
        setState(() {
          widget.data.imageUrl = downloadUrl;
          _isUploading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Снимката е качена успешно!'), backgroundColor: Colors.green),
        );
      } else {
        throw Exception('Upload failed');
      }

    } catch (e) {
      setState(() {
        _isUploading = false;
        _displayImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Грешка при качване: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.requiredVolunteers <= 0) {
      widget.data.requiredVolunteers = 1;
    }

    // If it is null, we initialise the controller with the same value as the requiredVolunteers field
    _volunteerController ??= TextEditingController(
      text: widget.data.requiredVolunteers.toString(),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 40.0),
      child: Form (
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Heading
            Text('Стъпка 3: Детайли', style: mainHeadingStyle, textAlign: TextAlign.center),
            SizedBox(height: 30.0),
            
            // Required Volunteers
            Text('Необходим брой доброволци', style: textFormFieldHeading),
            SizedBox(height: 10.0),
            FormField<int>(
              initialValue: widget.data.requiredVolunteers,
              validator: (val) {
                if (val == null || val <= 0) {
                  return 'Моля, изберете поне 1 доброволец';
                }
                return null;
              },
              builder: (FormFieldState<int> state) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: state.hasError ? Colors.red : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // The minus button
                          IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            icon: const Icon(Icons.remove_circle_outline, color: greenPrimary),
                            onPressed: () {
                              int current = int.tryParse(_volunteerController!.text) ?? 1;
                              if (current > 1) {
                                int newValue = current - 1;
                                _volunteerController!.text = newValue.toString();
                                state.didChange(newValue);
                                widget.data.requiredVolunteers = newValue;
                              }
                            },
                          ),

                          // The text form field in the middle
                          Expanded(
                            child: TextField(
                              controller: _volunteerController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              onChanged: (val) {
                                int? parsed = int.tryParse(val);
                                if (parsed != null) {
                                  state.didChange(parsed);
                                  widget.data.requiredVolunteers = parsed;
                                } else {
                                  state.didChange(0);
                                }
                              },
                            ),
                          ),

                          // The plus button
                          IconButton(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            icon: const Icon(Icons.add_circle_outline, color: greenPrimary),
                            onPressed: () {
                              int current = int.tryParse(_volunteerController!.text) ?? 0;
                              int newValue = current + 1;
                              _volunteerController!.text = newValue.toString();
                              state.didChange(newValue);
                              widget.data.requiredVolunteers = newValue;
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Error message
                    if (state.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                        child: Text(
                          state.errorText!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
            ),

            SizedBox(height: 20.0),

            // Instructions (optional)
            Text('Инструкции (опционално)', style: textFormFieldHeading),
            SizedBox(height: 10.0),
            TextFormField(
              scrollPadding: EdgeInsets.only(bottom: 130),
              decoration: textInputDecoration.copyWith(labelText: 'Допълнителни инструкции', hintText: 'Например: носете ръкавици и чували'),
              onChanged: (val) => widget.data.instructions = val,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),

            SizedBox(height: 20.0),

            // Upload image (optional)
            Text('Изображение за кампанията', style: textFormFieldHeading),
            SizedBox(height: 10.0),
            ElevatedButton.icon(
              icon: Icon(_isUploading ? Icons.timer : Icons.upload_file, color: Colors.white),
              label: Text(
                _isUploading ? 'Качване...' : (_displayImage == null ? 'Качете изображение' : 'Смени изображение'), 
                style: const TextStyle(color: Colors.white)
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: greenPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isUploading ? null : _handleImageUpload, 
            ),
          ]
        ),
      )
    );
  }
}
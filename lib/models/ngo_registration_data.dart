import 'package:image_picker/image_picker.dart';

class NgoRegistrationData {
  String email = '';
  String password = '';

  String name = '';
  // The equivalent of ЕИК / БУЛСТАТ in Bulgaria
  String registrationNumber = '';
  String description = '';

  String phone = '';
  String website = '';
  String address = '';
  String facebookLink = '';
  String instagramLink = '';

  String logoUrl = '';
  String coverImageUrl = '';
  
  XFile? logoImage;
  XFile? bannerImage;

  // Validation fields
  bool get isStepOneValid => email.isNotEmpty && password.length >= 6;
  bool get isStepTwoValid => name.isNotEmpty && registrationNumber.isNotEmpty && description.isNotEmpty;
  bool get isStepThreeValid => phone.isNotEmpty;
}

import 'package:flutter/material.dart';
import 'package:volunteer_app/models/ngo_registration_data.dart';
import 'package:volunteer_app/shared/constants.dart';

class NgoRegisterStepThree extends StatefulWidget {
  final NgoRegistrationData data;
  final GlobalKey<FormState> formKey;

  const NgoRegisterStepThree({
    super.key, 
    required this.data,
    required this.formKey
  });

  @override
  State<NgoRegisterStepThree> createState() => _NgoRegisterStepThreeState();
}

class _NgoRegisterStepThreeState extends State<NgoRegisterStepThree> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 40.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 60.0),
            Text('Стъпка 3: Контакти', style: mainHeadingStyle),
            SizedBox(height: 20.0),

            TextFormField(
              initialValue: widget.data.phone,
              keyboardType: TextInputType.phone,
              decoration: textInputDecoration.copyWith(hintText: 'Телефонен номер'),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Моля, въведете телефонен номер';
                if (!RegExp(r'^(?:\+359|0)\d{9}$').hasMatch(val)) {
                  return 'Въведете валиден телефонен номер';
                }
                return null;
              },
              onChanged: (val) => widget.data.phone = val, 
            ),

            SizedBox(height: 20.0),

            TextFormField(
              initialValue: widget.data.address,
              decoration: textInputDecoration.copyWith(hintText: 'Адрес / Локация'),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Моля, въведете адрес';
                return null;
              },
              onChanged: (val) => widget.data.address = val, 
            ),

            SizedBox(height: 20.0),

            TextFormField(
              initialValue: widget.data.website,
              keyboardType: TextInputType.url,
              decoration: textInputDecoration.copyWith(hintText: 'Уебсайт (по избор)', hintStyle: TextStyle(color: Colors.grey[600])),
              onChanged: (val) {
                widget.data.website = val;
              },
            ),
            
            SizedBox(height: 20.0),

            TextFormField(
              initialValue: widget.data.facebookLink,
              decoration: textInputDecoration.copyWith(hintText: 'Facebook профил (по избор)', hintStyle: TextStyle(color: Colors.grey[600])),
              onChanged: (val) {
                widget.data.facebookLink = val;
              },
            ),

            SizedBox(height: 20.0),

            TextFormField(
              initialValue: widget.data.instagramLink,
              decoration: textInputDecoration.copyWith(hintText: 'Instagram профил (по избор)', hintStyle: TextStyle(color: Colors.grey[600])),
              onChanged: (val) {
                widget.data.instagramLink = val;
              },
            ),

            SizedBox(height: 30.0),
          ]
        )
      )
    );
  }
}

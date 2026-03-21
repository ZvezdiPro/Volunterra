import 'package:flutter/material.dart';
import 'package:volunteer_app/models/ngo_registration_data.dart';
import 'package:volunteer_app/shared/constants.dart';

class NgoRegisterStepTwo extends StatefulWidget {
  final NgoRegistrationData data;
  final GlobalKey<FormState> formKey;

  const NgoRegisterStepTwo({
    super.key, 
    required this.data,
    required this.formKey
  });

  @override
  State<NgoRegisterStepTwo> createState() => _NgoRegisterStepTwoState();
}

class _NgoRegisterStepTwoState extends State<NgoRegisterStepTwo> {  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 40.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 100.0),
            Text('Стъпка 2: Детайли', style: mainHeadingStyle),
            SizedBox(height: 20.0),

            TextFormField(
              initialValue: widget.data.name,
              decoration: textInputDecoration.copyWith(hintText: 'Име на организацията'),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Моля, въведете име на организацията';
                return null;
              },
              onChanged: (val) => widget.data.name = val, 
            ),

            SizedBox(height: 20.0),

            TextFormField(
              initialValue: widget.data.registrationNumber,
              decoration: textInputDecoration.copyWith(hintText: 'ЕИК / БУЛСТАТ'),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Моля, въведете ЕИК или БУЛСТАТ';
                if (!RegExp(r'^(\d{9}|\d{13})$').hasMatch(val)) {
                  return 'Невалиден ЕИК / БУЛСТАТ';
                }
                return null;
              },
              onChanged: (val) => widget.data.registrationNumber = val, 
            ),

            SizedBox(height: 20.0),

            TextFormField(
              initialValue: widget.data.description,
              maxLines: 5,
              maxLength: 500,
              decoration: textInputDecoration.copyWith(hintText: 'Кратко описание на дейността ви', hintStyle: TextStyle(color: Colors.grey[600])),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Моля, въведете кратко описание';
                return null;
              },
              onChanged: (val) {
                widget.data.description = val;
              },
            ),
            
            SizedBox(height: 30.0),
          ],
        )
      )
    );
  }
}

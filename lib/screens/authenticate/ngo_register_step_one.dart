import 'package:flutter/material.dart';
import 'package:volunteer_app/models/ngo_registration_data.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class NgoRegisterStepOne extends StatefulWidget {
  final NgoRegistrationData data;
  final GlobalKey<FormState> formKey;

  const NgoRegisterStepOne({
    super.key, 
    required this.data, 
    required this.formKey,
  });

  @override
  State<NgoRegisterStepOne> createState() => _NgoRegisterStepOneState();
}

class _NgoRegisterStepOneState extends State<NgoRegisterStepOne> {
  String repeatedPassword = '';
  bool _isPasswordVisible = false;
  bool _isRepeatedPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 40.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 100.0),
            const Text('Регистрация за НПО', style: mainHeadingStyle),
            const SizedBox(height: 30.0),

            // Email input
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              decoration: textInputDecoration.copyWith(hintText: 'Имейл'),
              validator: (val) { 
                if (val == null || val.isEmpty) {
                  return 'Моля, въведете имейл';
                }
                final bool isValidEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val);
                if (!isValidEmail) {
                  return 'Моля, въведете валиден имейл адрес';
                }
                return null;
              },
              onChanged: (val) {
                setState(() {
                  widget.data.email = val;
                });
              },
            ),

            const SizedBox(height: 20.0),

            // Password input
            TextFormField(
              decoration: textInputDecoration.copyWith(
                hintText: 'Парола',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: greenPrimary
                  ), 
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  })
                ),
              obscureText: !_isPasswordVisible,
              validator: (val) => val!.length < 6 ? 'Въведете парола с най-малко 6 знака' : null,
              onChanged: (val) {
                setState(() {
                  widget.data.password = val;
                });
              },
            ),

            const SizedBox(height: 20.0),
            
            // Repeat password field
            TextFormField(
              decoration: textInputDecoration.copyWith(
                hintText: 'Повторете паролата',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isRepeatedPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: greenPrimary
                  ), 
                  onPressed: () {
                    setState(() {
                      _isRepeatedPasswordVisible = !_isRepeatedPasswordVisible;
                    });
                  })
                ),
              obscureText: !_isRepeatedPasswordVisible,
              validator: (val) => val != widget.data.password ? 'Паролите не съвпадат' : null,
              onChanged: (val) {
                setState(() {
                  repeatedPassword = val;
                });
              },
            ),

            const SizedBox(height: 30.0),
          ],
        )
      ),
    );
  }
}

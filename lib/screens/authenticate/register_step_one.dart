import 'package:flutter/material.dart';
import 'package:volunteer_app/shared/constants.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/models/registration_data.dart';
import 'package:volunteer_app/screens/authenticate/ngo_register.dart';

class RegisterStepOne extends StatefulWidget {

  final RegistrationData data;
  final GlobalKey<FormState> formKey;
  final Function toggleView;

  const RegisterStepOne({
    super.key, 
    required this.data, 
    required this.formKey,
    required this.toggleView,
  });

  @override
  State<RegisterStepOne> createState() => _RegisterStepOneState();
}

class _RegisterStepOneState extends State<RegisterStepOne> {

  String error = '';
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
              SizedBox(height: 180.0),
              const Text('Регистрация', style: mainHeadingStyle),
              SizedBox(height: 30.0),
      
              // Email input
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: textInputDecoration.copyWith(hintText: 'Имейл'),
                validator: (val) { 
                  if (val == null || val.isEmpty) {
                    return 'Моля, въведете имейл';
                  }
                  // Email RegEx and validation
                  final bool isValidEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val);
                  if (!isValidEmail) {
                    return 'Моля, въведете валиден имейл адрес';
                  }
                  return null;
                },
                onChanged: (val) {
                  // Handle email input change
                  setState(() {
                    widget.data.email = val;
                  });
                },
              ),
      
              SizedBox(height: 20.0),
      
              // Password input
              TextFormField(
                decoration: textInputDecoration.copyWith(
                  hintText: 'Парола',
                  suffixIcon: IconButton(
                    // The icon changes depending on whether the password is visible or not
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
                  // Handle password input change
                  setState(() {
                    widget.data.password = val;
                  });
                },
              ),
      
              SizedBox(height: 20.0),
              
              // Repeat password field
              TextFormField(
                decoration: textInputDecoration.copyWith(
                  hintText: 'Повторете паролата',
                  suffixIcon: IconButton(
                    // The icon changes depending on whether the password is visible or not
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
                  // Handle password input change
                  setState(() {
                    repeatedPassword = val;
                  });
                },
              ),

              SizedBox(height: 30.0),
    
              // Switch to sign-in page
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Имате регистрация?'),
                  GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4.0, right: 4.0), 
                    child: const Text(
                      'Влезте!',
                      style: TextStyle(
                        color: greenPrimary, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {
                    widget.toggleView();
                  },
                ),
              ],
            ),
            
            SizedBox(height: 20.0),
            
            // Link to NGO registration
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0), 
                    child: const Text(
                      'НПО? Регистрирайте се тук!',
                      style: TextStyle(
                        color: blueSecondary, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NgoRegister()),
                    );
                  },
                ),
              ],
            ),
          ],
        )
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:volunteer_app/services/authenticate.dart';
import 'package:volunteer_app/main.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';
import 'package:volunteer_app/shared/loading.dart';
import 'package:volunteer_app/widgets/social_button.dart';
import 'package:volunteer_app/screens/authenticate/forgot_password.dart' as volunteer_app;

class SignIn extends StatefulWidget {

  final Function toggleView;
  const SignIn({super.key, required this.toggleView});

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {

  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool loading = false;
  

  // Text field state
  String email = '';
  String password = '';
  String error = '';

  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return loading ? Loading() : Scaffold(
      backgroundColor: backgroundGrey,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 50.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                SizedBox(height: 150.0),
                Text('Добре дошли отново!', style: mainHeadingStyle, textAlign: TextAlign.center),
                SizedBox(height: 30.0),

                // Email input
                TextFormField(
                  decoration: textInputDecoration.copyWith(hintText: 'Имейл'),
                  validator: (val) => val!.isEmpty ? 'Моля, въведете имейл' : null,
                  onChanged: (val) {
                    // Handle email input change
                    setState(() {
                      email = val;
                    });
                  },
                ),

                SizedBox(height: 20.0),

                // Password input
                TextFormField(
                  decoration: textInputDecoration.copyWith(
                    hintText: 'Парола',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: greenPrimary,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: (val) => val!.length < 6 ? 'Въведете парола с най-малко 6 знака' : null,
                  onChanged: (val) {
                    setState(() {
                      password = val;
                    });
                  },
                ),

                SizedBox(height: 10.0),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const volunteer_app.ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Забравена парола?',
                      style: TextStyle(
                        color: greenPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20.0),

                // Sign-in button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greenPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 36),
                    shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: Text('Влезте'),

                  // Logs the user in if correct, throws error message otherwise
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => loading = true);
                      email = email.trim();
                      password = password.trim();
                      dynamic result = await _auth.signInWithEmailAndPassword(email, password);
                      if (result == null) {
                        setState(() {
                          error = 'Настъпи грешка при влизането';
                          loading = false;
                        });
                      }
                    }
                  },
                ),

                SizedBox(height: 20.0),

                Text(
                  'Или влезте с:',
                  style: TextStyle(fontSize: 16)
                ),
                SizedBox(height: 12.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sign-in with Google
                    SocialButton(
                      label: 'Google',
                      icon: const Icon(Icons.g_mobiledata, size: 30, color: blueSecondary),
                      onPressed: () async {
                        setState(() => loading = true);
                        dynamic result = await _auth.googleLogin();
                        if (result == null) {
                          setState(() {
                            error = 'Настъпи грешка при влизането';
                            loading = false;
                          });
                        } else if (result is String) {
                          setState(() {
                            error = result;
                            loading = false;
                          });
                        }
                      },
                    ),

                    // Sign-in with Facebook
                    SocialButton(
                      label: 'Facebook',
                      icon: const Icon(Icons.facebook, size: 24, color: blueSecondary),
                      onPressed: () async {
                        setState(() => loading = true);
                        dynamic result = await _auth.facebookLogin(
                          onAccountLinkNeeded: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Този имейл е свързан с Google акаунт. Влезте през правилния Google акаунт, за да ги свържем.',
                                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                duration: Duration(seconds: 4),
                                backgroundColor: blueSecondary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          onAccountLinked: () {
                            scaffoldMessengerKey.currentState?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Профилите са свързани успешно!',
                                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                duration: Duration(seconds: 4),
                                backgroundColor: greenPrimary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        );
                        if (result == null) {
                          setState(() {
                            error = 'Настъпи грешка при влизането';
                            loading = false;
                          });
                        } else if (result is String) {
                          setState(() {
                            error = result;
                            loading = false;
                          });
                        }
                      },
                    ),
                  ],
                ),

                // Sign-in anonymously
                SocialButton(
                  label: 'Влезте като гост',
                  icon: const Icon(Icons.person, size: 24, color: Colors.grey),
                  onPressed: () async {
                    setState(() => loading = true);
                    dynamic result = await _auth.signInAnon();
                    if (result == null) {
                      setState(() {
                        error = 'Настъпи грешка при влизането';
                        loading = false;
                      });
                    }
                  },
                ),

                SizedBox(height: 40.0),

                // Links to register page                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Нямате регистрация?'),
                    GestureDetector(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0, right: 4.0), 
                      child: const Text(
                        'Регистрирайте се!',
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

                // Error message
                SizedBox(height: 12.0),
                Text(
                  error,
                  style: TextStyle(color: Colors.red, fontSize: 14.0),
                ),
        
              ],
            )
          ),
        ),
      ),

    );
  }
}
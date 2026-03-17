import 'package:flutter/material.dart';
import 'package:volunteer_app/services/authenticate.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';
import 'package:volunteer_app/shared/loading.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  bool loading = false;
  String email = '';
  String error = '';

  @override
  Widget build(BuildContext context) {
    return loading ? const Loading() : Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: const Text('Забравена парола', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 50.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 30.0),
                const Text(
                  'Въведете вашия имейл адрес, за да получите връзка за възстановяване на паролата.\n\nСлед това проверете вашата папка за спам - имейлът може да е там!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30.0),

                // Email input
                TextFormField(
                  decoration: textInputDecoration.copyWith(hintText: 'Имейл'),
                  keyboardType: TextInputType.emailAddress,
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
                      email = val;
                      error = '';
                    });
                  },
                ),

                const SizedBox(height: 20.0),

                // Send reset email button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greenPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: const Text('Изпрати имейл за възстановяване'),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => loading = true);
                      try {
                        await _auth.sendPasswordResetEmail(email.trim());
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Имейл за възстановяване на паролата е изпратен!', style: TextStyle(fontWeight: FontWeight.bold)),
                              backgroundColor: greenPrimary,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                         if (mounted) {
                           setState(() {
                             error = 'Грешка при изпращане. Проверете имейла си и опитайте отново.';
                             loading = false;
                           });
                         }
                      }
                    }
                  },
                ),

                const SizedBox(height: 12.0),
                
                // Error message
                if (error.isNotEmpty)
                  Text(
                    error,
                    style: const TextStyle(color: Colors.red, fontSize: 14.0),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

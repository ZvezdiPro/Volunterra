import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:volunteer_app/services/authenticate.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/loading.dart';
import 'package:volunteer_app/models/ngo_registration_data.dart';
import 'package:volunteer_app/screens/authenticate/ngo_register_step_one.dart';
import 'package:volunteer_app/screens/authenticate/ngo_register_step_two.dart';
import 'package:volunteer_app/screens/authenticate/ngo_register_step_three.dart';
import 'package:volunteer_app/screens/authenticate/ngo_register_step_four.dart';

class NgoRegister extends StatefulWidget {
  const NgoRegister({super.key});

  @override
  State<NgoRegister> createState() => _NgoRegisterState();
}

class _NgoRegisterState extends State<NgoRegister> {
  final AuthService _auth = AuthService();
  final NgoRegistrationData _data = NgoRegistrationData();

  final GlobalKey<FormState> _stepOneFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _stepTwoFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _stepThreeFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _stepFourFormKey = GlobalKey<FormState>();

  PageController pageController = PageController();

  bool loading = false;
  int _currentPage = 0;
  final int totalSteps = 4;

  GlobalKey<FormState> _getCurrentFormKey() {
    switch (_currentPage) {
      case 0: return _stepOneFormKey;
      case 1: return _stepTwoFormKey;
      case 2: return _stepThreeFormKey;
      case 3: return _stepFourFormKey;
      default: return _stepOneFormKey;
    }
  }

  void nextStep() {
    final currentFormKey = _getCurrentFormKey();
    if (currentFormKey.currentState!.validate()) {
      if (_currentPage < totalSteps - 1) {
        pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
      } else {
        _submitRegistration();
      }
    }
  }

  void previousStep() {
    if (_currentPage > 0) {
      pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Предупреждение', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        content: const Text('Сигурни ли сте, че искате да излезете? Въведената информация няма да бъде запазена.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отказ', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Излизане', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _submitRegistration() async {
    setState(() {
      loading = true;
    });
    
    _data.email = _data.email.trim();
    _data.password = _data.password.trim();
    _data.name = _data.name.trim();
    _data.registrationNumber = _data.registrationNumber.trim();
    _data.description = _data.description.trim();
    _data.phone = _data.phone.trim();
    _data.website = _data.website.trim();
    _data.address = _data.address.trim();
    _data.facebookLink = _data.facebookLink.trim();
    _data.instagramLink = _data.instagramLink.trim();

    dynamic result = await _auth.registerNgoWithEmailAndPassword(_data.email, _data.password, _data);

    if (result == null) {
      setState(() {
        loading = false;
      });
      // Error handling is inside registerNgoWithEmailAndPassword or we can show snackbar here.
    } else {
      // Pop to the root so Wrapper can display MainPage
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Успешна регистрация!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            backgroundColor: greenPrimary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return loading ? const Loading() : PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundGrey,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              final shouldPop = await _showExitConfirmation();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            }
          ),
        ),
        body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: PageView(
              controller: pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (int index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                NgoRegisterStepOne(data: _data, formKey: _stepOneFormKey),
                NgoRegisterStepTwo(data: _data, formKey: _stepTwoFormKey),
                NgoRegisterStepThree(data: _data, formKey: _stepThreeFormKey),
                NgoRegisterStepFour(data: _data, formKey: _stepFourFormKey),
              ],
            ),
          ),
          Container(
            alignment: const Alignment(0, 0.85),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 100,
                    child: GestureDetector(
                      onTap: previousStep,
                      child: AnimatedOpacity(
                        opacity: _currentPage > 0 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          'Назад',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _currentPage > 0 ? greenPrimary : Colors.transparent,
                          ),
                        ),
                      )
                    ),
                  ),
                  SmoothPageIndicator(
                    controller: pageController,
                    count: totalSteps,
                    effect: JumpingDotEffect(
                      dotHeight: 10,
                      dotWidth: 10,
                      activeDotColor: greenPrimary,
                      dotColor: Colors.grey.shade400,
                    ),
                    onDotClicked: (index) {
                      if (index > _currentPage) {
                        nextStep();
                      } else {
                        pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn
                        );
                      }
                    }
                  ),
                  SizedBox(
                    width: 100,
                    child: GestureDetector(
                      onTap: nextStep,
                      child: Text(
                        _currentPage == totalSteps - 1 ? 'Край' : 'Напред',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: greenPrimary,
                        ),
                      )
                    ),
                  ),
                ],
              ),
            )
          )
        ]
      )
      )
    );
  }
}

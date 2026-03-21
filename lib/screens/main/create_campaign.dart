import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_app/models/campaign_data.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';
import 'package:volunteer_app/shared/loading.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:volunteer_app/screens/main/helper_screens/create_campaign_step_one.dart';
import 'package:volunteer_app/screens/main/helper_screens/create_campaign_step_two.dart';
import 'package:volunteer_app/screens/main/helper_screens/create_campaign_step_three.dart';


class CreateCampaign extends StatefulWidget {
  const CreateCampaign({super.key});

  @override
  State<CreateCampaign> createState() => _CreateCampaignState();
}

class _CreateCampaignState extends State<CreateCampaign> {
  final CampaignData _data = CampaignData();
  final PageController _pageController = PageController();

  bool _loading = false;
  bool _isImageUploading = false;
  int _currentPage = 0;
  final int totalSteps = 3;

  final GlobalKey<FormState> _stepOneFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _stepTwoFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _stepThreeFormKey = GlobalKey<FormState>();

  GlobalKey<FormState> _getCurrentFormKey() {
    switch (_currentPage) {
      case 0: return _stepOneFormKey;
      case 1: return _stepTwoFormKey;
      case 2: return _stepThreeFormKey;
      default: return _stepOneFormKey;
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Предупреждение', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        content: Text('Сигурни ли сте, че искате да излезете? Въведената информация за кампанията няма да бъде запазена.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отказ', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Излизане', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void nextStep() {
    final currentFormKey = _getCurrentFormKey();

    if (currentFormKey.currentState!.validate()) {
      // If we aren't on the last page, go to the next
      if (_currentPage < totalSteps - 1) {
        _pageController.nextPage(
          duration: Duration(milliseconds: 300), 
          curve: Curves.easeIn
        );
      }
      else {
        _submitCampaign();
      }
    }
  }
  
  void previousStep() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300), 
        curve: Curves.easeIn
      );
    }
  }

  Future<void> _submitCampaign() async {
    setState(() {
      _loading = true;
      });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final Object? userObj = Provider.of<Object?>(context, listen: false);
    
    String? uid;
    if (userObj is VolunteerUser) {
      uid = userObj.uid;
    } else if (userObj is NGO) {
      uid = userObj.id;
    }

    if (uid == null) return;
    
    try {
      await DatabaseService(uid: uid).updateCampaignData(_data);

      navigator.pop();

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: greenPrimary,
          content: Container(
            alignment: Alignment.center,
            height: 45,
            child: Text('Кампанията е създадена успешно!', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red[400],
          content: Text('Настъпи грешка при създаването на кампанията. Моля, опитайте отново.', style: TextStyle(color: Colors.black))
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading ? Loading() : PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final shouldPop = await _showExitConfirmation();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold (
        backgroundColor: backgroundGrey,
        resizeToAvoidBottomInset: false,
      
        // AppBar at the top
        appBar: AppBar(
          title: Text('Добавяне на кампания', style: appBarHeadingStyle),
          centerTitle: true,
          backgroundColor: backgroundGrey,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close),
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
            // The Campaign creation pages
            Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: PageView(
                controller: _pageController,
                physics: NeverScrollableScrollPhysics(),
                // The value of _currentPage changes when a page is selected
                onPageChanged: (int index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  CreateCampaignStepOne(data: _data, formKey: _stepOneFormKey),
                  CreateCampaignStepTwo(data: _data, formKey: _stepTwoFormKey),
                  CreateCampaignStepThree(
                    data: _data, 
                    formKey: _stepThreeFormKey,
                    onUploadingChanged: (isUploading) {
                      setState(() {
                        _isImageUploading = isUploading;
                      });
                    },
                  )
                ],
              ),
            ),
      
            // Navigation
            Container(
              alignment: Alignment(0, 0.85),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 50.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Go to the previous page
                    SizedBox(
                      width: 100,
                      child: GestureDetector(
                        onTap: previousStep,
                        // The text will appear with an animation
                        child: AnimatedOpacity(
                          opacity: _currentPage > 0 ? 1.0 : 0.0,
                          duration: Duration(milliseconds: 300),
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
      
                    // Dot indicator              
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: totalSteps,
                      effect: JumpingDotEffect(
                        dotHeight: 10,
                        dotWidth: 10,
                        activeDotColor: greenPrimary,
                        dotColor: Colors.grey.shade400,
                      ),
                      onDotClicked: (index) {
                        // If it's forward, make the validation
                        if (index > _currentPage) {
                          nextStep();
                        }
                        else {
                          _pageController.animateToPage(
                            index,
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeIn
                          );
                        }
                      }
                    ),
      
                    // Go to the next page
                    SizedBox(
                      width: 100,
                      child: GestureDetector(
                        onTap: _isImageUploading ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Моля, изчакайте качването на снимката да приключи!', style: TextStyle(fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        } : nextStep,
                        // If we're on the last step, show different text
                        child: AnimatedOpacity(
                          opacity: _isImageUploading ? 0.5 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _currentPage == totalSteps - 1 ? 'Край' : 'Напред',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: greenPrimary,
                            ),
                          ),
                        )
                      ),
                    ),
                  ],
                ),
              )
            )
          ]
        ),
        
      ),
    );
  }
}
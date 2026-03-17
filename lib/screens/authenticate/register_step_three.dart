import 'package:flutter/material.dart';
import 'package:volunteer_app/models/registration_data.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class RegisterStepThree extends StatefulWidget {

  final RegistrationData data;
  final GlobalKey<FormState> formKey;

  const RegisterStepThree({
    super.key, 
    required this.data,
    required this.formKey
  });

  @override
  State<RegisterStepThree> createState() => _RegisterStepThreeState();
}

class _RegisterStepThreeState extends State<RegisterStepThree> {
  
  final List<String> availableInterests = [
    'Образование', 'Екология', 'Животни', 'Грижа за деца', 'Спорт', 'Здраве',
    'Грижа за възрастни', 'Изкуство и култура', 'Помощ в извънредни ситуации'
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 50.0, right: 50.0, top: 20.0, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 100.0),
            Text('Стъпка 3: Избор на интереси', style: mainHeadingStyle),
            SizedBox(height: 30.0),

            Text(
              'Изберете областите, в които искате да доброволствате (1 до 5):', 
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700)
            ),

            SizedBox(height: 20.0),

            // Contains all the interests in buttons which are clickable in order to make a selection
            Wrap(
              spacing: 8.0, 
              runSpacing: 8.0, 
              children: availableInterests.map((interest) {
                final isSelected = widget.data.interests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: greenPrimary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                  checkmarkColor: Colors.white,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        if (widget.data.interests.length < 5) {
                          widget.data.interests.add(interest);
                        }
                        else {
                           ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: greenPrimary,
                              content: Text('Можете да изберете до максимум 5 интереса!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              ),
                          );
                        }
                      }
                      else {
                        widget.data.interests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            SizedBox(height: 20.0),
          ]
        )
      )
    );
  }
}
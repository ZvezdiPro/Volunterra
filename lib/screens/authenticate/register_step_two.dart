import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:volunteer_app/models/registration_data.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class RegisterStepTwo extends StatefulWidget {

  final RegistrationData data;
  final GlobalKey<FormState> formKey;

  const RegisterStepTwo({
    super.key, 
    required this.data,
    required this.formKey
  });

  @override
  State<RegisterStepTwo> createState() => _RegisterStepTwoState();
}

class _RegisterStepTwoState extends State<RegisterStepTwo> {  
  @override
  Widget build(BuildContext context) {

    // Format the birth date to an output string
    final dateText = widget.data.dateOfBirth == null 
        ? 'Рождена дата (по избор)'
        : DateFormat('dd.MM.yyyy').format(widget.data.dateOfBirth!);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 40.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: 100.0),
            Text('Стъпка 2: Лични Данни', style: mainHeadingStyle),
            SizedBox(height: 20.0),

            // First name input
            TextFormField(
              initialValue: widget.data.firstName,
              decoration: textInputDecoration.copyWith(hintText: 'Име'),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Моля, въведете име';
                if (val.length > 30) return 'Името е твърде дълго (макс. 30 символа)';
                return null;
              },
              onChanged: (val) => widget.data.firstName = val, 
            ),

            SizedBox(height: 20.0),

            // Surname input
            TextFormField(
              initialValue: widget.data.lastName,
              decoration: textInputDecoration.copyWith(hintText: 'Фамилия'),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Моля, въведете фамилия';
                if (val.length > 30) return 'Фамилията е твърде дълга (макс. 30 символа)';
                return null;
              },
              onChanged: (val) => widget.data.lastName = val, 
            ),

            SizedBox(height: 20.0),

            // Phone number input
            TextFormField(
              initialValue: widget.data.phoneNumber,
              keyboardType: TextInputType.phone,
              decoration: textInputDecoration.copyWith(hintText: 'Телефонен номер (по избор)', hintStyle: TextStyle(color: Colors.grey[600])),
              validator: (val) {
                if (val != null && val.isNotEmpty) {
                  // Validates Bulgarian formats: 08XXXXXXXX or +3598XXXXXXXX
                  if (!RegExp(r'^(?:\+359|0)\d{9}$').hasMatch(val)) {
                    return 'Въведете валиден телефонен номер';
                  }
                }
                return null;
              },
              onChanged: (val) => widget.data.phoneNumber = val.isEmpty ? null : val, 
            ),

            SizedBox(height: 20.0),

            // Select birthday
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade100, width: 1.0),
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.white,
                ),
                child: Text(
                  dateText,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: widget.data.dateOfBirth == null ? Colors.grey[600] : Colors.black,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20.0),

            // Biography input
            TextFormField(
              initialValue: widget.data.bio,
              maxLines: 5,
              maxLength: 200,
              scrollPadding: EdgeInsets.only(bottom: 140.0),
              decoration: textInputDecoration.copyWith(hintText: 'Разкажи за себе си... (по избор)', hintStyle: TextStyle(color: Colors.grey[600])),
              onChanged: (val) {
                widget.data.bio = val.isEmpty ? null : val;
              },
            ),
            
            SizedBox(height: 30.0),
          ],
        )
      )
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: greenPrimary, 
            colorScheme: ColorScheme.light(primary: greenPrimary),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        widget.data.dateOfBirth = pickedDate;
      });
    }
  }
}
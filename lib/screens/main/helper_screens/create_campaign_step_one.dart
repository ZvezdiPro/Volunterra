import 'package:flutter/material.dart';
import 'package:volunteer_app/models/campaign_data.dart';
import 'package:volunteer_app/shared/constants.dart';

class CreateCampaignStepOne extends StatefulWidget {
  final CampaignData data;
  final GlobalKey<FormState> formKey;

  const CreateCampaignStepOne({
    super.key,
    required this.data,
    required this.formKey,
  });

  @override
  State<CreateCampaignStepOne> createState() => _CreateCampaignStepOneState();
}

class _CreateCampaignStepOneState extends State<CreateCampaignStepOne> {

  final GlobalKey<FormFieldState> _titleKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _descriptionKey = GlobalKey<FormFieldState>();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 40.0),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Page title
            Text(
              'Стъпка 1: Основна информация',
              style: mainHeadingStyle,
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 40.0),

            // Campaign title input
            Text('Име на кампанията', style: textFormFieldHeading),
            SizedBox(height: 10.0),
            TextFormField(
              key: _titleKey,
              initialValue: widget.data.title,
              maxLength: 50,
              decoration: textInputDecoration.copyWith(labelText: 'Име', hintText: 'Например: Почистване на плажа'),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Въведете име';
                return null;
              },
              onChanged: (val) {
                widget.data.title = val.trim();
                _titleKey.currentState?.validate();
              },
            ),

            SizedBox(height: 10.0),

            // Description input
            Text('Кратко описание', style: textFormFieldHeading),
            SizedBox(height: 10.0),
            TextFormField(
              key: _descriptionKey,
              scrollPadding: EdgeInsets.only(bottom: 100),
              initialValue: widget.data.description,
              maxLength: 300,
              decoration: textInputDecoration.copyWith(labelText: 'Въведете описание', hintText: 'Ще съберем пластмасови отпадъци от плажната ивица и ще ги рециклираме.'),
              maxLines: 4,
              keyboardType: TextInputType.multiline,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Въведете описание';
                return null;
              },
              onChanged: (val) {
                widget.data.description = val.trim();
                _descriptionKey.currentState?.validate();
              }
            ),
          ],
        ),
      ),
    );
  }
}
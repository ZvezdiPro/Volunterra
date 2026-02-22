import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/models/campaign_data.dart';
import 'package:volunteer_app/shared/constants.dart';
import 'package:volunteer_app/screens/main/choose_location.dart';

class CreateCampaignStepTwo extends StatefulWidget {
  final CampaignData data;
  final GlobalKey<FormState> formKey;

  const CreateCampaignStepTwo({
    super.key,
    required this.data,
    required this.formKey,
  });

  @override
  State<CreateCampaignStepTwo> createState() => _CreateCampaignStepTwoState();
}

class _CreateCampaignStepTwoState extends State<CreateCampaignStepTwo> {

  // The keys check the validity of the individual fields and provide immediate feedback
  final GlobalKey<FormFieldState> _startDateKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _startTimeKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _endDateKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _endTimeKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _locationKey = GlobalKey<FormFieldState>();
  final GlobalKey<FormFieldState> _categoryKey = GlobalKey<FormFieldState>();

  late TextEditingController _locationController;
  
  @override
  void initState() {
    super.initState();
    // Initialize the controller with existing data (if any)
    _locationController = TextEditingController(text: widget.data.location);
  }

  @override
  void dispose() {
    // Clean up the controller
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectLocationOnMap() async {
    // Navigate to MapPicker and wait for result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          // Pass current coordinates if they exist, so the map opens there
          initialLat: widget.data.latitude,
          initialLng: widget.data.longitude,
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        // Update Data Model
        widget.data.latitude = result['latitude'];
        widget.data.longitude = result['longitude'];
        widget.data.location = result['address'];
        
        // Update the UI Text Field
        _locationController.text = result['address'];
      });

      // Trigger validation to remove any "Field is required" errors
      _locationKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormatter = DateFormat('dd MMM yyyy', 'bg_BG');
    final DateFormat timeFormatter = DateFormat('HH:mm', 'bg_BG');

    final List<String> availableCategories = [
    'Образование', 'Екология', 'Животни', 'Грижа за деца', 'Спорт', 'Здраве',
    'Грижа за възрастни', 'Изкуство и култура', 'Помощ в извънредни ситуации'
  ];

    return SingleChildScrollView(
      padding: EdgeInsets.only(left: 50.0, right: 50.0, top: 40.0, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: <Widget>[
            // Page title
            Text(
              'Стъпка 2: Подробности за кампанията',
              style: mainHeadingStyle,
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 20.0),

            // Start of the Campaign input
            Text('Начало на кампанията', style: textFormFieldHeading),
            SizedBox(height: 10.0),
            Row(
              children: [
                // Start Date input
                Expanded(
                  flex: 3,
                  child: _buildDateTimePicker(
                    context, 
                    'Дата', 
                    Icons.calendar_today, 
                    widget.data.startDate == null ? '' : dateFormatter.format(widget.data.startDate!), 
                    () => _selectDateTime(context, true),
                    fieldKey: _startDateKey,
                    validator: (val) => widget.data.startDate == null ? 'Изберете дата' : null,
                  ),
                ),
                SizedBox(width: 15),
                // Start hour input
                Expanded(
                  flex: 2,
                  child: _buildDateTimePicker(
                    context, 
                    'Час', 
                    Icons.access_time, 
                    widget.data.startDate == null ? '' : timeFormatter.format(widget.data.startDate!), 
                    () => _updateTime(context, true),
                    fieldKey: _startTimeKey,
                    validator: (val) => widget.data.startDate == null ? 'Изберете час' : null
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20.0),

            // Select the end date and time for the campaign
            Text('Край на кампанията', style: textFormFieldHeading),
            SizedBox(height: 10.0),
            Row(
              children: [
                // End date
                Expanded(
                  flex: 3,
                  child: _buildDateTimePicker(
                    context, 
                    'Дата', 
                    Icons.calendar_today, 
                    widget.data.endDate == null ? '' : dateFormatter.format(widget.data.endDate!), 
                    () => _selectDateTime(context, false),
                    validator: (val) {
                      if (widget.data.endDate == null) return 'Изберете крайна дата';
                      if (widget.data.startDate != null && widget.data.endDate!.isBefore(widget.data.startDate!)) {
                        return 'След началото!';
                      }
                      return null;
                    },
                    fieldKey: _endDateKey
                  ),
                ),
                SizedBox(width: 15),
                // End hour
                Expanded(
                  flex: 2,
                  child: _buildDateTimePicker(
                    context, 
                    'Час', 
                    Icons.access_time, 
                    widget.data.endDate == null ? '' : timeFormatter.format(widget.data.endDate!), 
                    () => _updateTime(context, false),
                    validator: (val) {
                      if (widget.data.endDate == null) return 'Изберете час';
                      if (widget.data.startDate != null && widget.data.endDate!.isBefore(widget.data.startDate!)) {
                        return '';
                      }
                      return null;
                    },
                    fieldKey: _endTimeKey
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20.0),

            // Choose Location
            Text('Местоположение', style: textFormFieldHeading),   
            SizedBox(height: 5.0),         
            TextFormField(
              key: _locationKey,
              controller: _locationController,
              readOnly: true,
              onTap: _selectLocationOnMap,
              decoration: textInputDecoration.copyWith(
                labelText: 'Адрес / точка на среща',
                hintText: 'Изберете местоположение от картата',
                suffixIcon: Icon(Icons.map, color: greenPrimary),
              ),
              validator: (val) => val!.isEmpty ? 'Въведете местоположение' : null,
            ),

            SizedBox(height: 20.0),

            // Choose category
            Text('Изберете категория', style: textFormFieldHeading),
            SizedBox(height: 5.0),
            DropdownButtonFormField<String>(
              decoration: textInputDecoration.copyWith(
                hintText: 'Изберете една категория',
                suffixIcon: Icon(Icons.arrow_drop_down, color: greenPrimary),
              ),
              
              key: _categoryKey,
              dropdownColor: Colors.white,
              initialValue: widget.data.categories.isNotEmpty ? widget.data.categories.first : null,
              validator: (val) => val == null || val.isEmpty ? 'Моля, изберете категория.' : null,
              isExpanded: true,
              
              // Whenever a category is selected
              onChanged: (String? newValue) {
                setState(() {
                  if (newValue != null) {
                    widget.data.categories = [newValue]; 
                  } else {
                    widget.data.categories = [];
                  }
                });
                _categoryKey.currentState?.validate();
              },

              // Create the list of options: for every String return an option in the menu
              items: availableCategories.map<DropdownMenuItem<String>>((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
            ),
          ]
        )
      )
    );
  }

  // Method to update the state of the corresponding field in campaign_data
  // and validate that the fields are correct
  void _updateStateAndValidate(DateTime finalDateTime, bool isStart) {
    setState(() {
      if (isStart) {
        widget.data.startDate = finalDateTime;
        
        // If the end is before the beginning, change its value to one hour after the start
        if (widget.data.endDate != null && widget.data.endDate!.isBefore(finalDateTime)) {
          widget.data.endDate = finalDateTime.add(Duration(hours: 1));
        }
      }
      else {
        widget.data.endDate = finalDateTime;
      }
    });

    if (isStart) {
      _startDateKey.currentState?.validate();
      _startTimeKey.currentState?.validate();
      if (widget.data.endDate != null) {
        _endDateKey.currentState?.validate();
      }
    }
    else {
      _endDateKey.currentState?.validate();
      _endTimeKey.currentState?.validate();
    }
  }

  // Method to select the date
  Future<DateTime?> _selectDate(BuildContext context, bool isStart) async {
    final initialDateTime = isStart 
        ? (widget.data.startDate ?? DateTime.now())
        : (widget.data.endDate ?? (widget.data.startDate ?? DateTime.now()).add(Duration(hours: 1)));

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: isStart ? DateTime.now() : (widget.data.startDate ?? DateTime.now()),
      lastDate: DateTime.now().add(Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: greenPrimary, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );

    return pickedDate;
  }

  // Method to select the time, based on a given initialDate (could be DateTime.now())
  // Because if the user has already selected a date, we want to keep the same hour and minute
  Future<TimeOfDay?> _selectTime(BuildContext context, DateTime initialDate) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate), 
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: greenPrimary, onPrimary: Colors.white),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );

    return pickedTime;
  }

  // Method to select both the Date and the Time. It's called whenever the
  // field for selecting the date is clicked and prompts the user to choose both Date and Time
  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    // Choose date
    final DateTime? pickedDate = await _selectDate(context, isStart);
    
    if (!context.mounted) return;

    if (pickedDate != null) {
      // Pick time
      final DateTime baseTime = (isStart ? widget.data.startDate : widget.data.endDate) ?? DateTime.now();

      final DateTime initialTimeForPicker = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day, 
        baseTime.hour, baseTime.minute
      );
      
      final TimeOfDay? pickedTime = await _selectTime(context, initialTimeForPicker);

      if (pickedTime != null) {
        final DateTime finalDateTime = DateTime(
          pickedDate.year, pickedDate.month, pickedDate.day, 
          pickedTime.hour, pickedTime.minute
        );

        // Update the data in the campaign_data instance
        _updateStateAndValidate(finalDateTime, isStart);
      }
    }
  }

  // Method that only updates the Time field
  Future<void> _updateTime(BuildContext context, bool isStart) async {
    final DateTime baseDateForTime = isStart ? (widget.data.startDate ?? DateTime.now()) : (widget.data.endDate ?? DateTime.now());
    final TimeOfDay? pickedTime = await _selectTime(context, baseDateForTime); 

    // Update the finalDateTime in the campaign_data
    if (pickedTime != null) {
      final DateTime finalDateTime = DateTime(
          baseDateForTime.year, baseDateForTime.month, baseDateForTime.day, 
          pickedTime.hour, pickedTime.minute
      );

      _updateStateAndValidate(finalDateTime, isStart);
    }
  }

  // Custom TextFormField that has a validator, a key
  // and an onTap method to show either DatePicker + TimePicker or only TimePicker
  Widget _buildDateTimePicker(
    BuildContext context, 
    String label, 
    IconData icon, 
    String text, 
    VoidCallback onTap, {
      GlobalKey<FormFieldState>? fieldKey,
      String? Function(String?)? validator
  }) {
    return TextFormField(
      key: fieldKey,
      decoration: textInputDecoration.copyWith(
        labelText: label,
        hintText: label,
        suffixIcon: Icon(icon, color: greenPrimary),
      ),
      controller: TextEditingController(text: text),
      readOnly: true,
      onTap: onTap,
      validator: validator
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/models/campaign_data.dart';
import 'package:volunteer_app/shared/constants.dart';
import 'package:volunteer_app/screens/main/helper_screens/choose_location.dart';

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
    _locationController = TextEditingController(text: widget.data.location);
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLat: widget.data.latitude,
          initialLng: widget.data.longitude,
        ),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        widget.data.latitude = result['latitude'];
        widget.data.longitude = result['longitude'];
        widget.data.location = result['address'];
        _locationController.text = result['address'];
      });

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
            Text(
              'Стъпка 2: Подробности за кампанията',
              style: mainHeadingStyle,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20.0),

            // Campaign Start
            Text('Начало на кампанията', style: textFormFieldHeading),
            const SizedBox(height: 10.0),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildDateTimePicker(
                    context, 
                    'Дата', 
                    Icons.calendar_today, 
                    widget.data.startDate == null ? '' : dateFormatter.format(widget.data.startDate!), 
                    () => _pickDateThenTime(context, true),
                    fieldKey: _startDateKey,
                    validator: (val) => widget.data.startDate == null ? 'Изберете дата' : null,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: _buildDateTimePicker(
                    context, 
                    'Час', 
                    Icons.access_time, 
                    widget.data.startDate == null ? '' : timeFormatter.format(widget.data.startDate!), 
                    () => _pickTimeOnly(context, true),
                    fieldKey: _startTimeKey,
                    validator: (val) => widget.data.startDate == null ? 'Изберете час' : null
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20.0),

            // Campaign End
            Text('Край на кампанията', style: textFormFieldHeading),
            const SizedBox(height: 10.0),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildDateTimePicker(
                    context, 
                    'Дата', 
                    Icons.calendar_today, 
                    widget.data.endDate == null ? '' : dateFormatter.format(widget.data.endDate!), 
                    () => _pickDateThenTime(context, false), // Извиква комбинирания метод
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
                const SizedBox(width: 15),
                Expanded(
                  flex: 2,
                  child: _buildDateTimePicker(
                    context, 
                    'Час', 
                    Icons.access_time, 
                    widget.data.endDate == null ? '' : timeFormatter.format(widget.data.endDate!), 
                    () => _pickTimeOnly(context, false), // Извиква само час
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
            
            const SizedBox(height: 20.0),

            // Location
            Text('Местоположение', style: textFormFieldHeading),   
            const SizedBox(height: 5.0),         
            TextFormField(
              key: _locationKey,
              controller: _locationController,
              readOnly: true,
              onTap: _selectLocationOnMap,
              decoration: textInputDecoration.copyWith(
                labelText: 'Адрес / точка на среща',
                hintText: 'Изберете местоположение от картата',
                suffixIcon: const Icon(Icons.map, color: greenPrimary),
              ),
              validator: (val) => val!.isEmpty ? 'Въведете местоположение' : null,
            ),

            const SizedBox(height: 20.0),

            // Category
            Text('Изберете категория', style: textFormFieldHeading),
            const SizedBox(height: 5.0),
            DropdownButtonFormField<String>(
              decoration: textInputDecoration.copyWith(
                hintText: 'Изберете една категория',
                suffixIcon: const Icon(Icons.arrow_drop_down, color: greenPrimary),
              ),
              key: _categoryKey,
              dropdownColor: Colors.white,
              initialValue: widget.data.categories.isNotEmpty ? widget.data.categories.first : null,
              validator: (val) => val == null || val.isEmpty ? 'Моля, изберете категория.' : null,
              isExpanded: true,
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

  // Pick date and time in one flow (used when user taps on date field)
  Future<void> _pickDateThenTime(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day); 

    final initialDate = isStart 
        ? (widget.data.startDate ?? now)
        : (widget.data.endDate ?? (widget.data.startDate ?? now).add(const Duration(hours: 2)));

    final firstDate = isStart 
        ? today 
        : (widget.data.startDate != null ? DateTime(widget.data.startDate!.year, widget.data.startDate!.month, widget.data.startDate!.day) : today);

    // Select date first
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => _buildPickerTheme(child!),
    );

    if (pickedDate == null || !context.mounted) return;

    // Picking time after date is selected
    final initialTimeDate = isStart 
        ? (widget.data.startDate ?? now)
        : (widget.data.endDate ?? (widget.data.startDate ?? now).add(const Duration(hours: 2)));

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTimeDate),
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => _buildPickerTheme(child!, isTimePicker: true),
    );

    if (pickedTime == null) return;

    final finalDateTime = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day, 
      pickedTime.hour, pickedTime.minute
    );

    _applyDateTimeChange(finalDateTime, isStart);
  }

  // Picking only time (used when user taps on time field directly)
  Future<void> _pickTimeOnly(BuildContext context, bool isStart) async {
    final baseDate = isStart 
        ? (widget.data.startDate ?? DateTime.now()) 
        : (widget.data.endDate ?? (widget.data.startDate ?? DateTime.now()).add(const Duration(hours: 2)));
        
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baseDate), 
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => _buildPickerTheme(child!, isTimePicker: true),
    ); 

    if (pickedTime != null) {
      final DateTime finalDateTime = DateTime(
          baseDate.year, baseDate.month, baseDate.day, 
          pickedTime.hour, pickedTime.minute
      );

      _applyDateTimeChange(finalDateTime, isStart);
    }
  }

  // Universal method to apply date and time changes with validation
  void _applyDateTimeChange(DateTime finalDateTime, bool isStart) {
    // Check if the new date and time are in the past
    if (finalDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Не може да избирате минало време!",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      if (isStart) {
        widget.data.startDate = finalDateTime;
        
        if (widget.data.endDate == null || widget.data.endDate!.isBefore(finalDateTime)) {
          widget.data.endDate = finalDateTime.add(const Duration(hours: 2));
        }
      } else {
        widget.data.endDate = finalDateTime;
      }
    });

    // Validation
    if (isStart) {
      _startDateKey.currentState?.validate();
      _startTimeKey.currentState?.validate();
      if (widget.data.endDate != null) {
        _endDateKey.currentState?.validate();
        _endTimeKey.currentState?.validate();
      }
    } else {
      _endDateKey.currentState?.validate();
      _endTimeKey.currentState?.validate();
    }
  }

  // Picker Theme Helper
  Widget _buildPickerTheme(Widget child, {bool isTimePicker = false}) {
    final theme = Theme(
      data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(primary: greenPrimary, onPrimary: Colors.white),
      ),
      child: child,
    );

    if (isTimePicker) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: theme,
      );
    }
    return theme;
  }

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
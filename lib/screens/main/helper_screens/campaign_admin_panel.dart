import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/screens/main/helper_screens/public_profile_screen.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class CampaignAdminPanel extends StatefulWidget {
  final Campaign campaign;

  const CampaignAdminPanel({super.key, required this.campaign});

  @override
  State<CampaignAdminPanel> createState() => _CampaignAdminPanelState();
}

class _CampaignAdminPanelState extends State<CampaignAdminPanel> {
  final DatabaseService _db = DatabaseService();
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy', 'bg');
  final DateFormat _timeFormatter = DateFormat('HH:mm');

  // State
  late DateTime _startDate;
  late DateTime _endDate;
  bool _hasChanges = false;
  bool _isSaving = false;

  // Controllers
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  // Volunteers State
  List<VolunteerUser>? _volunteers;
  bool _isLoadingVolunteers = true;

  @override
  void initState() {
    super.initState();
    _startDate = widget.campaign.startDate;
    _endDate = widget.campaign.endDate;
    
    _updateControllers();
    _loadVolunteers();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _startTimeController.dispose();
    _endDateController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _updateControllers() {
    _startDateController.text = _dateFormatter.format(_startDate);
    _startTimeController.text = _timeFormatter.format(_startDate);
    _endDateController.text = _dateFormatter.format(_endDate);
    _endTimeController.text = _timeFormatter.format(_endDate);
  }

  Future<void> _loadVolunteers() async {
    try {
      if (widget.campaign.registeredVolunteersUids.isEmpty) {
        setState(() {
          _volunteers = [];
          _isLoadingVolunteers = false;
        });
        return;
      }
      
      List<VolunteerUser> users = await _db.getVolunteersFromList(widget.campaign.registeredVolunteersUids);
      
      if (mounted) {
        setState(() {
          _volunteers = users;
          _isLoadingVolunteers = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading volunteers: $e");
      if (mounted) setState(() => _isLoadingVolunteers = false);
    }
  }

  // Save logic (upon pressing the button)
  Future<void> _saveChanges() async {
    if (!_hasChanges) return;

    setState(() => _isSaving = true);

    try {
      await _db.updateCampaignDates(widget.campaign.id, _startDate, _endDate);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: greenPrimary,
            content: Center(
              child: Text("Промените са запазени успешно!", style: TextStyle(fontWeight: FontWeight.bold),)
            )
          ),
        );
        setState(() {
          _hasChanges = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Грешка: $e"), backgroundColor: Colors.red),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  // Date picker
  Future<void> _pickDate({required bool isStart}) async {
    final DateTime firstDate = isStart ? DateTime(2020) : _startDate;
    
    final DateTime initialPickerDate = isStart ? _startDate : _endDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialPickerDate.isBefore(firstDate) ? firstDate : initialPickerDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: greenPrimary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          final TimeOfDay time = TimeOfDay.fromDateTime(_startDate);
          _startDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);

          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(hours: 2));
          }
        } else {
          final TimeOfDay time = TimeOfDay.fromDateTime(_endDate);
          _endDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        }
        
        _updateControllers();
        _hasChanges = true;
      });
    }
  }

  // Time picker
  Future<void> _pickTime({required bool isStart}) async {
    final DateTime baseDate = isStart ? _startDate : _endDate;
    final TimeOfDay initialTime = TimeOfDay.fromDateTime(baseDate);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
             data: ThemeData.light().copyWith(colorScheme: ColorScheme.light(primary: greenPrimary)),
             child: child!
        ),
      ),
    );

    if (picked != null) {
      final DateTime newDateTime = DateTime(
        baseDate.year, baseDate.month, baseDate.day, 
        picked.hour, picked.minute
      );

      // Validation
      if (!isStart && newDateTime.isBefore(_startDate)) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Крайният час не може да е преди началния!"), backgroundColor: Colors.redAccent)
           );
         }
         return;
      }

      setState(() {
        if (isStart) {
          _startDate = newDateTime;
          if (_endDate.isBefore(_startDate)) {
             _endDate = _startDate.add(const Duration(hours: 1));
          }
        } else {
          _endDate = newDateTime;
        }
        _updateControllers();
        _hasChanges = true;
      });
    }
  }

  // Confirmation dialog for unsaved changes
  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Незапазени промени'),
        content: const Text('Имате незапазени промени. Сигурни ли сте, че искате да напуснете?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отказ', style: TextStyle(color: Colors.black87)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Напусни', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges, 
      
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }

        final shouldLeave = await _showExitConfirmationDialog();

        if (shouldLeave && context.mounted) {
          setState(() {
            _hasChanges = false; 
          });
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: backgroundGrey,
        // AppBar with the Title and Save button
        appBar: AppBar(
          title: const Text("Админ Панел", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
            TextButton(
              onPressed: (_hasChanges && !_isSaving) ? _saveChanges : null,
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    "Запази",
                    style: TextStyle(
                      color: _hasChanges ? greenPrimary : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold
                    ),
                  ),
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Duration
              Text("Продължителност", style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              
              _buildDateRow("Начало", _startDateController, _startTimeController, true),
              const SizedBox(height: 15),
              _buildDateRow("Край", _endDateController, _endTimeController, false),
      
              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 10),
      
              // Registered Volunteers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Записани доброволци", style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold)),
                  if (_volunteers != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: greenPrimary.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                      child: Text("${_volunteers!.length}", style: TextStyle(color: greenPrimary, fontWeight: FontWeight.bold)),
                    )
                ],
              ),
              const SizedBox(height: 10),
      
              if (_isLoadingVolunteers)
                 const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_volunteers == null || _volunteers!.isEmpty)
                 const Padding(
                   padding: EdgeInsets.symmetric(vertical: 20),
                   child: Text("Няма записани доброволци за тази кампания.", style: TextStyle(color: Colors.grey)),
                 )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _volunteers!.length,
                  itemBuilder: (context, index) {
                    final user = _volunteers![index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                        child: user.avatarUrl == null ? Text(user.firstName[0], style: TextStyle(color: greenPrimary)) : null,
                      ),
                      title: Text("${user.firstName} ${user.lastName}"),
                      subtitle: Text(user.email, style: const TextStyle(fontSize: 12)),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                        onPressed: () => _confirmRemoveVolunteer(user),
                      ),
                      // Push a public profile screen
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublicProfileScreen(volunteer: user),
                          ),
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        // Remove Campaign Button
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(25),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Colors.redAccent)
                ),
                onPressed: _confirmEndCampaign,
                child: const Text("Прекрати Кампанията", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget row
  Widget _buildDateRow(String label, TextEditingController dateCtrl, TextEditingController timeCtrl, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            // Date field
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: dateCtrl,
                readOnly: true,
                onTap: () => _pickDate(isStart: isStart),
                decoration: textInputDecoration.copyWith(
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Time field
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: timeCtrl,
                readOnly: true,
                onTap: () => _pickTime(isStart: isStart),
                decoration: textInputDecoration.copyWith(
                  suffixIcon: const Icon(Icons.access_time, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Method to confirm removing a volunteer
  Future<void> _confirmRemoveVolunteer(VolunteerUser user) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Премахване на доброволец"),
        content: Text("Сигурни ли сте, че искате да премахнете ${user.firstName} от кампанията?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Отказ")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Премахни", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;

    // Call database to remove volunteer
    if (confirm) {
      await _db.removeVolunteerFromCampaign(widget.campaign.id, user.uid);
      setState(() {
        _volunteers!.remove(user);
        widget.campaign.registeredVolunteersUids.remove(user.uid);
      });
    }
  }

  // Method to confirm ending the campaign
  Future<void> _confirmEndCampaign() async {
    final bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Прекратяване на кампания"),
        content: const Text("Това действие ще маркира кампанията като 'Приключила'. Сигурни ли сте?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Отказ")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Да, Приключи", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;

    // Call database to end campaign
    if (confirm) {
      await _db.endCampaign(widget.campaign.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
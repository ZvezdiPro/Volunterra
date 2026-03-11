import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/screens/main/choose_location.dart';
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
  final GlobalKey<FormState> _generalFormKey = GlobalKey<FormState>();

  // General State
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late TextEditingController _locationController;

  late DateTime _startDate;
  late DateTime _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();

  late double _latitude;
  late double _longitude;
  late List<String> _categories;

  bool _hasChanges = false;
  bool _isSaving = false;

  // Volunteers State
  List<VolunteerUser>? _volunteers;
  bool _isLoadingVolunteers = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.campaign.title);
    _descriptionController = TextEditingController(
      text: widget.campaign.description,
    );
    _instructionsController = TextEditingController(
      text: widget.campaign.instructions,
    );
    _locationController = TextEditingController(text: widget.campaign.location);

    _startDate = widget.campaign.startDate;
    _endDate = widget.campaign.endDate;
    _latitude = widget.campaign.latitude;
    _longitude = widget.campaign.longitude;
    _categories = List.from(widget.campaign.categories);

    _updateControllers();
    _loadVolunteers(widget.campaign.registeredVolunteersUids);
  }

  void _initializeData(Campaign campaign) {
    if (!_isInitialized) {
      _titleController = TextEditingController(text: campaign.title);
      _descriptionController =
          TextEditingController(text: campaign.description);
      _instructionsController =
          TextEditingController(text: campaign.instructions);
      _locationController = TextEditingController(text: campaign.location);

      _startDate = campaign.startDate;
      _endDate = campaign.endDate;
      _latitude = campaign.latitude;
      _longitude = campaign.longitude;
      _categories = List.from(campaign.categories);

      _updateControllers();
      _loadVolunteers(campaign.registeredVolunteersUids);
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _startTimeController.dispose();
    _endDateController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _updateControllers() {
    _startDateController.text = _dateFormatter.format(_startDate);
    _startTimeController.text = _timeFormatter.format(_startDate);
    _endDateController.text = _dateFormatter.format(_endDate);
    _endTimeController.text = _timeFormatter.format(_endDate);
  }

  Future<void> _loadVolunteers(List<dynamic> uids) async {
    try {
      if (uids.isEmpty) {
        setState(() {
          _volunteers = [];
          _isLoadingVolunteers = false;
        });
        return;
      }

      List<VolunteerUser> users = await _db.getVolunteersFromList(uids);

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

  // Save changes for general tab
  Future<void> _saveChanges() async {
    if (!_hasChanges) return;
    if (!(_generalFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      Map<String, dynamic> updateData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'location': _locationController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'startDate': _startDate,
        'endDate': _endDate,
        'categories': _categories,
      };

      await _db.updateCampaignGeneralInfo(widget.campaign.id, updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: greenPrimary,
            content: Center(
              child: Text(
                "Промените са запазени успешно!",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
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

  // Pick Date
  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDate = isStart
        ? today
        : DateTime(_startDate.year, _startDate.month, _startDate.day);

    final DateTime initialPickerDate = isStart ? _startDate : _endDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialPickerDate.isBefore(firstDate)
          ? firstDate
          : initialPickerDate,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365 * 2)),
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
          _startDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );

          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(hours: 2));
          }
        } else {
          final TimeOfDay time = TimeOfDay.fromDateTime(_endDate);
          _endDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        }

        _updateControllers();
        _hasChanges = true;
      });
    }
  }

  // Pick Time
  Future<void> _pickTime({required bool isStart}) async {
    final DateTime baseDate = isStart ? _startDate : _endDate;
    final TimeOfDay initialTime = TimeOfDay.fromDateTime(baseDate);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: greenPrimary),
          ),
          child: child!,
        ),
      ),
    );

    if (picked != null) {
      final DateTime newDateTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        picked.hour,
        picked.minute,
      );

      // Validation
      if (!isStart && newDateTime.isBefore(_startDate)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Крайният час не може да е преди началния!",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.redAccent,
            ),
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

  // Pick Location
  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MapPickerScreen(initialLat: _latitude, initialLng: _longitude),
      ),
    );

    if (result != null && result is Map) {
      setState(() {
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _locationController.text = result['address'];
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
            content: const Text(
              'Имате незапазени промени. Сигурни ли сте, че искате да напуснете?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Отказ',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Напусни',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Method to check if registered volunteers are present for ownership transfer
  void _openTransferOwnershipDialog() {
    if (_volunteers == null || _volunteers!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Няма записани доброволци, на които да прехвърлите кампанията.",
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Прехвърляне на кампанията"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Изберете доброволец от списъка с участници:"),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _volunteers!.length,
                    itemBuilder: (context, index) {
                      final vol = _volunteers![index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: vol.avatarUrl != null
                              ? NetworkImage(vol.avatarUrl!)
                              : null,
                          child: vol.avatarUrl == null
                              ? Text(vol.firstName[0])
                              : null,
                        ),
                        title: Text("${vol.firstName} ${vol.lastName}"),
                        subtitle: Text(vol.email),
                        onTap: () {
                          Navigator.pop(ctx);
                          _confirmTransferOwnership(vol);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Отказ"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmTransferOwnership(VolunteerUser newOwner) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Потвърждение"),
            content: Text(
              "Сигурни ли сте, че искате да прехвърлите собствеността на тази кампания на ${newOwner.firstName} ${newOwner.lastName}? Това действие не може да бъде отменено.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Отказ"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Прехвърли",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await _db.transferCampaignOwnership(
          widget.campaign.id,
          widget.campaign.organizerId,
          newOwner.uid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Собствеността е прехвърлена успешно!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: greenPrimary,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Грешка: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmEndCampaign() async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Прекратяване на кампания", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: const Text(
              "Това действие ще прекрати кампанията и е НЕОБРАТИМО! Сигурни ли сте?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Отказ"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Да, прекрати",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await _db.endCampaign(widget.campaign.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Кампанията е прекратена успешно!",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: greenPrimary,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  // Method to confirm removing a volunteer
  Future<void> _confirmRemoveVolunteer(VolunteerUser user) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Премахване на доброволец"),
            content: Text(
              "Сигурни ли сте, че искате да премахнете ${user.firstName} от кампанията?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Отказ"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Премахни",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await _db.removeVolunteerFromCampaign(widget.campaign.id, user.uid);
      setState(() {
        _volunteers!.remove(user);
        widget.campaign.registeredVolunteersUids.remove(user.uid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Campaign?>(
      future: _db.getCampaign(widget.campaign.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          _initializeData(snapshot.data!);

          return PopScope(
            canPop: !_hasChanges,
            onPopInvokedWithResult: (bool didPop, dynamic result) async {
              if (didPop) return;

              final shouldLeave = await _showExitConfirmationDialog();

              if (shouldLeave && context.mounted) {
                setState(() {
                  _hasChanges = false;
                });
                Navigator.of(context).pop();
              }
            },
            child: DefaultTabController(
              length: 3,
              child: Scaffold(
                backgroundColor: backgroundGrey,
                appBar: AppBar(
                  title: const Text(
                    "Админ панел",
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  elevation: 1,
                  iconTheme: const IconThemeData(color: Colors.black87),
                  bottom: const TabBar(
                    labelColor: greenPrimary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: greenPrimary,
                    tabs: [
                      Tab(text: "Детайли"),
                      Tab(text: "Участници"),
                      Tab(text: "Опасна зона"),
                    ],
                  ),
                ),
                body: SafeArea(
                  child: TabBarView(
                    children: [
                      _buildGeneralTab(),
                      _buildParticipantsTab(),
                      _buildDangerZoneTab(),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const Scaffold(
          body: Center(child: Text('Грешка при зареждането на кампанията.')),
        );
      },
    );
  }

  Widget _buildGeneralTab() {
    final List<String> availableCategories = [
      'Образование',
      'Екология',
      'Животни',
      'Грижа за деца',
      'Спорт',
      'Здраве',
      'Грижа за възрастни',
      'Изкуство и култура',
      'Помощ в извънредни ситуации',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Form(
        key: _generalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Основна информация",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              "Променете основните детайли на кампанията",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Title
            Text('Име на кампанията', style: textFormFieldHeading),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: textInputDecoration.copyWith(
                hintText: "Например: Почистване на парк",
                fillColor: Colors.white,
              ),
              onChanged: (_) => _onFieldChanged(),
              validator: (val) => val!.isEmpty ? 'Въведете име' : null,
            ),
            const SizedBox(height: 15),

            // Description
            Text('Описание', style: textFormFieldHeading),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: textInputDecoration.copyWith(
                hintText: "Опишете целта на тази кампания...",
              ),
              maxLines: 4,
              onChanged: (_) => _onFieldChanged(),
              validator: (val) => val!.isEmpty ? 'Въведете описание' : null,
            ),
            const SizedBox(height: 15),

            // Start & End Dates
            _buildDateRow(
              "Начална дата",
              _startDateController,
              _startTimeController,
              true,
            ),
            const SizedBox(height: 15),
            _buildDateRow(
              "Крайна дата",
              _endDateController,
              _endTimeController,
              false,
            ),
            const SizedBox(height: 15),

            // Location
            Text('Местоположение', style: textFormFieldHeading),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationController,
              readOnly: true,
              onTap: _selectLocationOnMap,
              decoration: textInputDecoration.copyWith(
                hintText: 'Град или село',
                prefixIcon: const Icon(Icons.location_on, color: greenPrimary),
              ),
              validator: (val) =>
                  val!.isEmpty ? 'Въведете местоположение' : null,
            ),
            const SizedBox(height: 15),

            // Instructions
            Text('Инструкции (по избор)', style: textFormFieldHeading),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructionsController,
              decoration: textInputDecoration.copyWith(
                hintText: "Добавете инструкции...",
              ),
              maxLines: 3,
              onChanged: (_) => _onFieldChanged(),
            ),
            const SizedBox(height: 15),

            // Category
            Text('Категория', style: textFormFieldHeading),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: textInputDecoration.copyWith(
                hintText: 'Изберете категория',
              ),
              icon: const Icon(Icons.arrow_drop_down, color: greenPrimary),
              dropdownColor: Colors.white,
              initialValue: _categories.isNotEmpty ? _categories.first : null,
              validator: (val) => val == null || val.isEmpty
                  ? 'Моля, изберете категория.'
                  : null,
              isExpanded: true,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _categories = [newValue];
                    _hasChanges = true;
                  });
                }
              },
              items: availableCategories.map<DropdownMenuItem<String>>((
                String category,
              ) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save, color: Colors.white),
                label: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Запази промените",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: greenPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                onPressed: (_hasChanges && !_isSaving) ? _saveChanges : null,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          color: backgroundGrey,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Регистрирани доброволци",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  if (_volunteers != null)
                    Text(
                      "${_volunteers!.length} Общо участници",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingVolunteers
              ? const Center(
                  child: CircularProgressIndicator(color: greenPrimary),
                )
              : (_volunteers == null || _volunteers!.isEmpty)
              ? const Center(
                  child: Text(
                    "Няма записани доброволци.",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(0),
                  itemCount: _volunteers!.length,
                  itemBuilder: (context, index) {
                    final user = _volunteers![index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 1),
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? Text(
                                  user.firstName[0],
                                  style: const TextStyle(
                                    color: greenPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          "${user.firstName} ${user.lastName}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _confirmRemoveVolunteer(user),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PublicProfileScreen(volunteer: user),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDangerZoneTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Критични действия",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            "Тези действия са необратими и ще повлияят незабавно на текущия статус на кампанията.",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Info Banner
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "След като кампанията бъде прекратена, тя няма да бъде видима за доброволци и те няма да могат да се записват за нея.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Transfer Ownership
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Прехвърляне на собственост",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 5),
                Text(
                  "Прехвърляне на административните права на тази кампания на друг потребител във вашата организация.",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _openTransferOwnershipDialog,
                    child: const Text(
                      "Прехвърляне на собственост",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // End Campaign
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Прекрати кампанията",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Премахва завинаги тази кампания и всички свързани с нея данни. Това действие не може да бъде отменено.",
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _confirmEndCampaign,
                    child: const Text(
                      "Прекрати кампанията",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Helper widget row
  Widget _buildDateRow(
    String label,
    TextEditingController dateCtrl,
    TextEditingController timeCtrl,
    bool isStart,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textFormFieldHeading),
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
                  prefixIcon: const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: greenPrimary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
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
                  prefixIcon: const Icon(
                    Icons.access_time,
                    size: 18,
                    color: greenPrimary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

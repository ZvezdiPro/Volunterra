import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/campaign_task.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';

class AssignTaskScreen extends StatefulWidget {
  final Campaign campaign;
  const AssignTaskScreen({super.key, required this.campaign});

  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _deadline;

  final List<String> _selectedAssigneeIds = [];
  List<VolunteerUser> _participants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    Set<String> participantIds = Set.from(
      widget.campaign.registeredVolunteersUids,
    );
    participantIds.addAll(widget.campaign.coorganizersIds);
    participantIds.add(widget.campaign.organizerId); // Can assign to themselves

    List<VolunteerUser> users = [];
    for (String id in participantIds) {
      bool exists = await DatabaseService(uid: id).checkUserExists();
      if (exists) {
        var userData = await DatabaseService(uid: id).getVolunteerUser();
        if (userData != null) {
          users.add(userData);
        }
      }
    }

    if (mounted) {
      setState(() {
        _participants = users;
        _isLoading = false;
      });
    }
  }

  void _showAssigneePicker() {
    String searchQuery = "";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredUsers = _participants.where((u) {
              final fullName = '${u.firstName} ${u.lastName}'.toLowerCase();
              return fullName.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.6,
                maxChildSize: 0.9,
                minChildSize: 0.4,
                expand: false,
                builder: (context, scrollController) {
                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Text(
                          'Избор на изпълнители',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Търсене...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            final isSelected = _selectedAssigneeIds.contains(
                              user.uid,
                            );
                            return CheckboxListTile(
                              activeColor: greenPrimary,
                              contentPadding: const EdgeInsets.only(
                                left: 24,
                                right: 16,
                              ),
                              title: Text('${user.firstName} ${user.lastName}'),
                              value: isSelected,
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedAssigneeIds.add(user.uid);
                                  } else {
                                    _selectedAssigneeIds.remove(user.uid);
                                  }
                                });
                                setModalState(() {});
                              },
                            );
                          },
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: greenPrimary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Готово',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _assignTask() async {
    if (_formKey.currentState!.validate() && _selectedAssigneeIds.isNotEmpty) {
      setState(() => _isLoading = true);

      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final taskId = const Uuid().v4();

      final task = CampaignTask(
        id: taskId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        assigneeIds: _selectedAssigneeIds,
        assignerId: currentUserId,
        isCompleted: false,
        createdAt: DateTime.now(),
        deadline: _deadline,
      );

      await DatabaseService(
        uid: currentUserId,
      ).createCampaignTask(widget.campaign.id, task);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Задачата е възложена успешно!'),
            backgroundColor: greenPrimary,
          ),
        );
      }
    } else if (_selectedAssigneeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Моля, попълнете празните полета!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: const Text(
          'Възлагане на задача',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: greenPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Заглавие',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: greenPrimary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        hintText: 'напр. Посрещнете участниците на гарата',
                        hintStyle: const TextStyle(fontSize: 16),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Въведете заглавие'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Описание (кратко)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: greenPrimary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        hintText:
                            'напр. Посрещнете участниците и ги изпратете до хотела',
                        hintStyle: const TextStyle(fontSize: 16),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Въведете описание'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Изпълнител(и)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: _showAssigneePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedAssigneeIds.isEmpty
                                  ? 'Изберете изпълнители'
                                  : 'Избрани (${_selectedAssigneeIds.length})',
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedAssigneeIds.isEmpty
                                    ? Colors.black54
                                    : Colors.black87,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedAssigneeIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _selectedAssigneeIds.map((uid) {
                          final user = _participants.firstWhere(
                            (u) => u.uid == uid,
                          );
                          return Chip(
                            label: Text(
                              '${user.firstName} ${user.lastName}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onDeleted: () {
                              setState(() {
                                _selectedAssigneeIds.remove(uid);
                              });
                            },
                            deleteIconColor: Colors.grey,
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),

                    const Text(
                      'Краен срок (опционално)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              widget.campaign.endDate.isAfter(DateTime.now())
                              ? widget.campaign.endDate
                              : DateTime.now(),
                          initialEntryMode: DatePickerEntryMode.calendarOnly,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: greenPrimary,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.black,
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: greenPrimary,
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          if (!context.mounted) return;
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: greenPrimary,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: greenPrimary,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (pickedTime != null) {
                            final newDeadline = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );

                            if (newDeadline.isBefore(DateTime.now())) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Не може да избирате минало време!',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                              return;
                            }

                            if (newDeadline.isAfter(widget.campaign.endDate)) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Срокът не може да е след края на кампанията!',
                                      style: TextStyle(
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
                              _deadline = newDeadline;
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _deadline == null
                                  ? 'Изберете дата и час'
                                  : '${_deadline!.day.toString().padLeft(2, '0')}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.year} ${_deadline!.hour.toString().padLeft(2, '0')}:${_deadline!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _assignTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: greenPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Възложи задача',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

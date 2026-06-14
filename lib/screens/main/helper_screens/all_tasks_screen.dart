import 'package:flutter/material.dart';
import 'package:volunteer_app/models/campaign.dart';
import 'package:volunteer_app/models/campaign_task.dart';
import 'package:volunteer_app/models/volunteer.dart';
import 'package:volunteer_app/screens/main/helper_screens/assign_task_screen.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';

class AllTasksScreen extends StatelessWidget {
  final Campaign campaign;
  final String currentUserId;

  const AllTasksScreen({
    super.key,
    required this.campaign,
    required this.currentUserId,
  });

  void _showDeleteDialog(BuildContext context, CampaignTask task) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text('Изтриване на задача'),
          content: Text(
            'Сигурни ли сте, че искате да изтриете задачата "${task.title}"? Този процес е необратим.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отказ', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await DatabaseService(
                  uid: currentUserId,
                ).deleteCampaignTask(campaign.id, task.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Задачата е изтрита успешно!',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text(
                'Изтриване',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: const Text(
          'Задачи',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<List<CampaignTask>>(
        stream: DatabaseService(
          uid: currentUserId,
        ).getAllCampaignTasks(campaign.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: greenPrimary),
            );
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text("Възникна грешка при зареждане на задачите."),
            );
          }

          final tasks = snapshot.data ?? [];
          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                "Няма създадени задачи за тази кампания.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return InkWell(
                onLongPress: () => _showDeleteDialog(context, task),
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isCompleted
                                      ? Colors.grey
                                      : Colors.black,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: task.isCompleted
                                    ? greenPrimary.withAlpha(30)
                                    : accentAmber.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                task.isCompleted ? "Завършена" : "Изпълнява се",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: task.isCompleted
                                      ? greenPrimary
                                      : accentAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.description,
                          style: TextStyle(
                            color: task.isCompleted
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        FutureBuilder<List<VolunteerUser?>>(
                          future: Future.wait(
                            task.assigneeIds.map(
                              (id) =>
                                  DatabaseService(uid: id).getVolunteerUser(),
                            ),
                          ),
                          builder: (context, userSnap) {
                            String assigneeName = "Зареждане...";
                            if (userSnap.hasData && userSnap.data != null) {
                              final validUsers = userSnap.data!
                                  .where((u) => u != null)
                                  .toList();
                              if (validUsers.isNotEmpty) {
                                assigneeName = validUsers
                                    .map((u) => "${u!.firstName} ${u.lastName}")
                                    .join(", ");
                              } else {
                                assigneeName = "Няма изпълнители";
                              }
                            } else if (userSnap.hasError) {
                              assigneeName = "Неизвестен";
                            }
                            return Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Изпълнител: $assigneeName',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (task.deadline != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Срок: ${task.deadline!.day}/${task.deadline!.month}/${task.deadline!.year} ${task.deadline!.hour.toString().padLeft(2, '0')}:${task.deadline!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AssignTaskScreen(campaign: campaign),
            ),
          );
        },
        backgroundColor: greenPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Възложи нова задача',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

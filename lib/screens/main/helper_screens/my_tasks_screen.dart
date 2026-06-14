import 'package:flutter/material.dart';
import 'package:volunteer_app/models/campaign_task.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/shared/colors.dart';

class MyTasksScreen extends StatelessWidget {
  final String campaignId;
  final String currentUserId;

  const MyTasksScreen({
    super.key,
    required this.campaignId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: const Text(
          'Моите задачи',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: StreamBuilder<List<CampaignTask>>(
        stream: DatabaseService(
          uid: currentUserId,
        ).getMyCampaignTasks(campaignId),
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
                "Нямате възложени задачи за тази кампания.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: CheckboxListTile(
                  activeColor: greenPrimary,
                  title: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted ? Colors.grey : Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        task.description,
                        style: TextStyle(
                          color: task.isCompleted
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                      if (task.deadline != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: task.isCompleted
                                  ? Colors.grey
                                  : accentAmber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Срок: ${task.deadline!.day}/${task.deadline!.month}/${task.deadline!.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: task.isCompleted
                                    ? Colors.grey
                                    : accentAmber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  value: task.isCompleted,
                  onChanged: (bool? value) {
                    if (value != null) {
                      DatabaseService(
                        uid: currentUserId,
                      ).updateCampaignTaskCompletion(
                        campaignId,
                        task.id,
                        value,
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class CampaignTask {
  final String id;
  final String title;
  final String description;
  final List<String> assigneeIds;
  final String assignerId;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? deadline;

  CampaignTask({
    required this.id,
    required this.title,
    required this.description,
    required this.assigneeIds,
    required this.assignerId,
    this.isCompleted = false,
    required this.createdAt,
    this.deadline,
  });

  factory CampaignTask.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return CampaignTask(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      assigneeIds: data['assigneeIds'] != null ? List<String>.from(data['assigneeIds']) : [],
      assignerId: data['assignerId'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      deadline: data['deadline'] != null ? (data['deadline'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'assigneeIds': assigneeIds,
      'assignerId': assignerId,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
    };
  }
}

import 'package:flutter/material.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  // TODO: Implement achievements display
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        backgroundColor: backgroundGrey,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Постижения', style: appBarHeadingStyle),
      ),
      body: const Center(
        child: Text("Тук ще са постиженията на потребителя"),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:volunteer_app/shared/constants.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // TODO: Implement settings options
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
        title: const Text('Настройки', style: appBarHeadingStyle),
      ),
      body: const Center(
        child: Text("Тук ще са настройките на приложението"),
      ),
    );
  }
}
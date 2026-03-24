import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[100],
      body: Container(
        color: Colors.green[100],
        child: const Center(
          child: SpinKitFadingCircle(
            color: Colors.green,
            size: 50.0,
          ),
        ),
      ),
    );
  }
}
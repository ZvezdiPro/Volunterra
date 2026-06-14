import 'package:flutter/material.dart';
import 'package:volunteer_app/shared/colors.dart';

const textInputDecoration = InputDecoration(
  fillColor: Colors.white,
  filled: true,
  enabledBorder: OutlineInputBorder(
    borderSide: BorderSide(
      color: Colors.white,
      width: 2.0,
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(
      color: accentAmber,
      width: 2.0,
    ),
  ),
);

final searchBarInputDecoration = InputDecoration(
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    borderSide: const BorderSide(color: blueSecondary, width: 1.5),
  ),
);

const titleStyle = TextStyle(
  color: Colors.black,
  fontSize: 28,
  fontWeight: FontWeight.bold,
  );

const mainHeadingStyle = TextStyle(
  color: greenPrimary,
  fontSize: 28,
  fontWeight: FontWeight.bold,
  );

const appBarHeadingStyle = TextStyle(
  color: Colors.black,
  fontSize: 22,
  fontWeight: FontWeight.w600,
  );

const textFormFieldHeading = TextStyle(
  color: Colors.black54,
  fontSize: 16,
  fontWeight: FontWeight.bold
);

const guestSnackbar = SnackBar(
  backgroundColor: Colors.orange,
  content: Center(child: Text('Тази функция е достъпна само за регистрирани потребители!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
  duration: Duration(seconds: 3),
  behavior: SnackBarBehavior.floating,
);

const volunteerOnlySnackbar = SnackBar(
  backgroundColor: Colors.orange,
  content: Center(child: Text('Тази функция е достъпна само за доброволци!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
  duration: Duration(seconds: 3),
  behavior: SnackBarBehavior.floating,
);
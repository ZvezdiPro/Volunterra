import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_app/screens/wrapper.dart';
import 'package:volunteer_app/services/authenticate.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // print("Handling a background message: \${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const VolunteerApp());
}

class VolunteerApp extends StatefulWidget {
  const VolunteerApp({super.key});

  @override
  State<VolunteerApp> createState() => _VolunteerAppState();
}

class _VolunteerAppState extends State<VolunteerApp> {
  int currentPageIndex = 0;
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamProvider<Object?>.value (
      initialData: null,
      value: _authService.user,
      catchError: (_, __) => null,
      child: MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'Volunteer App',
        theme: ThemeData(
          primarySwatch: Colors.green,
        ),
        
        // Supported locales (languages)
        supportedLocales: [
          Locale('en', ''),
          Locale('bg', ''),
        ],

        // The localization delegates
        // which decide how to load the localized resources
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        // The locale of the app
        locale: Locale('bg', ''),

        // The wrapper widget decides which page to show based on authentication state
        home: Wrapper(),
      )
    );
  }
}
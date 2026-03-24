import 'package:flutter/material.dart';
import 'package:volunteer_app/screens/main/home.dart';
import 'package:volunteer_app/screens/main/events_page.dart';
import 'package:volunteer_app/screens/main/chats.dart';
import 'package:volunteer_app/screens/main/profile.dart';
import 'package:volunteer_app/screens/main/ngo_profile.dart';
import 'package:volunteer_app/services/authenticate.dart';
import 'package:volunteer_app/services/database.dart';
import 'package:volunteer_app/services/fcm_service.dart';
import 'package:volunteer_app/shared/colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:volunteer_app/models/ngo.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final AuthService _auth = AuthService();
  int currentPageIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: currentPageIndex);
    FCMService().init();
    _updateLocationOnStartup();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _updateLocationOnStartup() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium)
      );
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        await DatabaseService(uid: user.uid).updateUserLocation(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint("Error fetching/saving location: \$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final userObj = Provider.of<Object?>(context);
    final bool isNgo = userObj is NGO;
    final bool isVerifiedNgo = isNgo && userObj.isVerified;
    
    return Scaffold(
      backgroundColor: backgroundGrey,
      // Appbar at the top
      appBar: AppBar(
        title: Text('Volunterra', style: TextStyle(color: greenPrimary, fontSize: 24.0, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: backgroundGrey,
        elevation: 1.0,
        actions: [
          TextButton.icon(
            icon: Icon(Icons.logout, color: blueSecondary),
            label: Text('Изход', style: TextStyle(color: greenPrimary, fontSize: 14.0)),
            onPressed: () async {
              await _auth.signOut();
            },
          ),
        ],
      ),

      // The four pages to navigate between
      body: Column(
        children: [
          if (isNgo && !isVerifiedNgo)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: Colors.orange.shade100,
              child: const Text(
                'Вашият профил се преглежда за одобрение. Ще се свържем с вас скоро.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  currentPageIndex = index;
                });
              },
              children: [
                HomeScreen(
                  onGoToEvents: () {
                    _pageController.animateToPage(
                      1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                const EventsPage(), 
                const ChatsScreen(),
                isNgo
                  ? const NGOProfilePage()
                  : const ProfilePage(),
              ],
            ),
          ),
        ],
      ),

      // Navigation bar at the bottom
      bottomNavigationBar: NavigationBar(destinations: 
        [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Начало',
          ),
          NavigationDestination(  
            icon: Icon(Icons.event),
            label: 'Събития',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat),
            label: 'Чатове'
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Профил',
          ),
        ],
        backgroundColor: blueSecondary.withAlpha(15),
        indicatorColor: greenPrimary.withAlpha(40),
        selectedIndex: currentPageIndex,
        onDestinationSelected: (int index) {
          if (currentPageIndex == index) return;
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }
}
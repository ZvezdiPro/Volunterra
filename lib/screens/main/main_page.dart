import 'package:flutter/material.dart';
import 'package:volunteer_app/screens/main/home.dart';
import 'package:volunteer_app/screens/main/events_page.dart';
import 'package:volunteer_app/screens/main/chats.dart';
import 'package:volunteer_app/screens/main/profile.dart';
import 'package:volunteer_app/services/authenticate.dart';
import 'package:volunteer_app/services/fcm_service.dart';
import 'package:volunteer_app/shared/colors.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final AuthService _auth = AuthService();
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    FCMService().init();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: backgroundGrey,
      // Appbar at the top
      appBar: AppBar(
        title: Text('Volunteer Varna', style: TextStyle(color: greenPrimary, fontSize: 24.0, fontWeight: FontWeight.bold)),
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
      body: IndexedStack(
        index: currentPageIndex,
        children: [
          HomeScreen(
            onGoToEvents: () {
              setState(() {
                // EventsPage index is 1
                currentPageIndex = 1;
              });
            },
          ),
          const EventsPage(), 
          const ChatsScreen(),
          const ProfilePage(),
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
          setState(() {
            currentPageIndex = index;
          });
        },
      ),
    );
  }
}
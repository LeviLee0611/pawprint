import 'package:flutter/material.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/feed/screens/feed_screen.dart';
import 'features/pet/screens/pet_screen.dart';
import 'features/profile/screens/profile_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    CalendarScreen(),
    FeedScreen(),
    PetScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.dynamic_feed), label: '피드'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: '내 펫'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
      ),
    );
  }
}

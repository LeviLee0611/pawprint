import 'package:flutter/material.dart';
import 'core/services/notification_service.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/feed/screens/feed_screen.dart';
import 'features/profile/screens/my_profile_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/search/screens/search_screen.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    NotificationService.onNotificationTap = () {
      if (mounted) _jumpToTab(0);
    };
  }

  @override
  void dispose() {
    _pageController.dispose();
    NotificationService.onNotificationTap = null;
    super.dispose();
  }

  void _jumpToTab(int index) {
    if (!_pageController.hasClients) {
      setState(() => _currentIndex = index);
      return;
    }
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: const [
          CalendarScreen(),
          FeedScreen(),
          SearchScreen(),
          MyProfileScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _jumpToTab,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dynamic_feed_outlined),
            activeIcon: Icon(Icons.dynamic_feed),
            label: '피드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search_rounded),
            label: '검색',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_on_outlined),
            activeIcon: Icon(Icons.grid_on),
            label: '내 피드',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '프로필',
          ),
        ],
      ),
    );
  }
}

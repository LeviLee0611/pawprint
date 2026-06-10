import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/notification_service.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/community/screens/community_screen.dart';
import 'features/feed/screens/feed_screen.dart';
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
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    NotificationService.onNotificationTap = () {
      if (mounted) _jumpToTab(0);
    };
    NotificationService.onChatNotificationTap = () {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChatListScreen()),
      );
    };
    // cold start: 콜백 등록 완료 후 보류 중인 알림 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.consumePendingNotification();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    NotificationService.onNotificationTap = null;
    NotificationService.onChatNotificationTap = null;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('뒤로가기를 한 번 더 누르면 앱이 종료됩니다'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          children: const [
            CalendarScreen(),
            FeedScreen(),
            SearchScreen(),
            CommunityScreen(),
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
              icon: Icon(Icons.favorite_border_rounded),
              activeIcon: Icon(Icons.favorite_rounded),
              label: '나눔&실종',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '프로필',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'screens/feed_screen.dart';
import 'screens/reels_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/chat_screen.dart';

import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'api/api_service.dart';
import 'app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initHost();
  final token = await ApiService.getToken();
  runApp(GMinstaApp(isLoggedIn: token != null));
}

class GMinstaApp extends StatelessWidget {
  final bool isLoggedIn;
  const GMinstaApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GMinsta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFE1306C),
        colorScheme: const ColorScheme.dark(primary: Color(0xFFE1306C)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0a0a0a),
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
        ),
        dividerColor: const Color(0xFF262626),
      ),
      home: isLoggedIn ? const MainNavigation() : const LoginScreen(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  void _onTabTap(int index) {
    setState(() => _currentIndex = index);
    activeTabNotifier.value = index; // notify screens to pause/play media
  }

  @override
  Widget build(BuildContext context) {
    // Build screens dynamically so ProfileScreen always shows current user
    final screens = [
      const FeedScreen(),
      const ExploreScreen(),
      const ReelsScreen(),
      const ChatScreen(),
      const ProfileScreen(), // own profile (no username = self)
    ];


    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie_creation_outlined),
            activeIcon: Icon(Icons.movie_creation),
            label: 'Reels',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );

  }
}

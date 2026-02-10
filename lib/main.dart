import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './pages/app_bar.dart';
import './pages/bottom_nav.dart';
import './widgets/info.dart';
import './widgets/checkin.dart';
import './widgets/history.dart';
import './widgets/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// ==================== MyApp ====================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _currentIndex = 0;
  bool _checkingLogin = true;
  bool _isLoggedIn = false;

  final List<Widget> _pages = [
    HistoryPage(),
    Checkin(),
    UserInfo(),
  ];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // ==================== Login Check ====================
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(seconds: 2));

    final String? userId = prefs.getString('user_id');

    setState(() {
      _isLoggedIn = userId != null;
      _checkingLogin = false;
      if (_isLoggedIn) _currentIndex = 2;
    });
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLogin) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashPage(),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Anuphan',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 22),
          bodyLarge: TextStyle(fontSize: 22),
          titleMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: _isLoggedIn
          ? Scaffold(
              appBar: CustomAppBar(title: 'CMRU Checkin'),
              body: _pages[_currentIndex],
              bottomNavigationBar: CustomBottomNav(
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
              ),
            )
          : const LoginPage(),
    );
  }
}

// ==================== Splash Page ====================
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF90CAF9), Color(0xFFE3F2FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "CMRU Checkin",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              RotationTransition(
                turns: _controller,
                child: const CircularProgressIndicator(
                  strokeWidth: 6,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

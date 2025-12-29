import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart'; // ✅ กลับหน้า Login หลัง logout เสร็จ

class LogoutPage extends StatefulWidget {
  const LogoutPage({super.key});

  @override
  State<LogoutPage> createState() => _LogoutPageState();
}

class _LogoutPageState extends State<LogoutPage> {
  @override
  void initState() {
    super.initState();
    _performLogout();
  }

  Future<void> _performLogout() async {
    await Future.delayed(const Duration(seconds: 1)); // แสดงโหลดนิดหน่อย
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // ✅ เคลียร์เฉพาะค่าผู้ใช้
    await prefs.remove('user_id');
    await prefs.remove('name');
    await prefs.remove('department');
    await prefs.remove('imageUrl');

    // ✅ กลับหน้า Login
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text(
              "กำลังออกจากระบบ...",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

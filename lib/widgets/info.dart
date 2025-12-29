import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login.dart';
import 'logout.dart';
import '../config.dart'; // ดึง appVersion จาก config.dart

class UserInfo extends StatefulWidget {
  const UserInfo({super.key});

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  String name = 'ไม่ระบุชื่อ';
  String department = 'ไม่ระบุสังกัด';
  String userId = 'ไม่ระบุ';
  String? imageUrl; // ใช้ null เป็น fallback
  bool canLogout = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndLoadUser();
    _checkAppUpdate();
  }

  Future<void> _checkLoginAndLoadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('user_id');
    if (id == null || id.isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
      return;
    }

    String? pic = prefs.getString('picture');

    setState(() {
      name = prefs.getString('fullname') ?? 'ไม่ระบุชื่อ';
      department = prefs.getString('stf_department') ?? 'ไม่ระบุสังกัด';
      userId = id.toString();
      imageUrl = (pic != null && pic.isNotEmpty)
          ? 'https://www.epersonal.cmru.ac.th/personal_data/images/small/$pic'
          : null; // ถ้าไม่มีรูป fallback จะใช้ AssetImage
    });

    await _checkLogoutPermission(userId);
  }

  Future<void> _checkLogoutPermission(String userId) async {
    try {
      final uri = Uri.parse(
        'https://checkin.cmru.ac.th/api/check_logout.php?user_id=$userId',
      );

      final response = await http.get(
        uri,
        headers: {"Authorization": "Bearer $bearerToken"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          canLogout = (data['match'] == true) || (data['can_logout'] == true);
        });
      }
    } catch (e) {
      debugPrint('Error checking logout permission: $e');
    }
  }

  // ------------------ ตรวจสอบเวอร์ชัน ------------------
  Future<void> _checkAppUpdate() async {
    try {
      final uri = Uri.parse('https://checkin.cmru.ac.th/api/update.json');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['appVersion'] as String?;
        final releaseNotes = data['releaseNotes'] as String?;

        if (latestVersion != null &&
            _isVersionGreater(latestVersion, appVersion)) {
          if (!mounted) return;
          _showUpdateDialog(latestVersion, releaseNotes);
        }
      }
    } catch (e) {
      debugPrint('Error checking app update: $e');
    }
  }

  bool _isVersionGreater(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length || latestParts[i] > currentParts[i]) {
        return true;
      } else if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }
    return false;
  }

  void _showUpdateDialog(String latestVersion, String? notes) {
    showDialog(
      context: context,
      barrierDismissible: false, // ป้องกันกดนอก dialog แล้วปิด
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // กันกดปุ่ม Back ออก
        child: AlertDialog(
          title: const Text('กรุณาอัปเดตแอป'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('เวอร์ชันใหม่: $latestVersion'),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('รายละเอียด: $notes'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ปิด'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[300],
                backgroundImage:
                    (imageUrl != null && imageUrl!.isNotEmpty)
                        ? NetworkImage(imageUrl!)
                        : const AssetImage('assets/images/avatar.jpg'),
                onBackgroundImageError: (_, _) {
                  setState(() {
                    imageUrl = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'User ID: $userId',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 5),
              Text(
                'App Version: $appVersion',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              if (canLogout)
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('ยืนยันการออกจากระบบ'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('ยกเลิก'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('ออกจากระบบ'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LogoutPage(),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    "ออกจากระบบ",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

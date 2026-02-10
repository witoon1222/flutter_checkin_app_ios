import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import './login.dart';
import '../config.dart';

class Checkin extends StatefulWidget {
  const Checkin({super.key});

  @override
  State<Checkin> createState() => _CheckinState();
}

// ===================== Clock =====================
String _dateText = "";
String _timeText = "";
Timer? _clockTimer;

class _CheckinState extends State<Checkin> {
  Timer? _gpsTimer;

  LatLng? _currentPosition;
  String? userId;

  final ValueNotifier<bool> insideArea = ValueNotifier(false);
  List<Map<String, dynamic>> allowedAreas = [];
  Map<String, dynamic>? currentArea;

  String name = 'ไม่ระบุชื่อ';
  String department = 'ไม่ระบุสังกัด';
  String imageUrl =
      'https://static.vecteezy.com/system/resources/thumbnails/004/511/281/small_2x/default-avatar-photo-placeholder-profile-picture-vector.jpg';

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _startClock();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _gpsTimer?.cancel();
    super.dispose();
  }

  // ===================== Load user =====================
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');

    if (userId == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
      return;
    }

    setState(() {
      name = prefs.getString('fullname') ?? 'ไม่ระบุชื่อ';
      department = prefs.getString('stf_department') ?? 'ไม่ระบุสังกัด';
      final pic = prefs.getString('picture');
      if (pic != null && pic.isNotEmpty) {
        imageUrl =
            'https://www.epersonal.cmru.ac.th/personal_data/images/small/$pic';
      }
    });

    await _loadBypassUsers();
    await _loadAllowedLocations();
    await _initLocation();
  }

  // ===================== Bypass =====================
  Future<void> _loadBypassUsers() async {
    try {
      final res = await http.get(
        Uri.parse("https://checkin.cmru.ac.th/api/bypass_location.json"),
        headers: {"Authorization": "Bearer $bearerToken"},
      );

      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.any((e) => e['user_id'] == userId)) {
          insideArea.value = true;
        }
      }
    } catch (_) {}
  }

  // ===================== Load areas =====================
  Future<void> _loadAllowedLocations() async {
    final res = await http.get(
      Uri.parse("https://checkin.cmru.ac.th/api/location.json"),
      headers: {"Authorization": "Bearer $bearerToken"},
    );

    if (res.statusCode == 200) {
      final List data = json.decode(res.body);
      allowedAreas = data.map<Map<String, dynamic>>((e) {
        return {
          "id": e["id"].toString(),
          "name": e["name"].toString(),
          "minLat": double.parse(e["minLat"].toString()),
          "maxLat": double.parse(e["maxLat"].toString()),
          "minLng": double.parse(e["minLng"].toString()),
          "maxLng": double.parse(e["maxLng"].toString()),
        };
      }).toList();
    }
  }

  // ===================== GPS =====================
  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    _updatePosition(pos);

    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _updatePosition(pos);
      } catch (_) {}
    });
  }

  void _updatePosition(Position p) {
    if (p.isMocked) {
      insideArea.value = false;
      return;
    }

    final latlng = LatLng(p.latitude, p.longitude);
    final area = _findArea(latlng);

    setState(() {
      _currentPosition = latlng;
      currentArea = area;
    });

    insideArea.value = area != null;
  }

  Map<String, dynamic>? _findArea(LatLng pos) {
    for (final area in allowedAreas) {
      if (pos.latitude >= area["minLat"] &&
          pos.latitude <= area["maxLat"] &&
          pos.longitude >= area["minLng"] &&
          pos.longitude <= area["maxLng"]) {
        return area;
      }
    }
    return null;
  }

  // ===================== Clock =====================
  void _startClock() {
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateClock();
    });
  }

  void _updateClock() {
    final now = DateTime.now();
    final buddhistYear = now.year + 543;

    setState(() {
      _dateText =
          "${now.day.toString().padLeft(2, '0')}/"
          "${now.month.toString().padLeft(2, '0')}/"
          "$buddhistYear";

      _timeText =
          "${now.hour.toString().padLeft(2, '0')}:"
          "${now.minute.toString().padLeft(2, '0')}:"
          "${now.second.toString().padLeft(2, '0')} น.";
    });
  }

  // ===================== Check-in =====================
  Future<void> _checkIn() async {
    if (!insideArea.value || userId == null) return;

    final res = await http.post(
      Uri.parse("https://checkin.cmru.ac.th/api/checkin1.php"),
      headers: {
        "Authorization": "Bearer $bearerToken",
        "Content-Type": "application/json",
      },
      body: json.encode({
        "barcode": userId,
        "server_id": currentArea?["id"],
      }),
    );

    final data = json.decode(res.body);

    _showDialog(
      data['status'] == 'success' ? 'ลงเวลาสำเร็จ' : 'ลงเวลาไม่สำเร็จ',
      data['message'] ?? '',
      data['status'] == 'success' ? Colors.green : Colors.red,
    );
  }

  void _showDialog(String title, String msg, Color color) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: TextStyle(color: color)),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  // ===================== UI =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Container(color: const Color(0xFFF5F5F5)),

                // ===== Profile =====
                Positioned(
                  top: 40,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(imageUrl),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                 
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              currentArea != null ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            currentArea != null
                                ? "📍 ${currentArea!["name"]}"
                                : "นอกเขตพื้นที่ที่กำหนด",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== Clock =====
Transform.translate(
  offset: const Offset(0, 40), // 👈 เลื่อนลงประมาณ 2 บรรทัด
  child: Center(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 30,
            vertical: 35,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 42,
                color: Color.fromARGB(255, 9, 24, 163),
              ),
              const SizedBox(height: 25),
              Text(
                "วันที่ $_dateText",
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "เวลา $_timeText",
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),

// ===== Button =====
ValueListenableBuilder<bool>(
  valueListenable: insideArea,
  builder: (_, inside, __) => inside
      ? Transform.translate(
          offset: const Offset(0, -20), // 👈 ปรับค่าได้
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: ElevatedButton(
                onPressed: _checkIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF016DE9),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 70,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(35),
                  ),
                ),
                child: const Text(
                  "ลงเวลาทำงาน",
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        )
      : const SizedBox.shrink(),
),

               
              ],
            ),
    );
  }
}

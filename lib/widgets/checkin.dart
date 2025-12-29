import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import './login.dart';
import '../config.dart';

class Checkin extends StatefulWidget {
  const Checkin({super.key});

  @override
  State<Checkin> createState() => _CheckinState();
}

class _CheckinState extends State<Checkin> {
  final MapController _mapController = MapController();
  final double _zoom = 16.0;

  LatLng? _selectedPosition;
  String? userId;

  List<Map<String, dynamic>> allowedAreas = [];
  Map<String, dynamic>? currentArea;

  final ValueNotifier<bool> insideArea = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ===================== Load user =====================
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id');

    debugPrint("🧠 DEBUG: Stored user_id in prefs = $userId");

    if (userId == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
      return;
    }

    await _loadAllowedLocations();
  }

  // ===================== Load areas =====================
  Future<void> _loadAllowedLocations() async {
    try {
      final response = await http.get(
        Uri.parse("https://checkin.cmru.ac.th/api/location.json"),
        headers: {"Authorization": "Bearer $bearerToken"},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        allowedAreas = data.map<Map<String, dynamic>>((e) {
          final minLat = double.tryParse(e["minLat"]?.toString() ?? '');
          final maxLat = double.tryParse(e["maxLat"]?.toString() ?? '');
          final minLng = double.tryParse(e["minLng"]?.toString() ?? '');
          final maxLng = double.tryParse(e["maxLng"]?.toString() ?? '');

          if (minLat == null ||
              maxLat == null ||
              minLng == null ||
              maxLng == null) {
            debugPrint("⚠️ Skip invalid area: $e");
            return {};
          }

          return {
            "id": e["id"].toString(),
            "name": e["name"].toString(),
            "minLat": minLat,
            "maxLat": maxLat,
            "minLng": minLng,
            "maxLng": maxLng,
          };
        }).where((e) => e.isNotEmpty).toList();

        await _getCurrentLocation();
      }
    } catch (e) {
      debugPrint("❌ Load location error: $e");
    }
  }

  // ===================== GPS =====================
  Future<void> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showDialog('ผิดพลาด', 'กรุณาเปิด GPS', Colors.orange);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showDialog('ผิดพลาด', 'ไม่อนุญาตให้ใช้ตำแหน่ง', Colors.red);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final latlng = LatLng(position.latitude, position.longitude);

    setState(() {
      _selectedPosition = latlng;
      currentArea = _findArea(latlng);
      insideArea.value = currentArea != null;
    });

    _mapController.move(latlng, _zoom);
  }

  // ===================== Area check =====================
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

  // ===================== Check-in =====================
  Future<void> _checkIn() async {
    if (_selectedPosition == null || userId == null) return;

    try {
      final response = await http.post(
        Uri.parse("https://checkin.cmru.ac.th/api/checkin1.php"),
        headers: {
          "Authorization": "Bearer $bearerToken",
          "Content-Type": "application/json",
        },
        body: json.encode({
          "barcode": userId,
          "server_id": currentArea?["id"] ?? "0",
        }),
      );

      final data = json.decode(response.body);

      _showDialog(
        data['status'] == 'success' ? 'ลงเวลาสำเร็จ' : 'ลงเวลาไม่สำเร็จ',
        data['message'] ?? '',
        data['status'] == 'success' ? Colors.green : Colors.red,
      );
    } catch (_) {
      _showDialog(
        'เกิดข้อผิดพลาด',
        'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์',
        Colors.orange,
      );
    }
  }

  // ===================== Dialog =====================
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
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(18.7883, 98.9853),
          initialZoom: _zoom,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'th.ac.cmru.checkin',
          ),
          if (_selectedPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedPosition!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),

      // ===================== FIXED GREEN BUTTON =====================
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: insideArea,
        builder: (_, inside, __) => Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: inside ? _checkIn : null,
            style: ButtonStyle(
              backgroundColor:
                  MaterialStateProperty.resolveWith<Color>((states) {
                if (states.contains(MaterialState.disabled)) {
                  return Colors.grey.shade400;
                }
                return Colors.green; // ✅ เขียวแน่นอน
              }),
              foregroundColor:
                  MaterialStateProperty.all(Colors.white),
              padding: MaterialStateProperty.all(
                const EdgeInsets.symmetric(vertical: 14),
              ),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            child: Text(
              inside ? 'ลงเวลาทำงาน' : 'อยู่นอกพื้นที่',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

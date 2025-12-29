import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String? userId;
  bool isLoading = false;
  List<dynamic> historyData = [];

  late List<DateTime> months = [];
  DateTime? selectedMonth;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initMonths();
    _checkLoginAndLoadUser();
    // 🔹 Debug เวลาปัจจุบัน
    final now = DateTime.now();
    print("Current time: $now"); // หรือ debugPrint("Current time: $now");
  }

  void _initMonths() {
    final now = DateTime.now();
    months = List.generate(12, (i) {
      final month = DateTime(now.year, now.month - i, 1);
      return month;
    });
    selectedMonth = months.first;
  }

  Future<void> _checkLoginAndLoadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString(
      'user_id',
    ); // 🔄 เปลี่ยนจาก getInt → getString

    // 🧩 เพิ่มบรรทัดนี้เพื่อดูค่าที่เก็บจริงใน SharedPreferences
    print('🧠 DEBUG: Stored user_id in prefs = $storedUserId');

    if (storedUserId != null && storedUserId.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        userId = storedUserId; // Assign as String
      });
      await _fetchHistoryForSelectedMonth(autoScroll: true);
    }
  }

  Future<void> _fetchHistoryForSelectedMonth({bool autoScroll = false}) async {
    if (userId == null || selectedMonth == null) return;

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // แปลง DateTime เป็น "YYYY-MM"
      final monthStr = _formatMonthString(selectedMonth!);

      final queryParams = {
        'user_id': userId.toString(),
        'month': monthStr, // ส่งเป็นเดือน
      };

      final uri = Uri.parse(
        'https://checkin.cmru.ac.th/api/history.php',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {"Authorization": "Bearer $bearerToken"},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          historyData = data['transactions'] ?? [];
          isLoading = false;
        });

        if (autoScroll && historyData.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          });
        }
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
        debugPrint('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      debugPrint('Error fetching history: $e');
    }
  }

  // แปลง DateTime เป็น "YYYY-MM"
  String _formatMonthString(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  String _formatThaiMonth(DateTime date) {
    final monthNames = [
      '',
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final month = monthNames[date.month];
    final year = date.year + 543;
    return '$month $year';
  }

  String _formatStatus(String? inOrOut) {
    if (inOrOut == 'in') return 'เข้างาน';
    if (inOrOut == 'out') return 'ออกงาน';
    return '';
  }

  String _formatDateTime(String? createdAt) {
    if (createdAt == null || createdAt.isEmpty) return '';
    final dt = DateTime.parse(createdAt);
    return '${dt.day}/${dt.month}/${dt.year + 543} เวลา ${DateFormat('HH:mm').format(dt)}';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('ประวัติการลงเวลา'),
      //   centerTitle: true,
      //   backgroundColor: Colors.blueAccent,
      // ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'เดือน: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<DateTime>(
                        value: selectedMonth,
                        items: months
                            .map(
                              (month) => DropdownMenuItem<DateTime>(
                                value: month,
                                child: Text(_formatThaiMonth(month)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            if (!mounted) return;
                            setState(() => selectedMonth = value);
                            _fetchHistoryForSelectedMonth(autoScroll: true);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await _fetchHistoryForSelectedMonth();
                      },
                      child: historyData.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 200),
                                Center(child: Text('ยังไม่มีข้อมูล')),
                              ],
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: historyData.length,

                              itemBuilder: (context, index) {
                                final item = historyData[index];

                                final formattedDate = _formatDateTime(
                                  item['created_at'],
                                );
                                final status = item['in_or_out'];
                                final location =
                                    item['location'] ?? '-'; // ✅ ดึงค่าจาก API

                                bool isToday = false;
                                if (item['created_at'] != null &&
                                    item['created_at'].toString().isNotEmpty) {
                                  final dt = DateTime.parse(item['created_at']);
                                  final now = DateTime.now();
                                  isToday =
                                      dt.year == now.year &&
                                      dt.month == now.month &&
                                      dt.day == now.day;
                                }

                                // สี/ไอคอนสถานะ
                                Color badgeColor;
                                IconData badgeIcon;
                                String badgeText;

                                if (status == 'in') {
                                  badgeColor = Colors.green.shade400;
                                  badgeIcon = Icons.login;
                                  badgeText = 'เข้า';
                                } else {
                                  badgeColor = Colors.red.shade400;
                                  badgeIcon = Icons.logout;
                                  badgeText = 'ออก';
                                }

                                return Card(
  elevation: 3,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  ),
  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        // 🕓 ไอคอนด้านซ้าย
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            badgeIcon,
            color: badgeColor,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),

        // 📄 เนื้อหาหลัก
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ✅ ป้ายสถานะ (IN / OUT)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  ),
);

                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
   return BottomNavigationBar(
  currentIndex: currentIndex,
  onTap: onTap,
  selectedItemColor: Colors.blueAccent, // สีตอนเลือก
  unselectedItemColor: Colors.grey, // สีตอนยังไม่เลือก
  selectedLabelStyle: const TextStyle(
    fontSize: 20, // ✅ ขนาดตัวอักษรตอนเลือก
    fontWeight: FontWeight.bold,
  ),
  unselectedLabelStyle: const TextStyle(
    fontSize: 20, // ✅ ขนาดตัวอักษรตอนยังไม่เลือก
  ),
  items: [
    const BottomNavigationBarItem(
      icon: Icon(
        Icons.history,
        size: 40, // <-- ขนาดไอคอน
      ),
      label: 'ประวัติลงเวลา',
    ),
    BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: currentIndex == 1
              ? Colors.blueAccent.withOpacity(0.2) // 🔹 สีเมื่อเลือก
              : const Color.fromARGB(255, 43, 96, 243)
                  .withOpacity(0.1), // 🔹 สีตอนยังไม่เลือก
        ),
        child: Icon(
          Icons.fingerprint,
          size: 80,
          color: currentIndex == 1
              ? Colors.blueAccent
              : const Color.fromARGB(255, 243, 4, 4),
        ),
      ),
      label: 'ลงเวลา',
    ),
    const BottomNavigationBarItem(
      icon: Icon(
        Icons.info,
        size: 40, // <-- ขนาดไอคอน
      ),
      label: 'ข้อมูลส่วนตัว',
    ),
  ],
);

  }
}

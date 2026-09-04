// ============================================================
// 📄 ไฟล์: category_icons.dart
// 📌 ไอคอนหมวดงานซ่อมที่ใช้ในหน้า dashboard.dart (แถบหมวดหมู่: เครื่องยนต์ / ยาง / แบตเตอรี่ / ซ่อมสี)
// 📝 หมายเหตุ: เดิมใช้ emoji จริงของระบบ (🔧🛞🔋🖌️) แต่ผู้ใช้ต้องการให้ไอคอนตรงกับภาพตัวอย่าง
//     ที่ส่งมาเป๊ะๆ จึงเปลี่ยนมาใช้รูปภาพจริง (ตัดมาจากภาพตัวอย่างที่ผู้ใช้ส่งให้โดยตรง) แทน emoji
//     รูปแต่ละไอคอนมีพื้นหลังวงกลมสีพาสเทลติดมาในตัวอยู่แล้ว (ตัดวงกลมพร้อมโปร่งใสรอบนอกไว้แล้ว)
//     จึงตั้ง default size = 68 ให้เท่ากับวงกลมพื้นหลัง 68x68 ของ CategoryItem ใน dashboard.dart
//     เพื่อให้รูปคลุมเต็มวงกลมพอดี แทนที่วงกลม color.withOpacity(0.12) เดิมไปเลย ไม่ซ้อนกันเป็น 2 วง
// ============================================================

import 'package:flutter/material.dart';

Widget _categoryIcon(String assetPath, double size) {
  return ClipOval(
    child: Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}

/// ไอคอนหมวด "เครื่องยนต์"
Widget buildEngineIcon({double size = 68}) =>
    _categoryIcon('images/categories/cat_engine.png', size);

/// ไอคอนหมวด "ยาง"
Widget buildTireIcon({double size = 68}) =>
    _categoryIcon('images/categories/cat_tire.png', size);

/// ไอคอนหมวด "แบตเตอรี่"
Widget buildBatteryIcon({double size = 68}) =>
    _categoryIcon('images/categories/cat_battery.png', size);

/// ไอคอนหมวด "ซ่อมสี"
Widget buildPaintIcon({double size = 68}) =>
    _categoryIcon('images/categories/cat_paint.png', size);

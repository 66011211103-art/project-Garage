// ไอคอนหมวดงานซ่อมแบบสมจริง (เครื่องยนต์ / ยาง / แบตเตอรี่ / ซ่อมสี)
// วาดด้วย widget พื้นฐาน + gradient ทั้งหมด ไม่ต้องใช้ไฟล์รูป
//
// วิธีใช้:  1) วางไฟล์นี้ที่ lib/category_icons.dart
//          2) ใน dashboard.dart เพิ่ม  import 'category_icons.dart';
//          3) เปลี่ยน CategoryItem ทั้ง 4 ตัวเป็น customIcon: (ดูท้ายไฟล์)

import 'package:flutter/material.dart';

// ทุกไอคอนออกแบบบนกริด 96x96 แล้วย่อด้วย FittedBox ให้ได้ขนาดที่ต้องการ
Widget _stage(double size, List<Widget> children) => SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        child: SizedBox(
          width: 96,
          height: 96,
          child: Stack(children: children),
        ),
      ),
    );

// แถบครีบ/ร่องแบบเส้นซ้ำ (แทน repeating-linear-gradient)
Widget _ribs({
  required double width,
  required double height,
  double gap = 13,
  double thickness = 4,
  Color light = const Color(0x1affffff),
  Color dark = const Color(0x1f000000),
  BorderRadius? radius,
}) {
  final count = (width / gap).floor();
  return ClipRRect(
    borderRadius: radius ?? BorderRadius.zero,
    child: SizedBox(
      width: width,
      height: height,
      child: Row(
        children: List.generate(count, (i) {
          return Container(
            width: gap,
            height: height,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: light, width: thickness / 2),
                right: BorderSide(color: dark, width: thickness / 2),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

// ================= เครื่องยนต์ =================
Widget buildEngineIcon({double size = 44}) => _stage(size, [
      // เสื้อสูบ (บล็อกเครื่อง)
      Positioned(
        left: 6,
        top: 26,
        child: Container(
          width: 80,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(9),
              topRight: Radius.circular(7),
              bottomLeft: Radius.circular(7),
              bottomRight: Radius.circular(5),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff8FA4B3), Color(0xff5C7383), Color(0xff3F5260), Color(0xff61798A)],
              stops: [0, .34, .62, 1],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x593F5260), blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
        ),
      ),
      // ครีบระบายความร้อน
      Positioned(left: 12, top: 46, child: _ribs(width: 70, height: 26, radius: BorderRadius.circular(4))),
      // ฝาครอบวาล์ว (สีน้ำเงินตามแบรนด์)
      Positioned(
        left: 14,
        top: 12,
        child: Container(
          width: 58,
          height: 20,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(3)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff4B93D6), Color(0xff1E6FBE), Color(0xff12508F)],
              stops: [0, .48, 1],
            ),
            boxShadow: const [BoxShadow(color: Color(0x66123E64), blurRadius: 6, offset: Offset(0, 3))],
          ),
        ),
      ),
      Positioned(
        left: 18,
        top: 16,
        child: _ribs(
          width: 50,
          height: 12,
          gap: 9,
          thickness: 3,
          light: const Color(0x47ffffff),
          dark: const Color(0x00000000),
          radius: BorderRadius.circular(3),
        ),
      ),
      // พูลเลย์สายพาน
      Positioned(
        left: 60,
        top: 30,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.3, -0.45),
              radius: .95,
              colors: [Color(0xffF2F6F8), Color(0xffA9BAC5), Color(0xff65798A), Color(0xff8EA1AE)],
              stops: [0, .46, .78, 1],
            ),
            boxShadow: [BoxShadow(color: Color(0x66142029), blurRadius: 6, offset: Offset(0, 3))],
          ),
        ),
      ),
      Positioned(
        left: 69,
        top: 39,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.2, -0.3),
              colors: [Color(0xff7B8E9B), Color(0xff374652)],
            ),
          ),
        ),
      ),
      // อ่างน้ำมันเครื่อง
      Positioned(
        left: 2,
        top: 66,
        child: Container(
          width: 78,
          height: 16,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(8)),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xff3B4B57), Color(0xff1E2A33)]),
          ),
        ),
      ),
      // ฝาเติมน้ำมัน
      Positioned(
        left: 30,
        top: 4,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xffDFE7EC), Color(0xff8798A4)]),
            boxShadow: const [BoxShadow(color: Color(0x4d000000), blurRadius: 3, offset: Offset(0, 2))],
          ),
        ),
      ),
    ]);

// ================= ยาง =================
Widget buildTireIcon({double size = 44}) => _stage(size, [
      // แก้มยาง
      Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.32, -0.48),
              radius: 1.0,
              colors: [Color(0xff54606A), Color(0xff22282D), Color(0xff0D1114)],
              stops: [0, .52, .88],
            ),
            boxShadow: [BoxShadow(color: Color(0x730F1419), blurRadius: 10, offset: Offset(0, 5))],
          ),
        ),
      ),
      // ดอกยาง (บล็อกยางเรียงรอบวง)
      Positioned.fill(
        child: Stack(
          children: List.generate(26, (i) {
            return Transform.rotate(
              angle: i * 6.2831853 / 26,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 4,
                  height: 9,
                  color: i.isEven ? const Color(0x24ffffff) : const Color(0x59000000),
                ),
              ),
            );
          }),
        ),
      ),
      // ขอบยางด้านใน
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.28, -0.44),
                colors: [Color(0xff3A4247), Color(0xff141A1E)],
                stops: [0, .7],
              ),
            ),
          ),
        ),
      ),
      // ล้อแม็ก (ก้านล้อด้วย SweepGradient)
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                startAngle: 0.2,
                endAngle: 6.4831853,
                colors: [
                  Color(0xffEEF3F6), Color(0xff93A5B1), Color(0xffF4F8FA), Color(0xff8B9EA9),
                  Color(0xffEEF3F6), Color(0xff93A5B1), Color(0xffF4F8FA), Color(0xff8B9EA9),
                  Color(0xffEEF3F6), Color(0xff93A5B1), Color(0xffEEF3F6),
                ],
                stops: [0, .07, .18, .26, .38, .46, .58, .66, .78, .86, 1],
              ),
              border: Border.all(color: const Color(0x59ffffff), width: 2),
            ),
          ),
        ),
      ),
      // ดุมล้อ
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.24, -0.4),
                colors: [Color(0xffF6FAFC), Color(0xff9FB0BB), Color(0xff6D7F8B)],
                stops: [0, .6, 1],
              ),
            ),
          ),
        ),
      ),
      // ไฮไลต์แสง
      Positioned.fill(
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: Alignment(-0.4, -0.56),
              radius: .7,
              colors: [Color(0x52ffffff), Color(0x00ffffff)],
            ),
          ),
        ),
      ),
    ]);

// ================= แบตเตอรี่ =================
class _BoltClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path();
    p.moveTo(s.width * .58, 0);
    p.lineTo(s.width * .10, s.height * .56);
    p.lineTo(s.width * .44, s.height * .56);
    p.lineTo(s.width * .30, s.height);
    p.lineTo(s.width * .90, s.height * .40);
    p.lineTo(s.width * .52, s.height * .40);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}

Widget _terminal() => Container(
      width: 20,
      height: 12,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xffF2F6F8), Color(0xff8B9BA6), Color(0xff5F6F7A)], stops: [0, .6, 1]),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 3, offset: Offset(0, 2))],
      ),
    );

Widget buildBatteryIcon({double size = 44}) => _stage(size, [
      Positioned(left: 18, top: 14, child: _terminal()),
      Positioned(left: 58, top: 14, child: _terminal()),
      // ฝาบน
      Positioned(
        left: 8,
        top: 24,
        child: Container(
          width: 80,
          height: 16,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xff4D5C68), Color(0xff28323B)]),
          ),
        ),
      ),
      // ตัวหม้อแบต
      Positioned(
        left: 10,
        top: 38,
        child: Container(
          width: 76,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3), bottom: Radius.circular(7)),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff2F3B46), Color(0xff18212A), Color(0xff0E151B)],
              stops: [0, .46, 1],
            ),
            boxShadow: const [BoxShadow(color: Color(0x660F1419), blurRadius: 10, offset: Offset(0, 5))],
          ),
        ),
      ),
      // สติกเกอร์สีเขียว + สายฟ้า
      Positioned(
        left: 10,
        top: 48,
        child: Container(
          width: 76,
          height: 22,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xff43A047), Color(0xff2E7D32)]),
          ),
        ),
      ),
      Positioned(
        left: 40,
        top: 50,
        child: ClipPath(
          clipper: _BoltClipper(),
          child: Container(width: 16, height: 18, color: Colors.white),
        ),
      ),
      // ไฮไลต์ด้านซ้าย
      Positioned(
        left: 14,
        top: 38,
        child: Container(
          width: 10,
          height: 44,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0x38ffffff), Color(0x00ffffff)]),
          ),
        ),
      ),
    ]);

// ================= ซ่อมสี (ลูกกลิ้งทาสี) =================
Widget buildPaintIcon({double size = 44}) => _stage(size, [
      // ลูกกลิ้ง
      Positioned(
        left: 22,
        top: 8,
        child: Transform.rotate(
          angle: -0.14,
          child: Container(
            width: 60,
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xffFFB14D), Color(0xffFB8C00), Color(0xffC96A00)],
                stops: [0, .45, 1],
              ),
              boxShadow: const [BoxShadow(color: Color(0x52783C00), blurRadius: 8, offset: Offset(0, 4))],
            ),
          ),
        ),
      ),
      // ขนลูกกลิ้ง
      Positioned(
        left: 22,
        top: 8,
        child: Transform.rotate(
          angle: -0.14,
          child: _ribs(
            width: 60,
            height: 26,
            gap: 6,
            thickness: 2,
            light: const Color(0x2effffff),
            dark: const Color(0x2e964600),
            radius: BorderRadius.circular(6),
          ),
        ),
      ),
      // ก้านโครเมียม
      Positioned(
        left: 18,
        top: 24,
        child: Transform.rotate(
          angle: 0.59,
          child: Container(
            width: 34,
            height: 9,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xffEEF3F6), Color(0xff9AABB6), Color(0xff6B7B86)], stops: [0, .55, 1]),
            ),
          ),
        ),
      ),
      // ด้ามจับ
      Positioned(
        left: 10,
        top: 52,
        child: Transform.rotate(
          angle: 0.21,
          child: Container(
            width: 16,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xff4D5C68), Color(0xff222B33)]),
              boxShadow: const [BoxShadow(color: Color(0x590F1419), blurRadius: 8, offset: Offset(0, 4))],
            ),
          ),
        ),
      ),
      // ฝาปิดปลายลูกกลิ้ง
      Positioned(
        left: 74,
        top: 6,
        child: Transform.rotate(
          angle: -0.14,
          child: Container(
            width: 12,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xffDFE7EC), Color(0xff7D8E9A)]),
            ),
          ),
        ),
      ),
      // รอยสีที่ทา
      Positioned(
        left: 34,
        top: 60,
        child: Transform.rotate(
          angle: -0.14,
          child: Container(
            width: 44,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                colors: [Color(0xd9FB8C00), Color(0x40FB8C00)],
              ),
            ),
          ),
        ),
      ),
      // หยดสี
      Positioned(
        left: 66,
        top: 44,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(center: Alignment(-0.3, -0.4),
                colors: [Color(0xffFFC477), Color(0xffE07B00)]),
          ),
        ),
      ),
    ]);

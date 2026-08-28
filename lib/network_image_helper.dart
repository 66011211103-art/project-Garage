// lib/network_image_helper.dart
// ============================================================================
// ✅ ตัวช่วยกลาง — ใช้แทน Image.network(...) ตรงๆ ทุกจุดในแอป
//
// ปัญหาเดิม: Image.network ถ้าโหลดรูปไม่สำเร็จ (URL 400/404, ไฟล์หายจาก Storage,
// เน็ตหลุด, timeout ฯลฯ) โดย default จะโชว์เป็นกล่อง error สีแดงเถือกของ Flutter เอง
// (สามเหลี่ยมแดง) ซึ่งผู้ใช้งานจริงเห็นแล้วจะงงว่าแอปพัง — ทั้งที่ทุกอย่างทำงานปกติ
// แค่รูปนั้นรูปเดียวโหลดไม่ขึ้น
//
// เดิมมีแค่ search_page.dart จุดเดียวในแอปที่ใส่ errorBuilder กันไว้เอง ส่วนอีก
// 21 จุดใน 14 ไฟล์ไม่มีเลย จึงรวม logic เดียวกันไว้ที่นี่ที่เดียว แทนการก็อปโค้ด
// ซ้ำๆ กันทุกจุด (ถ้าจะปรับหน้าตา fallback ทีหลัง แก้ที่เดียวจบ)
// ============================================================================
import 'package:flutter/material.dart';
import 'app_locale.dart';

class NetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const NetImage(this.url, {super.key, this.width, this.height, this.fit});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // ignore: avoid_print
        print('⚠️ โหลดรูปไม่สำเร็จ: $url — $error');
        // ช่องเล็ก (ไอคอน/รูปย่อ) โชว์แค่ไอคอน ช่องใหญ่โชว์ไอคอน+ข้อความด้วย
        final compact = (height != null && height! < 80) || (width != null && width! < 80);
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: compact
              ? Icon(Icons.broken_image_outlined, size: 20, color: Colors.grey.shade400)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text(AppLocale.instance.t('search_image_load_failed'), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
        );
      },
    );
  }
}

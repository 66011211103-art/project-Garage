import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// ศูนย์ช่วยเหลือ — คำถามที่พบบ่อย ตรงกับฟีเจอร์ที่มีอยู่จริงในแอปตอนนี้เท่านั้น
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const List<Map<String, String>> _faqs = [
    {
      'q': 'ค้นหาอู่ซ่อมรถใกล้ฉันได้อย่างไร',
      'a': 'ไปที่แท็บ "ค้นหา" หน้าแรก ระบบจะแสดงรายชื่ออู่ซ่อมพร้อมระยะทางจากตำแหน่งปัจจุบันของคุณ '
          'สามารถกดดูรายละเอียดแต่ละอู่ เช่น เวลาทำการ บริการที่ให้บริการ และตำแหน่งบนแผนที่ได้',
    },
    {
      'q': 'ส่งคำขอซ่อมไปยังอู่อย่างไร',
      'a': 'เปิดหน้ารายละเอียดอู่ที่ต้องการ กดปุ่ม "ส่งคำขอซ่อม" เลือกประเภทรถ ประเภทปัญหา '
          'อธิบายอาการ แนบรูปได้สูงสุด 5 รูป และระบุที่อยู่/ตำแหน่งของคุณ แล้วกดส่งคำขอ',
    },
    {
      'q': 'ดูสถานะคำขอซ่อมได้ที่ไหน',
      'a': 'ไปที่แท็บ "ประวัติ" จะเห็นสถานะล่าสุดของทุกคำขอ ตั้งแต่รอตอบรับ, อู่รับงานแล้ว, '
          'มีใบเสนอราคาใหม่ ไปจนถึงเสร็จสิ้น หากอู่ปฏิเสธจะแสดงเหตุผลให้เห็นในหน้านี้ด้วย',
    },
    {
      'q': 'ใบเสนอราคาคืออะไร ต้องทำอย่างไรต่อ',
      'a': 'หลังอู่รับงานแล้ว อู่จะประเมินและส่งใบเสนอราคามาให้ คุณสามารถกดยืนยันหรือปฏิเสธ '
          'ใบเสนอราคาได้จากหน้าประวัติคำขอซ่อมของคุณโดยตรง',
    },
    {
      'q': 'ลืมรหัสผ่าน ต้องทำอย่างไร',
      'a': 'ที่หน้าเข้าสู่ระบบ กด "ลืมรหัสผ่าน?" กรอกอีเมลที่ใช้สมัคร ระบบจะส่งรหัส OTP ไปทางอีเมล '
          'นำรหัสมากรอกเพื่อตั้งรหัสผ่านใหม่ได้ทันที',
    },
    {
      'q': 'เปลี่ยนอีเมล/รหัสผ่านได้ที่ไหน',
      'a': 'ไปที่โปรไฟล์ → ไอคอนฟันเฟือง (ตั้งค่า) → บัญชีของฉัน จะมีเมนูเปลี่ยนอีเมลและเปลี่ยนรหัสผ่านแยกไว้ให้',
    },
    {
      'q': 'ส่งตำแหน่งปัจจุบันให้อู่ได้อย่างไร',
      'a': 'ในหน้ารายละเอียดคำขอซ่อม กดปุ่ม "ส่งตำแหน่งปัจจุบันให้อู่" ระบบจะขอสิทธิ์เข้าถึงตำแหน่ง '
          'แล้วส่งพิกัดล่าสุดให้อู่เห็นทันที ใช้ได้ทั้งตอนอู่ขอตำแหน่งมาหรือส่งล่วงหน้าเองก็ได้',
    },
  ];

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@outeewaiwangjai.example.com',
      query: 'subject=${Uri.encodeComponent('สอบถามการใช้งานแอปอู่ที่ไว้วางใจ')}',
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบแอปอีเมลในเครื่อง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('ศูนย์ช่วยเหลือ', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'คำถามที่พบบ่อย',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: _faqs.asMap().entries.map((entry) {
                final index = entry.key;
                final faq = entry.value;
                return Column(
                  children: [
                    ExpansionTile(
                      title: Text(
                        faq['q']!,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          faq['a']!,
                          style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                        ),
                      ],
                    ),
                    if (index < _faqs.length - 1) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'ยังไม่พบคำตอบที่ต้องการ?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ติดต่อฝ่ายสนับสนุนของเราได้โดยตรง เราจะตอบกลับภายใน 1-2 วันทำการ',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _contactSupport(context),
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: const Text('ส่งอีเมลถึงฝ่ายสนับสนุน'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2196F3),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_locale.dart';

/// ศูนย์ช่วยเหลือ — คำถามที่พบบ่อย + ฟอร์มแจ้งข้อร้องเรียนจริง (เชื่อม backend)
class HelpPage extends StatefulWidget {
  // ✅ เพิ่มใหม่: รับ userData ต่อจากหน้าที่เปิดมา (ตั้งค่า/โปรไฟล์) เพื่อใช้แจ้งข้อร้องเรียน
  // ผูกกับผู้ใช้ที่ล็อกอินอยู่จริง — ไม่มีข้อมูลก็ยังเข้าดู FAQ ได้ปกติ แค่แจ้งข้อร้องเรียนไม่ได้
  final Map<String, dynamic>? userData;

  const HelpPage({super.key, this.userData});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
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

  final _subjectController = TextEditingController();
  final _detailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  // ✅ เพิ่มใหม่: แจ้งข้อร้องเรียนจริง — ยิงไป POST /api/complaints แล้วแอดมินเห็นทันทีใน
  // หน้า "รีวิว & ข้อร้องเรียน" ของระบบแอดมิน (เดิมปุ่มติดต่อฝ่ายสนับสนุนในหน้านี้เป็นแค่
  // mailto ไปโดเมนตัวอย่างที่ไม่มีจริง ไม่มีใครได้รับอีเมลเลย — เอาออกแล้วแทนที่ด้วยฟอร์มนี้)
  Future<void> _submitComplaint() async {
    final loc = AppLocale.instance;
    final subject = _subjectController.text.trim();

    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('help_complaint_subject_required'))),
      );
      return;
    }

    final rawId = widget.userData?['id'];
    final reporterId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (reporterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('help_complaint_login_required'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final detail = _detailController.text.trim();
    final result = await ApiService.submitComplaint(
      reporterId: reporterId,
      subject: subject,
      detail: detail.isEmpty ? null : detail,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success ? loc.t('help_complaint_success') : result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (result.success) {
      _subjectController.clear();
      _detailController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F6FA),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
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
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
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
          Text(
            loc.t('help_complaint_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                Text(
                  loc.t('help_complaint_subtitle'),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _subjectController,
                  decoration: _fieldDecoration(loc.t('help_complaint_subject_hint')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _detailController,
                  maxLines: 4,
                  decoration: _fieldDecoration(loc.t('help_complaint_detail_hint')),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitComplaint,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.report_gmailerrorred_outlined, size: 18),
                    label: Text(loc.t('help_complaint_submit')),
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

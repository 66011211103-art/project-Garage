import 'package:flutter/material.dart';

/// เหตุผลปฏิเสธงานสำเร็จรูป ให้อู่เลือกเร็วๆ ไม่ต้องพิมพ์เอง
const List<String> kRejectionReasonPresets = [
  'คิวงานเต็ม ไม่สามารถรับงานเพิ่มได้ในขณะนี้',
  'อู่ไม่มีความชำนาญในการซ่อมประเภทนี้',
  'อยู่นอกพื้นที่ให้บริการของอู่',
  'ไม่มีอะไหล่ที่ต้องใช้ในขณะนี้',
  'ช่วงเวลาที่ลูกค้าต้องการไม่ตรงกับคิวที่ว่าง',
  'ต้องการข้อมูลเพิ่มเติมจากลูกค้าก่อนรับงาน',
  'ราคา/งบประมาณไม่ตรงกับที่ลูกค้าต้องการ',
];

/// เปิด dialog ให้เลือกเหตุผลปฏิเสธ (หรือพิมพ์เอง) แล้วส่งให้ลูกค้า
/// คืนค่าข้อความเหตุผล หรือ null ถ้ายกเลิก
Future<String?> showRejectReasonDialog(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _RejectReasonSheet(),
  );
}

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet();

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  String? _selectedPreset;
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String? get _finalReason {
    if (_customController.text.trim().isNotEmpty) return _customController.text.trim();
    return _selectedPreset;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.close, color: Colors.red),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('ปฏิเสธคำขอซ่อม',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'เลือกเหตุผล หรือพิมพ์เอง ระบบจะแจ้งให้ลูกค้าทราบ',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...kRejectionReasonPresets.map((reason) {
                      final selected = _selectedPreset == reason;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedPreset = selected ? null : reason;
                            _customController.clear();
                          }),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xffFFEBEE) : const Color(0xffF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? Colors.red : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  size: 18,
                                  color: selected ? Colors.red : Colors.grey,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(reason, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    const Text('หรือพิมพ์เหตุผลเอง', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customController,
                      maxLines: 3,
                      onChanged: (_) => setState(() => _selectedPreset = null),
                      decoration: InputDecoration(
                        hintText: 'ระบุเหตุผลอื่นๆ ที่นี่...',
                        filled: true,
                        fillColor: const Color(0xffF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finalReason == null
                    ? null
                    : () => Navigator.pop(context, _finalReason),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ยืนยันการปฏิเสธ',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

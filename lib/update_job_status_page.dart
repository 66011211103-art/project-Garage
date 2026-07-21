// ============================================================
// 📄 ไฟล์: update_job_status_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "อัปเดตสถานะงาน" (Mechanic Update Screen) ฝั่งช่าง
//     เปิดจากปุ่ม "อัปเดตสถานะงาน" ในหน้า technician_job_detail_page.dart
// 📝 คำอธิบาย: ให้ช่างเลือกสถานะใหม่, บันทึกรายละเอียดที่ทำไป, แนบรูป
//     ก่อน/หลังซ่อม และกรอกรายการอะไหล่ที่ใช้ (ชื่อ/จำนวน/ราคา) แล้วส่งอัปเดต
//     ครั้งเดียว (เรียก API 2 ตัว: updateTechnicianJobStatus + createRepairLog)
// ⚠️ หมายเหตุสำคัญ:
//   1) API `updateTechnicianJobStatus` ปัจจุบันรองรับแค่สถานะ 'in_progress'
//      และ 'completed' เท่านั้น จึงมีตัวเลือกให้ 2 สถานะนี้ก่อน ถ้าต้องการ
//      สถานะย่อยเพิ่ม เช่น "กำลังตรวจสอบ" / "รอรับอะไหล่" ตามมอกอัป ต้อง
//      แก้ backend + ฐานข้อมูลเพิ่มสถานะเหล่านี้ก่อน
//   2) API `createRepairLog` เก็บ "อะไหล่ที่ใช้" เป็นข้อความรวมช่องเดียว
//      (partsUsed: String) ไม่ใช่รายการแยกช่องแบบมีโครงสร้าง ฉะนั้นรายการ
//      อะไหล่ที่กรอกในหน้านี้จะถูกรวมเป็นข้อความก่อนส่ง ถ้าต้องการเก็บแบบ
//      โครงสร้างจริง (ชื่อ/จำนวน/ราคาแยกฟิลด์) ต้องแก้ backend เพิ่ม
//   3) รูป "ก่อนซ่อม" และ "หลังซ่อม" ส่งรวมกันเป็น list เดียวไปยัง backend
//      (API ปัจจุบันไม่มีฟิลด์แยกก่อน/หลัง) — ถ้าต้องการแยกเก็บจริง ต้อง
//      เพิ่มฟิลด์ backend เช่นกัน
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class _PartRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  final TextEditingController priceCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class UpdateJobStatusPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final Map<String, dynamic> userData;

  const UpdateJobStatusPage({super.key, required this.job, required this.userData});

  @override
  State<UpdateJobStatusPage> createState() => _UpdateJobStatusPageState();
}

class _UpdateJobStatusPageState extends State<UpdateJobStatusPage> {
  late String _selectedStatus;
  final _noteController = TextEditingController();
  final List<_PartRow> _parts = [_PartRow()];

  Uint8List? _beforePhoto;
  String? _beforePhotoName;
  Uint8List? _afterPhoto;
  String? _afterPhotoName;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // ค่าเริ่มต้น: ถ้ายังไม่เริ่มงาน (assigned) ให้เลือก "กำลังซ่อม" ไว้ก่อน
    final current = widget.job['status']?.toString() ?? 'assigned';
    _selectedStatus = current == 'in_progress' ? 'completed' : 'in_progress';
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto({required bool isBefore}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (isBefore) {
        _beforePhoto = bytes;
        _beforePhotoName = picked.name;
      } else {
        _afterPhoto = bytes;
        _afterPhotoName = picked.name;
      }
    });
  }

  void _addPartRow() => setState(() => _parts.add(_PartRow()));

  void _removePartRow(int index) {
    setState(() {
      _parts[index].dispose();
      _parts.removeAt(index);
    });
  }

  String _buildPartsUsedText() {
    return _parts
        .where((p) => p.nameCtrl.text.trim().isNotEmpty)
        .map((p) {
          final qty = p.qtyCtrl.text.trim();
          final price = p.priceCtrl.text.trim();
          final priceText = price.isNotEmpty ? ' ฿$price' : '';
          return '${p.nameCtrl.text.trim()} x$qty$priceText';
        })
        .join(', ');
  }

  Future<void> _handleSubmit() async {
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรายละเอียดที่ทำไป'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // 1) อัปเดตสถานะงาน
    final statusResult = await ApiService.updateTechnicianJobStatus(
      requestId: widget.job['id'],
      status: _selectedStatus,
    );

    // 2) บันทึกความคืบหน้า (โน้ต + อะไหล่ + รูปก่อน/หลัง)
    final photos = <Uint8List>[];
    final photoNames = <String>[];
    if (_beforePhoto != null) {
      photos.add(_beforePhoto!);
      photoNames.add(_beforePhotoName ?? 'before.jpg');
    }
    if (_afterPhoto != null) {
      photos.add(_afterPhoto!);
      photoNames.add(_afterPhotoName ?? 'after.jpg');
    }

    final logResult = await ApiService.createRepairLog(
      repairRequestId: widget.job['id'],
      technicianId: widget.userData['technician_id'] ?? widget.userData['id'],
      note: _noteController.text.trim(),
      partsUsed: _buildPartsUsedText(),
      photos: photos,
      photoNames: photoNames,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final success = statusResult.success && logResult.success;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'ส่งอัปเดตสำเร็จ' : (statusResult.message.isNotEmpty ? statusResult.message : logResult.message)),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      Navigator.pop(context, {'status': _selectedStatus});
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = '${widget.job['first_name'] ?? ''} ${widget.job['last_name'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('อัปเดตสถานะงาน', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---------- สรุปงาน ----------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('งาน #${widget.job['id']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(customerName.isEmpty ? 'ไม่ระบุชื่อ' : customerName,
                                style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text('อัปเดตสถานะ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _statusOption('in_progress', 'กำลังซ่อม', Icons.build_circle_outlined, const Color(0xffFF9800)),
                _statusOption('completed', 'เสร็จสิ้น', Icons.check_circle_outline, const Color(0xff4CAF50)),

                const SizedBox(height: 16),
                const Text('บันทึกรายละเอียด', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'กรอกรายละเอียดการซ่อม เช่น อันตอนที่ทำ ปัญหาที่พบเพิ่มเติม...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('รูปภาพก่อน/หลังซ่อม', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _photoSlot('ก่อนซ่อม', _beforePhoto, () => _pickPhoto(isBefore: true))),
                    const SizedBox(width: 10),
                    Expanded(child: _photoSlot('หลังซ่อม', _afterPhoto, () => _pickPhoto(isBefore: false))),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('อะไหล่ที่ใช้', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _addPartRow,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('เพิ่มอะไหล่'),
                    ),
                  ],
                ),
                ...List.generate(_parts.length, (index) {
                  final p = _parts[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: p.nameCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'ชื่ออะไหล่', isDense: true, border: OutlineInputBorder()),
                              ),
                            ),
                            if (_parts.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removePartRow(index),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: p.qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'จำนวน', isDense: true, border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: p.priceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'ราคา (บาท)', isDense: true, border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
            ),
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2196F3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                _isSubmitting ? 'กำลังส่ง...' : 'ส่งอัปเดต',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusOption(String value, String label, IconData icon, Color color) {
    final selected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedStatus = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18, color: selected ? color : Colors.grey),
              const SizedBox(width: 10),
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoSlot(String label, Uint8List? photo, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: photo != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(photo, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400),
                  const SizedBox(height: 6),
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
      ),
    );
  }
}

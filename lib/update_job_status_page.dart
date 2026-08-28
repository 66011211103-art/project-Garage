// ============================================================
// 📄 ไฟล์: update_job_status_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "อัปเดตสถานะงาน" (Mechanic Update Screen) ฝั่งช่าง
//     เปิดจากปุ่ม "อัปเดตสถานะงาน" ในหน้า technician_job_detail_page.dart
// 📝 คำอธิบาย: ให้ช่างเลือกสถานะใหม่ (3 แบบ: ช่างกำลังเดินทาง/กำลังซ่อม/ซ่อมเสร็จแล้ว
//     ตรงกับที่ backend รองรับแล้ว — ใช้คำเดียวกับหน้าติดตามสถานะฝั่งลูกค้าเพื่อไม่ให้สับสน)
//     บันทึกรายละเอียดที่ทำไป, แนบรูปก่อน/หลังซ่อม และกรอกรายการอะไหล่ที่ใช้
//     (เฉพาะตอนเลือกสถานะ "กำลังซ่อม" เท่านั้น — อีก 2 สถานะไม่เกี่ยวกับอะไหล่)
//     แล้วส่งอัปเดตครั้งเดียว (เรียก API 2 ตัว: updateTechnicianJobStatus + createRepairLog)
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'app_locale.dart';

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
  // ✅ โผล่เฉพาะตอนเลือกสถานะ "กำลังซ่อม" (in_progress) เท่านั้น — อีก 2 สถานะไม่โชว์
  final List<_PartRow> _parts = [_PartRow()];

  Uint8List? _beforePhoto;
  String? _beforePhotoName;
  Uint8List? _afterPhoto;
  String? _afterPhotoName;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // ค่าเริ่มต้น: เลือกสถานะถัดไปที่สมเหตุสมผลจากสถานะปัจจุบัน
    final current = widget.job['status']?.toString() ?? 'assigned';
    switch (current) {
      case 'assigned':
        _selectedStatus = 'checking';
        break;
      case 'checking':
        _selectedStatus = 'in_progress';
        break;
      case 'waiting_parts':
        _selectedStatus = 'in_progress';
        break;
      default:
        _selectedStatus = 'in_progress';
    }
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    _noteController.dispose();
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
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
      partsUsed: _selectedStatus == 'in_progress' ? _buildPartsUsedText() : '',
      photos: photos,
      photoNames: photoNames,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final success = statusResult.success && logResult.success;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? AppLocale.instance.t('ujs_update_success') : (statusResult.message.isNotEmpty ? statusResult.message : logResult.message)),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      Navigator.pop(context, {'status': _selectedStatus});
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    final customerName = '${widget.job['first_name'] ?? ''} ${widget.job['last_name'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('ujs_page_title'), style: const TextStyle(color: Colors.white)),
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
                            Text(loc.t('ujs_job_number_prefix').replaceAll('%s', '${widget.job['id']}'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(customerName.isEmpty ? loc.t('profile_name_fallback') : customerName,
                                style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Text(loc.t('ujs_update_status_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _statusOption('checking', loc.t('dash_status_checking'), loc.t('ujs_status_checking_subtitle'),
                    Icons.directions_car_outlined, const Color(0xff9C27B0)),
                _statusOption('in_progress', loc.t('dash_status_in_progress'), loc.t('ujs_status_in_progress_subtitle'),
                    Icons.build_circle_outlined, const Color(0xffFF9800)),
                _statusOption('completed', loc.t('tech_status_completed'), loc.t('ujs_status_completed_subtitle'),
                    Icons.check_circle_outline, const Color(0xff4CAF50)),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(loc.t('ujs_log_details_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    Text(loc.t('ujs_optional_label'), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: loc.t('ujs_details_hint'),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text(loc.t('ujs_photos_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _photoSlot(loc.t('ujs_photo_before'), _beforePhoto, () => _pickPhoto(isBefore: true))),
                    const SizedBox(width: 10),
                    Expanded(child: _photoSlot(loc.t('ujs_photo_after'), _afterPhoto, () => _pickPhoto(isBefore: false))),
                  ],
                ),

                // ✅ โผล่เฉพาะตอนเลือกสถานะ "กำลังซ่อม" (in_progress) เท่านั้น —
                // เลือก "ช่างกำลังเดินทาง" หรือ "ซ่อมเสร็จแล้ว" จะไม่เห็นส่วนนี้
                if (_selectedStatus == 'in_progress') ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.t('ujs_parts_used_title'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: _addPartRow,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(loc.t('ujs_add_part_button')),
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
                                  decoration: InputDecoration(
                                      labelText: loc.t('ujs_part_name_label'), isDense: true, border: const OutlineInputBorder()),
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
                                  decoration: InputDecoration(
                                      labelText: loc.t('ujs_part_qty_label'), isDense: true, border: const OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: p.priceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: loc.t('ujs_part_price_label'), isDense: true, border: const OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
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
                _isSubmitting ? loc.t('ujs_sending') : loc.t('ujs_send_update_button'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusOption(String value, String label, String subtitle, IconData icon, Color color) {
    final selected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selectedStatus = value),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 2 : 1),
            boxShadow: selected
                ? [BoxShadow(color: color.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? color : color.withOpacity(0.12),
                ),
                child: Icon(icon, size: 20, color: selected ? Colors.white : color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: selected ? color : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_off,
                color: selected ? color : Colors.grey.shade300,
                size: 22,
              ),
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
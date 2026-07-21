// ============================================================
// 📄 ไฟล์: assign_technician_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "มอบหมายงานช่าง" (Assign Mechanic Screen) ฝั่งอู่
//     เปิดจากปุ่ม "รับงาน" ในการ์ดคำขอซ่อมของ garage_dashboard.dart
// 📝 คำอธิบาย: แสดงสรุปงาน (ลูกค้า/ประเภทงาน/เลขที่งาน), รายชื่อช่างในสังกัด
//     ให้เลือก 1 คน (ดึงจาก ApiService.getTechnicians), วันที่มอบหมาย,
//     หมายเหตุ แล้วกด "ยืนยันการมอบหมายงาน" — ระบบจะรับงาน (accepted) และ
//     มอบหมายให้ช่างที่เลือกในขั้นตอนเดียว
// ⚠️ หมายเหตุสำคัญ (โปรดอ่านก่อนใช้งานจริง):
//   1) "วันที่มอบหมาย" และ "หมายเหตุ" ในหน้านี้เป็น UI ที่ทำไว้ให้ตรงกับ
//      มอกอัปเท่านั้น — API `assignTechnician` ปัจจุบัน**ไม่มีพารามิเตอร์**
//      รับวันที่/หมายเหตุ ข้อมูล 2 ช่องนี้จึง "ยังไม่ถูกบันทึกจริง" ต้องแก้
//      backend เพิ่ม field ก่อนถึงจะใช้งานได้ครบ
//   2) badge "ว่าง/ไม่ว่าง" และ "รับงานอยู่ N งาน" ต่อการ์ดช่าง มาจากฟิลด์
//      `status` ที่ตอบกลับจาก ApiService.getTechnicians เท่านั้น (active =
//      ว่าง, inactive = ไม่ว่าง) — ไม่ได้คำนวณจำนวนงานที่ถืออยู่จริง เพราะ
//      API ปัจจุบันไม่ได้ส่งจำนวนงานต่อช่างมาด้วย ถ้าต้องการตัวเลขนี้จริง
//      ต้องเพิ่ม field จาก backend เช่นกัน
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';

const List<String> _thaiMonthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

class AssignTechnicianPage extends StatefulWidget {
  final Map<String, dynamic> request; // คำขอซ่อมที่กำลังจะรับ
  final Map<String, dynamic> userData; // ข้อมูลอู่ (garage)

  const AssignTechnicianPage({super.key, required this.request, required this.userData});

  @override
  State<AssignTechnicianPage> createState() => _AssignTechnicianPageState();
}

class _AssignTechnicianPageState extends State<AssignTechnicianPage> {
  bool _isLoadingTechs = true;
  List<Map<String, dynamic>> _technicians = [];
  int? _selectedTechnicianId;

  DateTime _assignDate = DateTime.now();
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchTechnicians() async {
    setState(() => _isLoadingTechs = true);
    final result = await ApiService.getTechnicians(garageId: widget.userData['id']);
    if (!mounted) return;
    setState(() {
      _isLoadingTechs = false;
      _technicians = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['technicians'] ?? [])
          : [];
    });
  }

  Future<void> _pickAssignDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assignDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _assignDate = picked);
  }

  String _fmtThaiDate(DateTime d) {
    final buddhistYear = d.year + 543;
    return '${d.day} ${_thaiMonthsFull[d.month - 1]} $buddhistYear';
  }

  Future<void> _handleConfirm() async {
    if (_selectedTechnicianId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกช่างผู้รับผิดชอบ'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // 1) รับงาน (เปลี่ยนสถานะคำขอเป็น accepted)
    final acceptResult = await ApiService.updateRepairRequestStatus(
      requestId: widget.request['id'],
      status: 'accepted',
    );

    // 2) มอบหมายให้ช่างที่เลือก
    final assignResult = acceptResult.success
        ? await ApiService.assignTechnician(
            requestId: widget.request['id'],
            technicianId: _selectedTechnicianId!,
          )
        : null;

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final success = acceptResult.success && (assignResult?.success ?? false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'มอบหมายงานสำเร็จ'
            : (assignResult?.message ?? acceptResult.message)),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final customerName = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('มอบหมายงานช่าง', style: TextStyle(color: Colors.white)),
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
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.assignment_outlined, size: 18, color: Color(0xff2196F3)),
                          const SizedBox(width: 8),
                          const Text('สรุปงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _summaryRow('ลูกค้า', customerName.isEmpty ? 'ไม่ระบุชื่อ' : customerName),
                      const SizedBox(height: 6),
                      _summaryRow('ประเภทงาน', r['problem_category']?.toString() ?? '-'),
                      const SizedBox(height: 6),
                      _summaryRow('เลขที่งาน', '#REQ${r['id'].toString().padLeft(6, '0')}'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Text('เลือกช่างผู้รับผิดชอบ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                if (_isLoadingTechs)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_technicians.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: const Column(
                      children: [
                        Icon(Icons.engineering_outlined, size: 44, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('ยังไม่มีช่างในสังกัด', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                else
                  ..._technicians.map(_technicianCard),

                const SizedBox(height: 16),
                const Text('รายละเอียดการมอบหมาย', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text('วันที่มอบหมาย', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickAssignDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xff2196F3)),
                        const SizedBox(width: 10),
                        Text(_fmtThaiDate(_assignDate)),
                        const Spacer(),
                        const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Text('หมายเหตุ (ถ้ามี)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'เพิ่มหมายเหตุสำหรับช่าง...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
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
              onPressed: _isSubmitting ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2196F3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                _isSubmitting ? 'กำลังดำเนินการ...' : 'ยืนยันการมอบหมายงาน',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _technicianCard(Map<String, dynamic> tech) {
    final id = tech['id'] as int?;
    final selected = _selectedTechnicianId == id;
    final status = tech['status']?.toString() ?? 'active';
    final available = status == 'active';
    final specialties = (tech['specialties'] is List) ? List<dynamic>.from(tech['specialties']) : [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: available ? () => setState(() => _selectedTechnicianId = id) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xff2196F3) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xffE3F2FD),
                backgroundImage: (tech['avatar_url']?.toString().isNotEmpty ?? false)
                    ? NetworkImage(tech['avatar_url'].toString())
                    : null,
                child: (tech['avatar_url']?.toString().isNotEmpty ?? false)
                    ? null
                    : const Icon(Icons.person, color: Color(0xff2196F3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(tech['name']?.toString() ?? 'ไม่ระบุชื่อ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (available ? Colors.green : Colors.red).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            available ? 'ว่าง' : 'ไม่ว่าง',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: available ? Colors.green.shade700 : Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                    if (specialties.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: specialties
                            .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffF0F4F8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(s.toString(), style: const TextStyle(fontSize: 10)),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? const Color(0xff2196F3) : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

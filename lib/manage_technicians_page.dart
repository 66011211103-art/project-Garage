// ============================================================
// 📄 ไฟล์: manage_technicians_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "จัดการช่าง" ฝั่งอู่ — เปิดจากปุ่ม "จัดการงาน" ใน
//     เมนูด่วนของ garage_dashboard.dart
// 📝 คำอธิบาย: ดูรายชื่อช่างทั้งหมดในสังกัด (ApiService.getTechnicians),
//     เปิด/ปิดการใช้งานบัญชีช่างแต่ละคน (updateTechnicianStatus) และเพิ่ม
//     ช่างใหม่ผ่านฟอร์ม (createTechnician) — ใช้ API ที่มีอยู่แล้วในระบบ
//     แต่ก่อนหน้านี้ยังไม่มีหน้า UI มาเรียกใช้เลย
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';

class ManageTechniciansPage extends StatefulWidget {
  final Map<String, dynamic> userData; // ข้อมูลอู่ (garage)

  const ManageTechniciansPage({super.key, required this.userData});

  @override
  State<ManageTechniciansPage> createState() => _ManageTechniciansPageState();
}

class _ManageTechniciansPageState extends State<ManageTechniciansPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _technicians = [];

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    setState(() => _isLoading = true);

    // ✅ แปลง garageId ให้เป็น int แบบปลอดภัย กันแอปพังเป็นหน้าจอแดง
    final garageId = int.tryParse(widget.userData['id'].toString());
    if (garageId == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _technicians = [];
      });
      return;
    }

    try {
      final result = await ApiService.getTechnicians(garageId: garageId);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _technicians = result.success && result.data != null
            ? List<Map<String, dynamic>>.from(result.data!['technicians'] ?? [])
            : [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _technicians = [];
      });
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> tech) async {
    final current = tech['status']?.toString() ?? 'active';
    final next = current == 'active' ? 'inactive' : 'active';

    final result = await ApiService.updateTechnicianStatus(
      technicianId: tech['id'],
      status: next,
    );

    if (!mounted) return;
    if (result.success) {
      setState(() => tech['status'] = next);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openAddTechnicianSheet() async {
    // ✅ ใช้ StatefulWidget แยกต่างหาก (ไม่ใช่ local controller + StatefulBuilder)
    //     เพราะเมื่อก่อน dispose() ของ controller ถูกเรียกทันทีตอน await
    //     showModalBottomSheet คืนค่า แต่ตอนนั้น animation ปิด sheet ยังไม่จบ
    //     (TextField ยังอยู่บนจอระหว่าง transition) เลยเกิด error
    //     "A TextEditingController was used after being disposed"
    //     การแยกเป็น widget ของตัวเอง ทำให้ framework เรียก dispose()
    //     ตอน widgetถูกถอดออกจาก tree จริง ๆ เท่านั้น ปลอดภัยกว่า
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AddTechnicianSheet(garageIdRaw: widget.userData['id']),
    );

    if (added == true) _fetchTechnicians();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('จัดการช่าง', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTechnicianSheet,
        backgroundColor: const Color(0xff2196F3),
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text('เพิ่มช่าง', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTechnicians,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _technicians.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 100),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.engineering_outlined, size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('ยังไม่มีช่างในสังกัด', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text('กดปุ่ม "เพิ่มช่าง" ด้านล่างเพื่อเริ่มต้น',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _technicians.length,
                    itemBuilder: (context, index) => _technicianCard(_technicians[index]),
                  ),
      ),
    );
  }

  Widget _technicianCard(Map<String, dynamic> tech) {
    final active = (tech['status']?.toString() ?? 'active') == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xffE3F2FD),
            child: const Icon(Icons.person, color: Color(0xff2196F3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tech['name']?.toString() ?? 'ไม่ระบุชื่อ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(tech['phone']?.toString() ?? '-', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(tech['email']?.toString() ?? '-', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: active,
                activeColor: const Color(0xff4CAF50),
                onChanged: (_) => _toggleStatus(tech),
              ),
              Text(active ? 'ใช้งาน' : 'ปิดใช้งาน',
                  style: TextStyle(fontSize: 10, color: active ? Colors.green.shade700 : Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ✅ ฟอร์ม "เพิ่มช่างใหม่" แยกเป็น StatefulWidget ของตัวเอง
//     เพื่อให้ TextEditingController ถูก dispose โดย framework
//     เอง ตอน widget ถูกถอดออกจาก tree จริง ๆ (หลัง animation
//     ปิด sheet จบสมบูรณ์) แก้ปัญหา "used after being disposed"
// ============================================================
class _AddTechnicianSheet extends StatefulWidget {
  final dynamic garageIdRaw; // ค่า id ของอู่ ก่อนแปลงเป็น int

  const _AddTechnicianSheet({required this.garageIdRaw});

  @override
  State<_AddTechnicianSheet> createState() => _AddTechnicianSheetState();
}

class _AddTechnicianSheetState extends State<_AddTechnicianSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    // ✅ ปลอดภัยเสมอ เพราะ framework เรียกตอน widget นี้ถูกถอดออก
    //     จาก tree จริง ๆ เท่านั้น (ไม่ใช่ตอน await ของ Future คืนค่า)
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xffF5F5F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }

  Future<void> _handleSubmit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบ'), backgroundColor: Colors.red),
      );
      return;
    }

    // ✅ แปลง garageId ให้เป็น int แบบปลอดภัย กัน error กรณี id
    //     เก็บมาเป็น String (เช่น จาก SharedPreferences)
    final garageId = int.tryParse(widget.garageIdRaw.toString());
    if (garageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลอู่ กรุณาเข้าสู่ระบบใหม่อีกครั้ง'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await ApiService.createTechnician(
        garageId: garageId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      if (result.success) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เพิ่มช่างไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เพิ่มช่างใหม่', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: _fieldDecoration('ชื่อ-นามสกุล'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration('เบอร์โทร'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration('อีเมล'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: _fieldDecoration('รหัสผ่านเริ่มต้น'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('เพิ่มช่าง', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
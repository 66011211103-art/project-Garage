import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

/// หน้าติดตามสถานะการซ่อม (Tracking Screen) — ใช้ร่วมกันทั้งฝั่งลูกค้าและอู่
/// ลูกค้าเห็นปุ่ม "ติดต่อช่าง", อู่เห็นแบบอ่านอย่างเดียว (ไม่มีปุ่มโทร ให้ไปโทรจากที่อื่น)
class RepairTrackingPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final bool isCustomerView;

  const RepairTrackingPage({super.key, required this.job, this.isCustomerView = true});

  @override
  State<RepairTrackingPage> createState() => _RepairTrackingPageState();
}

// ✅ ลำดับขั้นตอนจริงตามสถานะที่ระบบมี (ไม่ได้ใส่ "ช่างกำลังเดินทาง" เพราะไม่มีข้อมูลสถานะนี้จริงในระบบ)
const List<Map<String, String>> _steps = [
  {'status': 'assigned', 'label': 'รับงานแล้ว'},
  {'status': 'checking', 'label': 'กำลังตรวจสอบ'},
  {'status': 'in_progress', 'label': 'กำลังซ่อม'},
  {'status': 'completed', 'label': 'ซ่อมเสร็จ'},
];

class _RepairTrackingPageState extends State<RepairTrackingPage> {
  bool _isLoadingLogs = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoadingLogs = true);
    final result = await ApiService.getRepairLogs(repairRequestId: widget.job['id']);
    if (!mounted) return;
    setState(() {
      _isLoadingLogs = false;
      _logs = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['logs'] ?? [])
          : [];
    });
  }

  String _vehicleLabel(String? value) {
    switch (value) {
      case 'sedan':
        return 'รถเก๋ง';
      case 'suv':
        return 'SUV';
      case 'pickup':
        return 'กระบะ';
      default:
        return 'ไม่ระบุ';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'รอการตอบรับจากอู่';
      case 'accepted':
        return 'อู่รับงานแล้ว รอมอบหมายช่าง';
      case 'assigned':
        return 'รับงานแล้ว';
      case 'checking':
        return 'กำลังตรวจสอบ';
      case 'in_progress':
        return 'กำลังซ่อม';
      case 'waiting_parts':
        return 'รอรับอะไหล่';
      case 'completed':
        return 'ซ่อมเสร็จแล้ว';
      case 'rejected':
        return 'ถูกปฏิเสธ';
      default:
        return status;
    }
  }

  String _statusDescription(String status) {
    switch (status) {
      case 'checking':
        return 'ช่างกำลังตรวจเช็คอาการรถของคุณ';
      case 'in_progress':
        return 'ช่างกำลังดำเนินการซ่อมรถของคุณ';
      case 'waiting_parts':
        return 'กำลังรออะไหล่ อาจใช้เวลาเพิ่มเติม';
      case 'completed':
        return 'ซ่อมเสร็จเรียบร้อยแล้ว';
      default:
        return 'รอการดำเนินการ';
    }
  }

  String _formatTime(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '');
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
  }

  Future<void> _callTechnician(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  int get _currentStepIndex {
    final status = widget.job['status']?.toString() ?? 'assigned';
    final index = _steps.indexWhere((s) => s['status'] == status);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.job['status']?.toString() ?? 'assigned';
    final technicianName = widget.job['technician_name']?.toString();
    final technicianPhone = widget.job['technician_phone']?.toString();
    final shopName = widget.job['shop_name']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('ติดตามสถานะการซ่อม', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLogs,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ===== แถบสถานะปัจจุบัน =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xff2196F3), Color(0xff1976D2)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.build_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('สถานะปัจจุบัน', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(_statusLabel(status),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(_statusDescription(status),
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text('ขั้นตอนการซ่อม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),

            // ===== Stepper =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: List.generate(_steps.length, (index) {
                  final done = index < _currentStepIndex ||
                      (index == _currentStepIndex && status == 'completed');
                  final active = index == _currentStepIndex && status != 'completed';
                  final isLast = index == _steps.length - 1;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done
                                    ? const Color(0xff4CAF50)
                                    : active
                                        ? const Color(0xff2196F3)
                                        : Colors.grey.shade300,
                              ),
                              child: Icon(
                                done ? Icons.check : (active ? Icons.build : Icons.circle),
                                size: done || active ? 16 : 8,
                                color: Colors.white,
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  color: done ? const Color(0xff4CAF50) : Colors.grey.shade300,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _steps[index]['label']!,
                                  style: TextStyle(
                                    fontWeight: done || active ? FontWeight.bold : FontWeight.normal,
                                    color: done || active ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                                if (!done && !active)
                                  const Text('รอดำเนินการ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),
            const Text('รายละเอียดงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (technicianName != null)
                    _detailRow(Icons.engineering_outlined, 'ช่างผู้รับผิดชอบ', technicianName),
                  if (shopName != null) _detailRow(Icons.home_repair_service_outlined, 'อู่ซ่อมรถ', shopName),
                  _detailRow(Icons.build_outlined, 'ประเภทปัญหา', widget.job['problem_category']?.toString() ?? '-'),
                  _detailRow(Icons.directions_car_outlined, 'ประเภทรถ',
                      _vehicleLabel(widget.job['vehicle_type']?.toString())),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text('ไทม์ไลน์ความคืบหน้า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            if (_isLoadingLogs)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_logs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Text('ยังไม่มีบันทึกความคืบหน้าจากช่าง', style: TextStyle(color: Colors.grey)),
              )
            else
              ..._logs.map((log) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(log['technician_name']?.toString() ?? 'ช่าง',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(_formatTime(log['created_at']?.toString()),
                                style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        if ((log['note']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(log['note'].toString(), style: const TextStyle(fontSize: 13)),
                        ],
                      ],
                    ),
                  )),

            if (status != 'completed') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xffE3F2FD), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xff2196F3)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('ช่างจะแจ้งให้ทราบเมื่อซ่อมเสร็จ',
                          style: TextStyle(color: Color(0xff2196F3), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],

            if (widget.isCustomerView && technicianPhone != null && technicianPhone.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _callTechnician(technicianPhone),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.call, color: Colors.white),
                  label: const Text('ติดต่อช่าง', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xff2196F3)),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

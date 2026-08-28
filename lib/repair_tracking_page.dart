import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'app_locale.dart';

/// หน้าติดตามสถานะการซ่อม (Tracking Screen) — ใช้ร่วมกันทั้งฝั่งลูกค้าและอู่
/// ลูกค้าเห็นปุ่ม "ติดต่อช่าง", อู่เห็นแบบอ่านอย่างเดียว (ไม่มีปุ่มโทร ให้ไปโทรจากที่อื่น)
class RepairTrackingPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final bool isCustomerView;

  const RepairTrackingPage({super.key, required this.job, this.isCustomerView = true});

  @override
  State<RepairTrackingPage> createState() => _RepairTrackingPageState();
}

// ✅ ลำดับขั้นตอนจริงตามสถานะที่ระบบมี — เปลี่ยนคำอธิบายขั้น "checking" ให้ตรงกับ
// ดีไซน์ที่ขอ (แสดงเป็น "ช่างกำลังเดินทาง" แทน "กำลังตรวจสอบ" เฉพาะหน้านี้)
const List<Map<String, String>> _steps = [
  {'status': 'assigned', 'labelKey': 'dash_status_assigned'},
  {'status': 'checking', 'labelKey': 'dash_status_checking'},
  {'status': 'in_progress', 'labelKey': 'dash_status_in_progress'},
  {'status': 'completed', 'labelKey': 'track_step_completed'},
];

class _RepairTrackingPageState extends State<RepairTrackingPage> {
  bool _isLoadingLogs = true;
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic>? _quotation;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _fetchQuotation();
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
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

  Future<void> _fetchQuotation() async {
    final result = await ApiService.getQuotation(repairRequestId: widget.job['id']);
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() => _quotation = result.data!['quotation'] as Map<String, dynamic>?);
    }
  }

  String _vehicleLabel(String? value) {
    final loc = AppLocale.instance;
    switch (value) {
      case 'sedan':
        return loc.t('tech_vehicle_sedan');
      case 'suv':
        return 'SUV';
      case 'pickup':
        return loc.t('tech_vehicle_pickup');
      default:
        return loc.t('garage_address_fallback');
    }
  }

  String _statusLabel(String status) {
    final loc = AppLocale.instance;
    switch (status) {
      case 'pending':
        return loc.t('track_status_pending');
      case 'accepted':
        return loc.t('track_status_accepted');
      case 'assigned':
        return loc.t('dash_status_assigned');
      case 'checking':
        return loc.t('dash_status_checking');
      case 'in_progress':
        return loc.t('dash_status_in_progress');
      case 'waiting_parts':
        return loc.t('dash_status_waiting_parts');
      case 'completed':
        return loc.t('tech_status_completed');
      case 'rejected':
        return loc.t('track_status_rejected');
      default:
        return status;
    }
  }

  String _statusDescription(String status) {
    final loc = AppLocale.instance;
    switch (status) {
      case 'checking':
        return loc.t('track_desc_checking');
      case 'in_progress':
        return loc.t('track_desc_in_progress');
      case 'waiting_parts':
        return loc.t('track_desc_waiting_parts');
      case 'completed':
        return loc.t('track_desc_completed');
      default:
        return loc.t('track_desc_default');
    }
  }

  String _formatTime(String? isoString) {
    // ✅ backend ส่งเวลาเป็น UTC ISO string — ต้อง .toLocal() ก่อนอ่าน .hour/.minute
    final dt = DateTime.tryParse(isoString ?? '')?.toLocal();
    if (dt == null) return '';
    final timeSuffix = AppLocale.instance.isThai ? ' น.' : '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}$timeSuffix';
  }

  String _formatDateTime(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '')?.toLocal();
    if (dt == null) return '-';
    final buddhistYear2Digit = (dt.year + 543) % 100;
    final timeSuffix = AppLocale.instance.isThai ? ' น.' : '';
    return '${dt.day}/${dt.month}/${buddhistYear2Digit.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}$timeSuffix';
  }

  // ✅ เวลาของแต่ละขั้นตอน — ใช้ข้อมูลจริงเท่าที่มี:
  // ขั้น "รับงานแล้ว" ใช้วันที่มอบหมายงาน (assignment_date ไม่มีเวลากำกับ จึงโชว์แค่วันที่)
  // ขั้นถัดไปประมาณจากเวลาบันทึกความคืบหน้า (repair_logs) เรียงตามลำดับที่ช่างส่งจริง
  // (ระบบยังไม่ได้บันทึกเวลาที่เปลี่ยนสถานะแยกเป็นรายขั้นตอน จึงเป็นการประมาณจากลำดับ log)
  String? _stepTimestamp(int stepIndex) {
    if (stepIndex == 0) {
      final assignmentDate = widget.job['assignment_date']?.toString();
      if (assignmentDate != null && assignmentDate.isNotEmpty) {
        final dt = DateTime.tryParse(assignmentDate)?.toLocal();
        if (dt != null) {
          final buddhistYear2Digit = (dt.year + 543) % 100;
          return '${dt.day}/${dt.month}/${buddhistYear2Digit.toString().padLeft(2, '0')}';
        }
      }
      return null;
    }
    final logIndex = stepIndex - 1;
    if (logIndex < _logs.length) {
      return _formatTime(_logs[logIndex]['created_at']?.toString());
    }
    return null;
  }

  // ✅ ระยะเวลาโดยประมาณ — คำนวณจากช่วงวันที่ในใบเสนอราคาที่อู่ระบุไว้ (ถ้ามี)
  String? get _estimatedDurationText {
    if (_quotation == null) return null;
    final startRaw = _quotation!['estimated_start_date']?.toString();
    final endRaw = _quotation!['estimated_end_date']?.toString();
    final start = DateTime.tryParse(startRaw ?? '');
    final end = DateTime.tryParse(endRaw ?? '');
    if (start == null || end == null) return null;
    final days = end.difference(start).inDays;
    if (days <= 0) return AppLocale.instance.t('track_duration_same_day');
    return AppLocale.instance.t('track_duration_days').replaceAll('%s', '$days');
  }

  Future<void> _callTechnician(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  int get _currentStepIndex {
    var status = widget.job['status']?.toString() ?? 'assigned';
    // ✅ "รอรับอะไหล่" ถือเป็นการหยุดชั่วคราวระหว่างขั้น "กำลังซ่อม" (ไม่ได้มีบล็อกแยกใน
    // stepper 4 ขั้นของฝั่งลูกค้า) จึงจับคู่ให้ไปอยู่ตำแหน่งเดียวกับ in_progress แทน
    // ไม่งั้น indexWhere จะหาไม่เจอ (คืน -1) แล้ว fallback ไปที่ขั้นแรกผิดๆ
    if (status == 'waiting_parts') status = 'in_progress';
    final index = _steps.indexWhere((s) => s['status'] == status);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    final status = widget.job['status']?.toString() ?? 'assigned';
    final technicianName = widget.job['technician_name']?.toString();
    final technicianPhone = widget.job['technician_phone']?.toString();
    final shopName = widget.job['shop_name']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('myreq_track_status_button'), style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_fetchLogs(), _fetchQuotation()]);
        },
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
                        Text(loc.t('track_current_status_label'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
            Text(loc.t('track_steps_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                                  loc.t(_steps[index]['labelKey']!),
                                  style: TextStyle(
                                    fontWeight: done || active ? FontWeight.bold : FontWeight.normal,
                                    color: done || active ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                                if (!done && !active)
                                  Text(loc.t('myreq_status_pending'), style: const TextStyle(color: Colors.grey, fontSize: 12))
                                else if (active && status == 'waiting_parts')
                                  Text(loc.t('track_paused_waiting_parts'),
                                      style: const TextStyle(color: Color(0xff795548), fontSize: 12, fontWeight: FontWeight.w600))
                                else if (_stepTimestamp(index) != null)
                                  Text(_stepTimestamp(index)!,
                                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
            Text(loc.t('track_job_details_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (technicianName != null)
                    _detailRow(Icons.engineering_outlined, loc.t('track_label_technician'), technicianName),
                  if (shopName != null) _detailRow(Icons.home_repair_service_outlined, loc.t('profile_type_repair'), shopName),
                  _detailRow(Icons.build_outlined, loc.t('req_problem_section_title'), widget.job['problem_category']?.toString() ?? '-'),
                  _detailRow(Icons.directions_car_outlined, loc.t('car_type_label'),
                      _vehicleLabel(widget.job['vehicle_type']?.toString())),
                  _detailRow(Icons.access_time, loc.t('track_label_request_time'),
                      _formatDateTime(widget.job['created_at']?.toString())),
                  if (_estimatedDurationText != null)
                    _detailRow(Icons.hourglass_bottom, loc.t('track_label_estimated_time'), _estimatedDurationText!),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(loc.t('track_timeline_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                child: Text(loc.t('track_no_logs'), style: const TextStyle(color: Colors.grey)),
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
                            Text(log['technician_name']?.toString() ?? loc.t('track_technician_fallback'),
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

            if (status == 'completed') ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xffE8F5E9), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: Color(0xff4CAF50)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(loc.t('track_completed_banner'),
                          style: const TextStyle(color: Color(0xff4CAF50), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xffE3F2FD), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xff2196F3)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(loc.t('track_pending_banner'),
                          style: const TextStyle(color: Color(0xff2196F3), fontSize: 12)),
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
                  label: Text(loc.t('track_call_technician_button'), style: const TextStyle(color: Colors.white, fontSize: 16)),
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
import 'package:flutter/material.dart';
import 'api_service.dart';

/// หน้ามอบหมายงานให้ช่าง — ตรงตามดีไซน์ "Assign Mechanic Screen"
class AssignTechnicianPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final int garageId;

  const AssignTechnicianPage({super.key, required this.job, required this.garageId});

  @override
  State<AssignTechnicianPage> createState() => _AssignTechnicianPageState();
}

class _AssignTechnicianPageState extends State<AssignTechnicianPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _technicians = [];
  int? _selectedTechnicianId;
  DateTime _assignmentDate = DateTime.now();
  final _noteController = TextEditingController();

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
    setState(() => _isLoading = true);
    final result = await ApiService.getTechnicians(garageId: widget.garageId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _technicians = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['technicians'] ?? [])
              .where((t) => t['status'] == 'active')
              .toList()
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assignmentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _assignmentDate = picked);
  }

  String _formatThaiDate(DateTime d) {
    const months = [
      'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
      'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year + 543}';
  }

  Future<void> _handleConfirm() async {
    if (_selectedTechnicianId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกช่างก่อน'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ApiService.assignTechnician(
      requestId: widget.job['id'],
      technicianId: _selectedTechnicianId!,
      assignmentDate:
          '${_assignmentDate.year}-${_assignmentDate.month.toString().padLeft(2, '0')}-${_assignmentDate.day.toString().padLeft(2, '0')}',
      assignmentNote: _noteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final customerName = '${widget.job['first_name'] ?? ''} ${widget.job['last_name'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
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
                // ===== สรุปงาน =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.assignment_outlined, size: 18, color: Color(0xff2196F3)),
                          SizedBox(width: 8),
                          Text('สรุปงาน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _summaryRow('ลูกค้า', customerName.isEmpty ? 'ไม่ระบุชื่อ' : customerName),
                      const SizedBox(height: 8),
                      _summaryRow('ประเภทงาน', widget.job['problem_category']?.toString() ?? '-'),
                      const SizedBox(height: 8),
                      _summaryRow('เลขที่งาน', '#REQ${widget.job['id'].toString().padLeft(6, '0')}'),
                      const SizedBox(height: 8),
                      _summaryRow('ประเภทรถ', _vehicleLabel(widget.job['vehicle_type']?.toString())),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text('เลือกช่างผู้รับผิดชอบ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_technicians.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: const Column(
                      children: [
                        Icon(Icons.engineering_outlined, size: 40, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('ยังไม่มีช่างในสังกัด', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),
                        Text('ไปเพิ่มช่างที่หน้า "จัดการช่าง" ก่อน',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                else
                  ..._technicians.map((tech) => _technicianOption(tech)),

                const SizedBox(height: 20),
                const Text('รายละเอียดการมอบหมาย',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                const Text('วันที่มอบหมาย', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xff2196F3)),
                        const SizedBox(width: 10),
                        Text(_formatThaiDate(_assignmentDate)),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('หมายเหตุ (ถ้ามี)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'เพิ่มหมายเหตุสำหรับช่าง...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===== ปุ่มยืนยัน ติดล่าง =====
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
                minimumSize: const Size(double.infinity, 0),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                _isSubmitting ? 'กำลังมอบหมาย...' : 'ยืนยันการมอบหมายงาน',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ],
    );
  }

  Widget _technicianOption(Map<String, dynamic> tech) {
    final id = tech['id'] as int;
    final selected = _selectedTechnicianId == id;
    final activeJobs = tech['active_job_count'] ?? 0;
    final isAvailable = activeJobs == 0;
    final specialties = (tech['specialties']?.toString() ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? const Color(0xff2196F3) : Colors.transparent, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xff2196F3),
                backgroundImage: (tech['avatar']?.toString().isNotEmpty ?? false)
                    ? NetworkImage(tech['avatar'])
                    : null,
                child: (tech['avatar']?.toString().isEmpty ?? true)
                    ? Text((tech['name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tech['name']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (specialties.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          children: specialties
                              .map((s) => Text(s.trim(),
                                  style: const TextStyle(fontSize: 11, color: Color(0xff2196F3))))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: isAvailable ? Colors.green : Colors.red),
                    const SizedBox(width: 4),
                    Text(isAvailable ? 'ว่าง' : 'ไม่ว่าง',
                        style: TextStyle(
                            fontSize: 11, color: isAvailable ? Colors.green.shade800 : Colors.red.shade800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('รับงานอยู่: $activeJobs งาน', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _selectedTechnicianId = selected ? null : id),
              style: OutlinedButton.styleFrom(
                backgroundColor: selected ? const Color(0xff2196F3) : Colors.white,
                foregroundColor: selected ? Colors.white : const Color(0xff2196F3),
                side: const BorderSide(color: Color(0xff2196F3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(selected ? Icons.check : Icons.person_add_alt, size: 16),
              label: Text(selected ? 'เลือกแล้ว' : 'เลือกช่าง'),
            ),
          ),
        ],
      ),
    );
  }
}
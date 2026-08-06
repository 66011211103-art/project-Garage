// ============================================================
// 📄 ไฟล์: garage_job_detail_page.dart
// 📌 หน้า/ฟีเจอร์: หน้ารายละเอียดงานซ่อมแบบเต็มจอ — เปิดจากปุ่ม "ดูรายละเอียด"
//     ในหน้าประวัติงานซ่อมฝั่งอู่ (garage_completed_jobs_page.dart)
// 📝 คำอธิบาย: แทนที่ bottom sheet แบบเดิมที่มีข้อมูลน้อยมาก ด้วยหน้าเต็มที่รวม
//     ข้อมูลลูกค้า/รถ/ปัญหา/รูปภาพ/ที่อยู่/ช่างที่รับผิดชอบ/ใบเสนอราคา/สถานะ
//     การชำระเงินไว้ครบในที่เดียว
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';

class GarageJobDetailPage extends StatefulWidget {
  final Map<String, dynamic> job;

  const GarageJobDetailPage({super.key, required this.job});

  @override
  State<GarageJobDetailPage> createState() => _GarageJobDetailPageState();
}

class _GarageJobDetailPageState extends State<GarageJobDetailPage> {
  Map<String, dynamic>? _quotation;
  bool _isLoadingQuotation = true;

  @override
  void initState() {
    super.initState();
    _fetchQuotation();
  }

  Future<void> _fetchQuotation() async {
    final result = await ApiService.getQuotation(repairRequestId: widget.job['id']);
    if (!mounted) return;

    Map<String, dynamic>? quotation;
    if (result.success && result.data != null) {
      quotation = result.data!['quotation'] as Map<String, dynamic>?;
    }

    setState(() {
      _isLoadingQuotation = false;
      _quotation = quotation;
    });
  }

  String _repairCode(dynamic id) => '#REQ${(id ?? 0).toString().padLeft(6, '0')}';

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

  String _paymentStatusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'ชำระเงินแล้ว';
      case 'pending_confirmation':
        return 'รอตรวจสอบสลิป';
      case 'rejected':
        return 'ปฏิเสธสลิปแล้ว';
      default:
        return 'ยังไม่ชำระเงิน';
    }
  }

  Color _paymentStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xff4CAF50);
      case 'pending_confirmation':
        return const Color(0xffFF9800);
      case 'rejected':
        return const Color(0xffE53935);
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '');
    if (dt == null) return '-';
    final buddhistYear2Digit = (dt.year + 543) % 100;
    return '${dt.day}/${dt.month}/${buddhistYear2Digit.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final name = '${job['first_name'] ?? ''} ${job['last_name'] ?? ''}'.trim();
    final photos = (job['photos'] is List) ? List<dynamic>.from(job['photos']) : [];
    final paymentStatus = job['payment_status']?.toString();
    final amount = double.tryParse(job['payment_amount']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(_repairCode(job['id']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- สถานะ ----------
          _card(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xffE8F5E9), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.task_alt, color: Color(0xff4CAF50), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('ซ่อมเสร็จเรียบร้อยแล้ว', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _paymentStatusColor(paymentStatus).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_paymentStatusLabel(paymentStatus),
                      style: TextStyle(color: _paymentStatusColor(paymentStatus), fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ---------- ข้อมูลลูกค้า/รถ/ปัญหา ----------
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.person_outline, 'ลูกค้า', name.isEmpty ? 'ไม่ระบุชื่อ' : name),
                const Divider(height: 20),
                _infoRow(Icons.directions_car_outlined, 'ประเภทรถ', _vehicleLabel(job['vehicle_type']?.toString())),
                const Divider(height: 20),
                _infoRow(Icons.build_outlined, 'ประเภทปัญหา', job['problem_category']?.toString() ?? '-'),
                if (job['technician_name'] != null) ...[
                  const Divider(height: 20),
                  _infoRow(Icons.engineering_outlined, 'ช่างที่รับผิดชอบ', job['technician_name'].toString()),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ---------- รายละเอียดที่แจ้ง ----------
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('รายละเอียดที่ลูกค้าแจ้ง',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  job['description']?.toString().isNotEmpty == true
                      ? job['description'].toString()
                      : 'ไม่มีรายละเอียดเพิ่มเติม',
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ---------- ที่อยู่ ----------
          _card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    job['address']?.toString().isNotEmpty == true ? job['address'].toString() : 'ไม่ระบุที่อยู่',
                    style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // ---------- รูปภาพ ----------
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('รูปภาพประกอบ',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(photos[i].toString(), width: 96, height: 96, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ---------- ใบเสนอราคา ----------
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ใบเสนอราคา', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 10),
                if (_isLoadingQuotation)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                else if (_quotation == null)
                  const Text('ไม่พบข้อมูลใบเสนอราคา', style: TextStyle(color: Colors.grey, fontSize: 13))
                else ...[
                  ...((_quotation!['items'] is List) ? List<dynamic>.from(_quotation!['items']) : []).map(
                    (it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(child: Text('${it['name']} x${it['quantity'] ?? 1}', style: const TextStyle(fontSize: 13))),
                          Text('฿${double.tryParse(it['price']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  if ((double.tryParse(_quotation!['labor_cost']?.toString() ?? '0') ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          const Expanded(child: Text('ค่าแรง', style: TextStyle(fontSize: 13))),
                          Text('฿${double.tryParse(_quotation!['labor_cost']?.toString() ?? '0')?.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  // ✅ คำนวณ VAT 7% บวกเพิ่มจริงจากค่าอะไหล่+ค่าแรง ให้ตรงกับยอด
                  // ที่ลูกค้าเห็นในใบเสนอราคา (quotation_card.dart) และยอดที่เรียก
                  // เก็บเงินจริงตอนจ่าย (customer_payment_page.dart)
                  Builder(builder: (context) {
                    final partsCost = ((_quotation!['items'] is List) ? List<dynamic>.from(_quotation!['items']) : [])
                        .fold<double>(0, (sum, it) => sum + (double.tryParse(it['price']?.toString() ?? '0') ?? 0));
                    final laborCost = double.tryParse(_quotation!['labor_cost']?.toString() ?? '0') ?? 0;
                    final subTotal = partsCost + laborCost;
                    final vatAmount = subTotal * 0.07;
                    final totalPrice = subTotal + vatAmount;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Expanded(child: Text('ภาษีมูลค่าเพิ่ม 7%', style: TextStyle(fontSize: 13))),
                              Text('฿${vatAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Text('รวมทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                            Text('฿${totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xff4CAF50))),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ],
            ),
          ),

          // ---------- สลิปการชำระเงิน ----------
          if (job['payment_slip'] != null) ...[
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('สลิปการชำระเงิน',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(job['payment_slip'].toString(), fit: BoxFit.contain),
                  ),
                  if (amount > 0) ...[
                    const SizedBox(height: 8),
                    Text('ยอดที่แจ้งโอน: ฿${amount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ---------- วันที่สำคัญ ----------
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.event_outlined, 'วันที่แจ้งซ่อม', _formatDateTime(job['created_at']?.toString())),
                const Divider(height: 20),
                _infoRow(Icons.task_alt, 'ซ่อมเสร็จเมื่อ', _formatDateTime(job['completed_at']?.toString())),
              ],
            ),
          ),

          const SizedBox(height: 20),
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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xff2196F3)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
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
import 'network_image_helper.dart';
import 'app_locale.dart';

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

  String _paymentStatusLabel(String? status) {
    final loc = AppLocale.instance;
    switch (status) {
      case 'confirmed':
        return loc.t('gcj_payment_confirmed');
      case 'pending_confirmation':
        return loc.t('gcj_payment_pending');
      case 'rejected':
        return loc.t('gcj_payment_rejected');
      default:
        return loc.t('gcj_payment_unpaid');
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
    // ✅ backend ส่งเวลาเป็น UTC ISO string — ต้อง .toLocal() ก่อนอ่าน .hour/.day
    final dt = DateTime.tryParse(isoString ?? '')?.toLocal();
    if (dt == null) return '-';
    final buddhistYear2Digit = (dt.year + 543) % 100;
    final timeSuffix = AppLocale.instance.isThai ? ' น.' : '';
    return '${dt.day}/${dt.month}/${buddhistYear2Digit.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}$timeSuffix';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
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
                Expanded(
                  child: Text(loc.t('track_desc_completed'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                _infoRow(Icons.person_outline, loc.t('profile_type_customer'), name.isEmpty ? loc.t('profile_name_fallback') : name),
                const Divider(height: 20),
                _infoRow(Icons.directions_car_outlined, loc.t('car_type_label'), _vehicleLabel(job['vehicle_type']?.toString())),
                const Divider(height: 20),
                _infoRow(Icons.build_outlined, loc.t('req_problem_section_title'), job['problem_category']?.toString() ?? '-'),
                if (job['technician_name'] != null) ...[
                  const Divider(height: 20),
                  _infoRow(Icons.engineering_outlined, loc.t('gjd_label_technician'), job['technician_name'].toString()),
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
                Text(loc.t('gjd_reported_details_title'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  job['description']?.toString().isNotEmpty == true
                      ? job['description'].toString()
                      : loc.t('crd_no_description'),
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
                    job['address']?.toString().isNotEmpty == true ? job['address'].toString() : loc.t('crd_no_address'),
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
                  Text(loc.t('crd_photos_title'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: NetImage(photos[i].toString(), width: 96, height: 96, fit: BoxFit.cover),
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
                Text(loc.t('rrd_quotation_title'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 10),
                if (_isLoadingQuotation)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                else if (_quotation == null)
                  Text(loc.t('gjd_no_quotation'), style: const TextStyle(color: Colors.grey, fontSize: 13))
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
                          Expanded(child: Text(loc.t('gjd_labor_cost'), style: const TextStyle(fontSize: 13))),
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
                              Expanded(child: Text(loc.t('common_vat_7'), style: const TextStyle(fontSize: 13))),
                              Text('฿${vatAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(child: Text(loc.t('common_grand_total'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
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
                  Text(loc.t('gjd_payment_slip_title'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: NetImage(job['payment_slip'].toString(), fit: BoxFit.contain),
                  ),
                  if (amount > 0) ...[
                    const SizedBox(height: 8),
                    Text(loc.t('gjd_transferred_amount_prefix').replaceAll('%s', amount.toStringAsFixed(0)),
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
                _infoRow(Icons.event_outlined, loc.t('crd_label_request_date'), _formatDateTime(job['created_at']?.toString())),
                const Divider(height: 20),
                _infoRow(Icons.task_alt, loc.t('gjd_label_completed_at'), _formatDateTime(job['completed_at']?.toString())),
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
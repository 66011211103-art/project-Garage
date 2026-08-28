// ============================================================
// 📄 ไฟล์: technician_job_detail_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "รายละเอียดงาน" (Mechanic Job Screen) ฝั่งช่าง
// 📝 คำอธิบาย: แสดงข้อมูลลูกค้า, รายละเอียดรถ, คำอธิบายปัญหา (ไฮไลต์กรอบเหลือง),
//     ตำแหน่งงาน + แผนที่พรีวิวปักหมุด + ปุ่มนำทาง, เช็กลิสต์อะไหล่ที่ต้องใช้ (ดึงจากใบเสนอราคาที่
//     ยืนยันแล้วของงานนี้ — ถ้ามี), รูปถ่ายก่อน/หลังซ่อมจากบันทึกความคืบหน้า,
//     ไทม์ไลน์ความคืบหน้า และปุ่มไปหน้าอัปเดตสถานะงาน (update_job_status_page.dart)
// ⚠️ หมายเหตุ: ปุ่ม "นำทาง" ใช้แพ็กเกจ url_launcher เปิด Google Maps —
//     ต้องมี `url_launcher` ใน pubspec.yaml (ตัวเดียวกับที่ใช้ในหน้า dashboard)
// ⚠️ เช็กลิสต์ "อุปกรณ์/อะไหล่ที่ต้องใช้" ดึงจากรายการในใบเสนอราคาจริงของงานนี้
//     (ไม่ได้เดา/สร้างข้อมูลเอง) — ถ้างานนี้ยังไม่มีใบเสนอราคา จะไม่แสดงส่วนนี้
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'update_job_status_page.dart';
import 'network_image_helper.dart';
import 'address_map_page.dart';
import 'app_locale.dart';

const List<String> _thaiMonthsAbbr = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

class TechnicianJobDetailPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final Map<String, dynamic> userData;

  const TechnicianJobDetailPage({super.key, required this.job, required this.userData});

  @override
  State<TechnicianJobDetailPage> createState() => _TechnicianJobDetailPageState();
}

class _TechnicianJobDetailPageState extends State<TechnicianJobDetailPage> {
  late Map<String, dynamic> _job;
  bool _isLoadingLogs = true;
  List<Map<String, dynamic>> _logs = [];

  bool _isLoadingQuotation = true;
  List<dynamic> _quotationItems = [];

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _fetchLogs();
    _fetchQuotationItems();
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
    final result = await ApiService.getRepairLogs(repairRequestId: _job['id']);
    if (!mounted) return;
    setState(() {
      _isLoadingLogs = false;
      _logs = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['logs'] ?? [])
          : [];
    });
  }

  // ✅ ดึงรายการอะไหล่จากใบเสนอราคาของงานนี้ (ถ้ามี) มาแสดงเป็นเช็กลิสต์
  Future<void> _fetchQuotationItems() async {
    setState(() => _isLoadingQuotation = true);
    final result = await ApiService.getQuotation(repairRequestId: _job['id']);
    if (!mounted) return;
    final quotation = result.success ? (result.data?['quotation'] as Map<String, dynamic>?) : null;
    setState(() {
      _isLoadingQuotation = false;
      _quotationItems = (quotation?['items'] is List) ? List<dynamic>.from(quotation!['items']) : [];
    });
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

  String _formatThaiDateTime(String? isoString) {
    if (isoString == null) return '-';
    // ✅ backend ส่งเวลาเป็น UTC ISO string — ต้อง .toLocal() ก่อนอ่าน .hour/.day
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return '-';
    final buddhistYear2Digit = (dt.year + 543) % 100;
    final month = _thaiMonthsAbbr[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month ${buddhistYear2Digit.toString().padLeft(2, '0')}, $hh:$mm';
  }

  // ✅ เปิดแอปแผนที่ "เริ่มต้น" ของเครื่อง แทนที่จะบังคับเปิด Google Maps เสมอ
  //     iOS -> Apple Maps (แอปแผนที่เริ่มต้นของ iPhone), Android/อื่นๆ -> ใช้ geo: ให้เครื่องเลือกแอปแผนที่เอง
  Future<void> _openNavigation() async {
    final point = _customerLatLng;
    final address = _job['address']?.toString() ?? '';
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    final Uri uri;
    if (kIsWeb) {
      // ✅ รันบนเว็บ/เบราว์เซอร์ (เช่นทดสอบผ่าน Chrome) — ไม่มีแอปแผนที่ของเครื่องให้เปิด
      //     เลยเปิดเว็บ Google Maps ในแท็บใหม่แทน ใช้งานได้ทุกเบราว์เซอร์
      uri = point != null
          ? Uri.parse('https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}')
          : Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    } else if (isIOS) {
      uri = point != null
          ? Uri.parse('https://maps.apple.com/?daddr=${point.latitude},${point.longitude}&dirflg=d')
          : Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(address)}');
    } else {
      uri = point != null
          ? Uri.parse('geo:${point.latitude},${point.longitude}?q=${point.latitude},${point.longitude}')
          : Uri.parse('geo:0,0?q=${Uri.encodeComponent(address)}');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.t('tjd_nav_open_failed'))),
      );
    }
  }

  // ✅ พิกัดตำแหน่งลูกค้าที่ปักหมุดไว้ — คืนค่า null ถ้าไม่มีพิกัด (จะได้ซ่อนแผนที่พรีวิวแทนโชว์แผนที่เปล่า)
  LatLng? get _customerLatLng {
    final lat = double.tryParse(_job['latitude']?.toString() ?? '');
    final lng = double.tryParse(_job['longitude']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _openFullMap() {
    final point = _customerLatLng;
    if (point == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressMapPage(
          title: AppLocale.instance.t('tjd_location_header'),
          subtitle: _job['address']?.toString(),
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      ),
    );
  }

  Future<void> _openUpdateStatus() async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpdateJobStatusPage(job: _job, userData: widget.userData),
      ),
    );
    if (updated is Map<String, dynamic>) {
      setState(() => _job = {..._job, ...updated});
      _fetchLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    final status = _job['status']?.toString() ?? 'assigned';
    final customerName = '${_job['first_name'] ?? ''} ${_job['last_name'] ?? ''}'.trim();
    final photos = (_job['photos'] is List) ? List<dynamic>.from(_job['photos']) : [];

    return Scaffold(
      backgroundColor: const Color(0xffF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('tjd_page_title'), style: const TextStyle(color: Colors.white)),
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
                // ---------- รหัสงาน + สถานะ ----------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xff2196F3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.t('tjd_job_code_prefix').replaceAll('%s', '${_job['id']}'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_statusLabel(status),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.person_outline, loc.t('tjd_customer_info_header')),
                      const SizedBox(height: 10),
                      Text(customerName.isEmpty ? loc.t('profile_name_fallback') : customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_job['customer_phone']?.toString() ?? loc.t('tjd_phone_unspecified'),
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.directions_car_outlined, loc.t('tjd_car_details_header')),
                      const SizedBox(height: 10),
                      Text(loc.t('tjd_vehicle_type_prefix').replaceAll('%s', _vehicleLabel(_job['vehicle_type']?.toString()))),
                      const SizedBox(height: 4),
                      Text(loc.t('tjd_problem_type_prefix').replaceAll('%s', '${_job['problem_category'] ?? '-'}')),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.warning_amber_outlined, loc.t('tjd_problem_description_header')),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _job['description']?.toString().isNotEmpty == true
                              ? _job['description'].toString()
                              : loc.t('crd_no_description'),
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ),
                      if (photos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: photos.map((url) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: NetImage(url.toString(),
                                      width: 90, height: 90, fit: BoxFit.cover),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.location_on_outlined, loc.t('tjd_location_header')),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_job['address']?.toString() ?? loc.t('crd_no_address'),
                            style: const TextStyle(fontSize: 13, height: 1.4)),
                      ),
                      if (_customerLatLng != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GestureDetector(
                            onTap: _openFullMap,
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              height: 150,
                              child: IgnorePointer(
                                // ✅ preview เฉยๆ ปิดการลาก/ซูมในนี้ กดเพื่อไปหน้าแผนที่เต็มจอแทน
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: _customerLatLng!,
                                    initialZoom: 15,
                                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                  ),
                                  children: [
                                    TileLayer(
                                      // ✅ CartoDB Voyager — ต้องตรงกับ garage_detail_page.dart,
                                      // garage_location_page.dart และ address_map_page.dart เสมอ
                                      // ไม่งั้นแต่ละหน้าแผนที่ในแอปจะดูไม่เหมือนกัน
                                      urlTemplate:
                                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                      subdomains: const ['a', 'b', 'c', 'd'],
                                      userAgentPackageName: 'com.goodgarage.app',
                                    ),
                                    MarkerLayer(markers: [
                                      Marker(
                                        point: _customerLatLng!,
                                        width: 40,
                                        height: 40,
                                        child: const Icon(Icons.location_on, color: Color(0xffE53935), size: 40),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fullscreen, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(loc.t('tjd_map_tap_hint'),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openNavigation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff2196F3),
                            side: const BorderSide(color: Color(0xff2196F3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.navigation_outlined, size: 16),
                          label: Text(loc.t('common_navigate')),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------- เช็กลิสต์อะไหล่ (จากใบเสนอราคาจริง ถ้ามี) ----------
                if (!_isLoadingQuotation && _quotationItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardHeader(Icons.checklist_outlined, loc.t('tjd_checklist_header')),
                        const SizedBox(height: 6),
                        ..._quotationItems.map((it) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_box_outlined, size: 18, color: Color(0xff4CAF50)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        '${it['name']} (${it['quantity']}${(it['unit'] ?? '').toString().isNotEmpty ? ' ${it['unit']}' : ''})',
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                _infoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _cardHeader(Icons.history, loc.t('tjd_timeline_header')),
                      const SizedBox(height: 8),
                      if (_isLoadingLogs)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_logs.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(loc.t('tjd_no_logs'), style: const TextStyle(color: Colors.grey)),
                        )
                      else
                        ..._logs.map(_logItem),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ===== ปุ่มอัปเดตสถานะ / บันทึกความคืบหน้า ติดด้านล่างเสมอ =====
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
            ),
            child: status == 'completed'
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(14)),
                    child: Center(
                      child: Text(loc.t('tjd_completed_banner'),
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openUpdateStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.update, color: Colors.white),
                      label: Text(loc.t('ujs_page_title'),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    final loc = AppLocale.instance;
    switch (status) {
      case 'assigned':
        return loc.t('tjd_status_assigned');
      case 'checking':
        return loc.t('dash_status_checking');
      case 'in_progress':
        return loc.t('dash_status_in_progress');
      case 'waiting_parts':
        return loc.t('dash_status_waiting_parts');
      case 'completed':
        return loc.t('tech_status_completed');
      default:
        return status;
    }
  }

  Widget _logItem(Map<String, dynamic> log) {
    final loc = AppLocale.instance;
    final photos = (log['photos'] is List) ? List<dynamic>.from(log['photos']) : [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xffF5F5F5), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(log['technician_name']?.toString() ?? loc.t('track_technician_fallback'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(_formatThaiDateTime(log['created_at']?.toString()),
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          if ((log['note']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(log['note'].toString(), style: const TextStyle(fontSize: 13)),
          ],
          if ((log['parts_used']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(loc.t('tjd_parts_used_prefix').replaceAll('%s', '${log['parts_used']}'),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: photos.map((url) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: NetImage(url.toString(), width: 70, height: 70, fit: BoxFit.cover),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
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

  Widget _cardHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xff2196F3)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}
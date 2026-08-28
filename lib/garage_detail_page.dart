import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'request_repair_page.dart'; // ✅ หน้าส่งคำขอซ่อม
import 'api_service.dart';
import 'chat_screen.dart'; // ✅ แชทกับอู่
import 'garage_reviews_page.dart'; // ✅ หน้าดูรีวิวทั้งหมดของอู่
import 'network_image_helper.dart';
import 'app_locale.dart'; // ✅ ระบบสลับภาษาไทย/อังกฤษ

/// หน้ารายละเอียดอู่ซ่อมรถ (ฝั่งลูกค้า)
/// รับข้อมูลอู่มาจากหน้า Search โดยตรง (ไม่ยิง API ซ้ำ เพราะข้อมูลชุดเดียวกันอยู่แล้ว)
class GarageDetailPage extends StatefulWidget {
  final Map<String, dynamic> garage;
  final Map<String, dynamic> userData;

  const GarageDetailPage({super.key, required this.garage, required this.userData});

  @override
  State<GarageDetailPage> createState() => _GarageDetailPageState();
}

class _GarageDetailPageState extends State<GarageDetailPage> {
  bool _isFavorite = false; // ⚠️ เก็บแค่ในหน้าจอนี้ ยังไม่บันทึกลง DB (ยังไม่มีระบบ favorite)

  // ✅ คะแนนรีวิวสรุป ดึงจาก API จริงมาโชว์ในหัวการ์ด (เดิมฝังข้อความ "ยังไม่มีรีวิว" ไว้ตายตัว)
  double? _averageRating;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _fetchReviewSummary();
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

  Future<void> _fetchReviewSummary() async {
    final garageId = _garageId;
    if (garageId == null) return;
    final result = await ApiService.getReviews(garageId: garageId);
    if (!mounted) return;
    if (result.success && result.data != null) {
      setState(() {
        _averageRating = (result.data!['averageRating'] as num?)?.toDouble();
        _totalReviews = (result.data!['totalReviews'] as num?)?.toInt() ?? 0;
      });
    }
  }

  String get _shopName => widget.garage['shop_name']?.toString() ?? AppLocale.instance.t('profile_shop_fallback');
  String? get _avatar => widget.garage['avatar']?.toString();
  String get _address => widget.garage['address']?.toString() ?? AppLocale.instance.t('gd_address_fallback');
  String get _phone => widget.garage['phone']?.toString() ?? '';
  // ✅ garage_id ที่ใช้ทั่วทั้งระบบ คือ users.id ของอู่ (เท่ากับ garages.user_id) — ต้อง
  // ลองอ่าน user_id ก่อนเสมอ ไม่ใช่ id (garages.id เป็นคนละค่ากับ garages.user_id เดิม
  // โค้ดสลับลำดับผิด ทำให้ทุกอย่างที่พึ่ง _garageId — แชท, ดูรีวิว, คะแนนเฉลี่ยบนหัวการ์ด
  // — ไป query ด้วยเลขผิด (garages.id) แทนที่จะเป็น garages.user_id ที่ถูกต้อง จึงว่างเปล่า
  // ทุกครั้งแม้จะมีรีวิวจริงอยู่ในฐานข้อมูลก็ตาม)
  int? get _garageId => widget.garage['user_id'] as int? ?? widget.garage['id'] as int?;

  bool _isOpeningChat = false;

  // ✅ แชทกับอู่นี้ (หาบทสนทนาเดิม หรือสร้างใหม่ถ้ายังไม่เคยคุยกัน)
  Future<void> _openChat() async {
    final garageId = _garageId;
    if (garageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.t('gd_no_garage_chat_fail')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isOpeningChat = true);
    final result = await ApiService.getOrCreateConversation(
      customerId: widget.userData['id'],
      garageId: garageId,
    );
    if (!mounted) return;
    setState(() => _isOpeningChat = false);

    if (!result.success || result.data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : AppLocale.instance.t('gd_chat_open_failed')), backgroundColor: Colors.red),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: result.data!['conversationId'],
          myId: widget.userData['id'],
          myType: 'customer',
          otherPartyName: _shopName,
          otherPartyAvatar: _avatar,
        ),
      ),
    );
  }

  // ✅ รองรับทั้งข้อมูลเก่า {name, price} และรูปแบบใหม่ {category, name, priceMin, priceMax,
  // details, active} จากหน้าแก้ไขข้อมูลอู่ — แปลงให้เหลือแค่ name/price (ข้อความพร้อมแสดงผล)
  // เหมือนเดิม เพื่อไม่ต้องแก้ส่วนอื่นของหน้านี้ และซ่อนบริการที่อู่ปิดใช้งานไว้ (active == false)
  // ข้อมูลเก่าที่ไม่มีฟิลด์ active ให้ถือว่าเปิดใช้งานอยู่เสมอ กันบริการเดิมหายจากโปรไฟล์ทันที
  List<Map<String, dynamic>> get _services {
    final raw = widget.garage['services'];
    if (raw is! List) return [];
    return raw
        .map((e) {
          if (e is Map) {
            final active = e['active'] is bool ? e['active'] as bool : true;
            final name = e['name']?.toString() ?? '';

            final priceMin = e['priceMin']?.toString().trim() ?? '';
            final priceMax = e['priceMax']?.toString().trim() ?? '';
            String price;
            if (priceMin.isNotEmpty || priceMax.isNotEmpty) {
              if (priceMin.isNotEmpty && priceMax.isNotEmpty && priceMin != priceMax) {
                price = '$priceMin - $priceMax ${AppLocale.instance.t('gd_baht')}';
              } else {
                price = '${priceMin.isNotEmpty ? priceMin : priceMax} ${AppLocale.instance.t('gd_baht')}';
              }
            } else {
              price = e['price']?.toString() ?? ''; // ข้อมูลเก่า
            }

            return {'name': name, 'price': price, 'active': active};
          }
          return {'name': e.toString(), 'price': '', 'active': true};
        })
        .where((s) => s['active'] == true && (s['name'] as String).isNotEmpty)
        .toList();
  }

  // ===== เช็คว่าตอนนี้เปิดทำการอยู่ไหม จากเวลาทำการที่อู่ตั้งไว้ =====
  bool? get _isOpenNow {
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final hoursText = isWeekend
        ? widget.garage['hours_weekend']?.toString()
        : widget.garage['hours_weekday']?.toString();
    if (hoursText == null || !hoursText.contains('-')) return null;

    final parts = hoursText.split('-');
    final start = _parseTimeOfDay(parts[0]);
    final end = _parseTimeOfDay(parts.length > 1 ? parts[1] : '');
    if (start == null || end == null) return null;

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  TimeOfDay? _parseTimeOfDay(String text) {
    final segments = text.trim().split(':');
    if (segments.length < 2) return null;
    final h = int.tryParse(segments[0]);
    final m = int.tryParse(segments[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  double? get _distanceKm {
    final myLat = double.tryParse(widget.userData['latitude']?.toString() ?? '');
    final myLng = double.tryParse(widget.userData['longitude']?.toString() ?? '');
    final gLat = double.tryParse(widget.garage['latitude']?.toString() ?? '');
    final gLng = double.tryParse(widget.garage['longitude']?.toString() ?? '');
    if (myLat == null || myLng == null || gLat == null || gLng == null) return null;

    const r = 6371.0;
    double deg2rad(double d) => d * (math.pi / 180);
    final dLat = deg2rad(gLat - myLat);
    final dLon = deg2rad(gLng - myLng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(deg2rad(myLat)) * math.cos(deg2rad(gLat)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // ✅ พิกัดอู่ที่ปักหมุดไว้ — คืนค่า null ถ้าอู่ยังไม่ได้ตั้งพิกัด (จะได้ซ่อนแผนที่แทนโชว์แผนที่เปล่า)
  LatLng? get _garageLatLng {
    final lat = double.tryParse(widget.garage['latitude']?.toString() ?? '');
    final lng = double.tryParse(widget.garage['longitude']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _openFullMap() {
    final point = _garageLatLng;
    if (point == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _GarageMapPage(point: point, shopName: _shopName, address: _address),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    final services = _services;
    final servicesWithPrice = services.where((s) => (s['price'] ?? '').isNotEmpty).toList();
    final isOpen = _isOpenNow;

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== รูปปกอู่ + ปุ่มย้อนกลับ/ถูกใจ =====
                    Stack(
                      children: [
                        _avatar != null && _avatar!.isNotEmpty
                            ? NetImage(_avatar!, height: 240, width: double.infinity, fit: BoxFit.cover)
                            : Container(
                                height: 240,
                                width: double.infinity,
                                color: Colors.grey.shade300,
                                child: Icon(Icons.home_repair_service, size: 64, color: Colors.grey.shade500),
                              ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _circleButton(
                                  icon: Icons.arrow_back,
                                  onTap: () => Navigator.pop(context),
                                ),
                                _circleButton(
                                  icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                                  iconColor: _isFavorite ? Colors.red : Colors.black87,
                                  onTap: () => setState(() => _isFavorite = !_isFavorite),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ===== ชื่ออู่ + สถานะเปิด/ปิด + คะแนน =====
                          _infoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_shopName,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                if (isOpen != null)
                                  Row(
                                    children: [
                                      Icon(Icons.circle, size: 10, color: isOpen ? Colors.green : Colors.red),
                                      const SizedBox(width: 6),
                                      Text(isOpen ? loc.t('gd_open_now') : loc.t('gd_closed_now'),
                                          style: TextStyle(
                                              color: isOpen ? Colors.green.shade700 : Colors.red.shade700)),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: _totalReviews > 0
                                      ? [
                                          const Icon(Icons.star, color: Color(0xffFFC107), size: 20),
                                          const SizedBox(width: 4),
                                          Text(_averageRating!.toStringAsFixed(1),
                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 4),
                                          Text('(${loc.t('search_reviews_count').replaceAll('%s', '$_totalReviews')})',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                        ]
                                      : [
                                          Icon(Icons.star_border, color: Colors.grey.shade400, size: 20),
                                          const SizedBox(width: 4),
                                          Text(loc.t('gd_no_reviews_yet'), style: TextStyle(color: Colors.grey.shade500)),
                                        ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ===== ประเภทบริการ =====
                          if (services.isNotEmpty)
                            _infoCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _cardHeader(Icons.build_outlined, loc.t('gd_service_types')),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: services.map((s) {
                                      return Chip(
                                        label: Text(s['name'] ?? ''),
                                        backgroundColor: const Color(0xffE3F2FD),
                                        labelStyle: const TextStyle(color: Color(0xff2196F3)),
                                        side: BorderSide.none,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),

                          if (services.isNotEmpty) const SizedBox(height: 16),

                          // ===== ราคาโดยประมาณ =====
                          if (servicesWithPrice.isNotEmpty)
                            _infoCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _cardHeader(Icons.sell_outlined, loc.t('gd_estimated_prices')),
                                  const SizedBox(height: 12),
                                  ...servicesWithPrice.map((s) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(s['name'] ?? ''),
                                            Text(s['price'] ?? '',
                                                style: const TextStyle(
                                                    color: Color(0xff2196F3), fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),

                          if (servicesWithPrice.isNotEmpty) const SizedBox(height: 16),

                          // ===== เวลาทำการ =====
                          _infoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _cardHeader(Icons.access_time, loc.t('gd_business_hours')),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(loc.t('gd_mon_fri')),
                                    Text(widget.garage['hours_weekday']?.toString() ?? loc.t('garage_address_fallback')),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(loc.t('gd_sat_sun')),
                                    Text(widget.garage['hours_weekend']?.toString() ?? loc.t('garage_address_fallback')),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ===== ที่ตั้ง =====
                          _infoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _cardHeader(Icons.location_on_outlined, loc.t('gd_location')),
                                const SizedBox(height: 12),
                                Text(_address),
                                if (_distanceKm != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.near_me, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(loc.t('gd_distance_from_you').replaceAll('%s', _distanceKm!.toStringAsFixed(1)),
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                    ],
                                  ),
                                ],
                                if (_garageLatLng != null) ...[
                                  const SizedBox(height: 12),
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
                                              initialCenter: _garageLatLng!,
                                              initialZoom: 15,
                                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                            ),
                                            children: [
                                              TileLayer(
                                                // ✅ CartoDB Voyager — ต้องตรงกับ garage_location_page.dart
                                                // และ address_map_page.dart เสมอ ไม่งั้นแต่ละหน้าแผนที่ในแอป
                                                // จะดูไม่เหมือนกัน (สลับไปมาแล้วรู้สึกแปลกๆ)
                                                urlTemplate:
                                                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                                subdomains: const ['a', 'b', 'c', 'd'],
                                                userAgentPackageName: 'com.goodgarage.app',
                                              ),
                                              MarkerLayer(markers: [
                                                Marker(
                                                  point: _garageLatLng!,
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
                                      Text(loc.t('gd_tap_fullscreen_map'),
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ===== ปุ่มด้านล่าง =====
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isOpeningChat ? null : _openChat,
                          icon: _isOpeningChat
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.chat_bubble_outline, size: 18),
                          label: Text(loc.t('nav_chat')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff2196F3),
                            side: const BorderSide(color: Color(0xff2196F3)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _garageId == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => GarageReviewsPage(
                                        garageId: _garageId!,
                                        shopName: _shopName,
                                      ),
                                    ),
                                  ),
                          icon: const Icon(Icons.star_border, size: 18),
                          label: Text(loc.t('gd_view_reviews')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade400),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RequestRepairPage(
                              garage: widget.garage,
                              userData: widget.userData,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.build, color: Colors.white, size: 18),
                      label: Text(loc.t('gd_send_repair_request'), style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap, Color iconColor = Colors.black87}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Widget _infoCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xff2196F3)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

// ============================================================
// หน้าแผนที่เต็มจอ — แตะจาก preview ในหน้ารายละเอียดอู่ ปักหมุดตำแหน่งอู่
// (ใช้ flutter_map + OpenStreetMap ตัวเดียวกับที่ระบบนี้ใช้ทำ routing/แชร์
// ตำแหน่งอยู่แล้ว ไม่ได้เพิ่ม map package ใหม่)
// ============================================================
class _GarageMapPage extends StatelessWidget {
  final LatLng point;
  final String shopName;
  final String? address;

  const _GarageMapPage({required this.point, required this.shopName, this.address});

  // ✅ เปิดแอปแผนที่จริงของเครื่อง (Google Maps/Apple Maps) พาไปยังจุดที่ปักหมุดไว้ตรงๆ
  Future<void> _openInMapsApp(BuildContext context) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.t('gd_open_maps_failed')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(shopName, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: point, initialZoom: 16),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.goodgarage.app',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: point,
                  width: 46,
                  height: 46,
                  child: const Icon(Icons.location_on, color: Color(0xffE53935), size: 46),
                ),
              ]),
              // ✅ เครดิตตามข้อกำหนดการใช้งานฟรีของ CARTO + OpenStreetMap (มีจุดเดียวพอ —
              // รอบก่อนใส่ซ้ำ 2 อันโดยไม่ตั้งใจ ทำให้ข้อความ attribution ซ้อนกันมุมล่างขวา)
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                  TextSourceAttribution('© CARTO'),
                ],
              ),
            ],
          ),

          // ✅ การ์ดชื่อร้าน+ที่อยู่ ลอยด้านล่าง ให้เห็นชัดว่าหมุดที่ปักคือที่ไหน
          // พร้อมปุ่มนำทางออกไปแอปแผนที่จริงของเครื่อง
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xffE53935), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(shopName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if ((address ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(address!, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4)),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openInMapsApp(context),
                      icon: const Icon(Icons.directions, color: Colors.white, size: 18),
                      label: Text(AppLocale.instance.t('gd_navigate_here'), style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff2196F3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
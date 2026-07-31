import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'request_repair_page.dart'; // ✅ หน้าส่งคำขอซ่อม
import 'api_service.dart';
import 'chat_screen.dart'; // ✅ แชทกับอู่

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

  String get _shopName => widget.garage['shop_name']?.toString() ?? 'ไม่ระบุชื่อร้าน';
  String? get _avatar => widget.garage['avatar']?.toString();
  String get _address => widget.garage['address']?.toString() ?? 'ไม่ระบุที่อยู่';
  String get _phone => widget.garage['phone']?.toString() ?? '';
  // ✅ garage_id ที่ใช้ทั่วทั้งระบบ คือ users.id ของอู่ (เท่ากับ garages.user_id)
  int? get _garageId => widget.garage['id'] as int? ?? widget.garage['user_id'] as int?;

  bool _isOpeningChat = false;

  // ✅ แชทกับอู่นี้ (หาบทสนทนาเดิม หรือสร้างใหม่ถ้ายังไม่เคยคุยกัน)
  Future<void> _openChat() async {
    final garageId = _garageId;
    if (garageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลอู่ ไม่สามารถเปิดแชทได้'), backgroundColor: Colors.red),
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
        SnackBar(content: Text(result.message.isNotEmpty ? result.message : 'เปิดแชทไม่สำเร็จ'), backgroundColor: Colors.red),
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

  List<Map<String, dynamic>> get _services {
    final raw = widget.garage['services'];
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) return {'name': e['name']?.toString() ?? '', 'price': e['price']?.toString() ?? ''};
      return {'name': e.toString(), 'price': ''};
    }).toList();
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

  @override
  Widget build(BuildContext context) {
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
                            ? Image.network(_avatar!, height: 240, width: double.infinity, fit: BoxFit.cover)
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
                                      Text(isOpen ? 'เปิดทำการ' : 'ปิดทำการ',
                                          style: TextStyle(
                                              color: isOpen ? Colors.green.shade700 : Colors.red.shade700)),
                                    ],
                                  ),
                                const SizedBox(height: 8),
                                // ⚠️ ยังไม่มีระบบรีวิว/คะแนนจริงในฐานข้อมูล แสดงสถานะที่ตรงความจริงไว้ก่อน
                                Row(
                                  children: [
                                    Icon(Icons.star_border, color: Colors.grey.shade400, size: 20),
                                    const SizedBox(width: 4),
                                    Text('ยังไม่มีรีวิว', style: TextStyle(color: Colors.grey.shade500)),
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
                                  _cardHeader(Icons.build_outlined, 'ประเภทบริการ'),
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
                                  _cardHeader(Icons.sell_outlined, 'ราคาโดยประมาณ'),
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
                                _cardHeader(Icons.access_time, 'เวลาทำการ'),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('จันทร์ - ศุกร์'),
                                    Text(widget.garage['hours_weekday']?.toString() ?? 'ไม่ระบุ'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('เสาร์ - อาทิตย์'),
                                    Text(widget.garage['hours_weekend']?.toString() ?? 'ไม่ระบุ'),
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
                                _cardHeader(Icons.location_on_outlined, 'ที่ตั้ง'),
                                const SizedBox(height: 12),
                                Text(_address),
                                if (_distanceKm != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.near_me, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text('ห่างจากคุณ ${_distanceKm!.toStringAsFixed(1)} กม.',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
                          label: const Text('แชท'),
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
                          onPressed: () {
                            // TODO: ต่อกับหน้ารีวิวจริงเมื่อมีระบบรีวิว (ตอนนี้ยังไม่มีตาราง reviews)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ระบบรีวิวยังไม่เปิดใช้งาน')),
                            );
                          },
                          icon: const Icon(Icons.star_border, size: 18),
                          label: const Text('ดูรีวิว'),
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
                      label: const Text('ส่งคำขอซ่อม', style: TextStyle(color: Colors.white)),
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
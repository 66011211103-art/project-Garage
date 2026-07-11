import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ผลลัพธ์ที่อยู่ + พิกัด ที่ได้จากการค้นหา
class PickedAddress {
  final String address;
  final double latitude;
  final double longitude;

  const PickedAddress({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

/// ค้นหาที่อยู่ -> พิกัด ด้วย Nominatim (OpenStreetMap) ฟรี ไม่ต้องใช้ API key
/// หมายเหตุ: Nominatim ขอให้ใส่ User-Agent ที่ระบุแอป และไม่ยิงถี่เกิน ~1 ครั้ง/วินาที
Future<List<PickedAddress>> searchAddressOSM(String query) async {
  if (query.trim().isEmpty) return [];

  final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
    queryParameters: {
      'q': query.trim(),
      'format': 'json',
      'addressdetails': '1',
      'limit': '5',
      'countrycodes': 'th', // จำกัดผลลัพธ์ในไทย ลบบรรทัดนี้ได้ถ้าต้องการค้นหาทั่วโลก
    },
  );

  try {
    final response = await http.get(
      uri,
      headers: {
        // Nominatim usage policy กำหนดให้ใส่ User-Agent ที่ระบุตัวแอป/ผู้ติดต่อ
        'User-Agent': 'flutter_goodgarage_app (student project)',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return [];

    final List<dynamic> results = jsonDecode(response.body);
    return results.map((item) {
      return PickedAddress(
        address: item['display_name'] ?? query,
        latitude: double.tryParse(item['lat'].toString()) ?? 0,
        longitude: double.tryParse(item['lon'].toString()) ?? 0,
      );
    }).toList();
  } catch (e) {
    return [];
  }
}

/// เปิด bottom sheet สไตล์ "แชท" ให้พิมพ์ที่อยู่แล้วค้นหาพิกัด
/// พิมพ์ในช่องด้านล่าง กดปุ่มส่ง (เหมือนแชท) ผลลัพธ์ขึ้นเป็นรายการให้เลือกด้านบน
/// คืนค่า PickedAddress ที่เลือก หรือ null ถ้าปิดโดยไม่ได้เลือก
Future<PickedAddress?> pickAddressViaChat(
  BuildContext context, {
  String? initialQuery,
}) {
  return showModalBottomSheet<PickedAddress>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AddressChatSheet(initialQuery: initialQuery),
  );
}

class _AddressChatSheet extends StatefulWidget {
  final String? initialQuery;
  const _AddressChatSheet({this.initialQuery});

  @override
  State<_AddressChatSheet> createState() => _AddressChatSheetState();
}

class _AddressChatSheetState extends State<_AddressChatSheet> {
  late final TextEditingController _controller;
  List<PickedAddress> _results = [];
  bool _isSearching = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorText = null;
    });

    final results = await searchAddressOSM(query);

    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _results = results;
      if (results.isEmpty) {
        _errorText = 'ไม่พบที่อยู่นี้ ลองพิมพ์ให้ละเอียดขึ้น เช่น เลขที่ ถนน ตำบล อำเภอ จังหวัด';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined, color: Color(0xff2196F3)),
                const SizedBox(width: 8),
                const Text('ค้นหาที่อยู่',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'พิมพ์ที่อยู่แล้วกดส่ง ระบบจะค้นหาพิกัดให้ (ข้อมูลจาก OpenStreetMap)',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),

            // ===== พื้นที่แสดงผลลัพธ์ (เหมือนข้อความในแชท) =====
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _errorText ?? 'พิมพ์ที่อยู่ที่ต้องการค้นหาด้านล่าง',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final r = _results[index];
                            return InkWell(
                              onTap: () => Navigator.pop(context, r),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xffF0F6FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Color(0xff2196F3), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(r.address,
                                          style: const TextStyle(fontSize: 14)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            const SizedBox(height: 12),

            // ===== ช่องพิมพ์สไตล์แชท ปุ่มส่งอยู่ด้านขวา =====
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _handleSend(),
                    decoration: InputDecoration(
                      hintText: 'พิมพ์ที่อยู่ เช่น 123 ถ.สุขุมวิท กรุงเทพฯ',
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xff2196F3),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _isSearching ? null : _handleSend,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

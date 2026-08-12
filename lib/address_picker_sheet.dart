import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'location_service.dart'; // ✅ ใช้ getCurrentPosition + reverseGeocodeOSM ร่วมกับหน้าอื่น

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

// ✅ ใช้ภายในเพื่อเก็บข้อมูลดิบจาก Nominatim ไว้คำนวณคะแนนความแม่นยำ
// ก่อนจะแปลงเป็น PickedAddress ที่ส่งออกไปให้หน้าอื่นใช้
class _AddressCandidate {
  final String displayName;
  final double lat;
  final double lon;
  final String osmClass; // เช่น 'building', 'highway', 'boundary', 'office'
  final String osmType; // เช่น 'house', 'residential', 'administrative'
  final bool hasHouseNumber;
  final bool hasRoad;

  _AddressCandidate({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.osmClass,
    required this.osmType,
    required this.hasHouseNumber,
    required this.hasRoad,
  });

  factory _AddressCandidate.fromJson(Map<String, dynamic> item) {
    final address = item['address'] as Map<String, dynamic>? ?? {};
    return _AddressCandidate(
      displayName: item['display_name']?.toString() ?? '',
      lat: double.tryParse(item['lat'].toString()) ?? 0,
      lon: double.tryParse(item['lon'].toString()) ?? 0,
      osmClass: item['class']?.toString() ?? '',
      osmType: item['type']?.toString() ?? '',
      hasHouseNumber: address.containsKey('house_number'),
      hasRoad: address.containsKey('road'),
    );
  }

  // ✅ ตัดจุดที่เป็น "หน่วยงานราชการ/เขตการปกครอง" ล้วนๆ ออก
  // (เทศบาล, ที่ว่าการอำเภอ, ขอบเขตจังหวัด/อำเภอ/ตำบล) เพราะไม่ใช่สิ่งที่ผู้ใช้
  // ต้องการเวลาค้นหาที่อยู่จริงของบ้าน/อู่ซ่อมรถ
  bool get isAdministrativeOnly {
    if (osmClass == 'boundary') return true;
    if (osmClass == 'place' &&
        [
          'city',
          'town',
          'village',
          'county',
          'state',
          'country',
          'suburb',
          'district',
        ].contains(osmType)) {
      return true;
    }
    if (osmClass == 'office' && osmType == 'government') return true;
    if (osmClass == 'amenity' && ['townhall', 'courthouse'].contains(osmType)) {
      return true;
    }
    return false;
  }

  // ✅ คะแนนความ "จำเพาะเจาะจง" ยิ่งมีเลขที่บ้าน/ชื่อถนน ยิ่งคะแนนสูง
  // ใช้จัดลำดับผลลัพธ์ให้ที่อยู่จริงขึ้นก่อนจุดกว้างๆ อย่างเขต/อำเภอ
  int get specificityScore {
    var score = 0;
    if (hasHouseNumber) score += 100;
    if (hasRoad) score += 50;
    if (osmClass == 'building') score += 30;
    return score;
  }
}

// ✅ คำค้นหาแต่ละแบบที่จะลองไล่ตามลำดับ พร้อมระบุว่า "แม่นยำ" หรือ "โดยประมาณ"
// เพื่อเอาไปติดป้ายเตือนผู้ใช้เมื่อผลลัพธ์มาจากการค้นหาแบบกว้าง (ไม่ใช่ที่อยู่ตรงเป๊ะ)
class _SearchAttempt {
  final String query;
  final bool approx;
  const _SearchAttempt(this.query, {this.approx = false});
}

/// ค้นหาที่อยู่ -> พิกัด ด้วย Nominatim (OpenStreetMap) ฟรี ไม่ต้องใช้ API key
/// ✅ ถ้าข้อความที่พิมพ์/วางมาเป็น "พิกัดดิบ" (ละติจูด,ลองจิจูด) เช่นที่ก็อปมาจาก URL
/// ของ Google Maps โดยตรง จะปักหมุดตรงจุดนั้นทันทีแม่นยำ 100% โดยไม่ผ่านการค้นหาข้อความเลย
/// (สำคัญมากสำหรับกรณีค้นหาชื่อร้าน/สถานที่ที่ Nominatim ไม่มีฐานข้อมูลธุรกิจแบบ Google)
/// ถ้าไม่ใช่พิกัดดิบ จะค้นหาด้วยข้อความตามปกติ และถ้าเต็มไม่เจอ จะลองแบบที่กว้างขึ้น
/// ให้อัตโนมัติ (ดู [_buildSearchAttempts]) ก่อนจะสรุปว่าไม่พบจริงๆ
Future<List<PickedAddress>> searchAddressOSM(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return [];

  final rawCoords = _tryParseRawCoordinates(trimmed);
  if (rawCoords != null) {
    final label = await reverseGeocodeOSM(rawCoords.$1, rawCoords.$2);
    return [
      PickedAddress(
        address:
            label ??
            'พิกัด ${rawCoords.$1.toStringAsFixed(6)}, ${rawCoords.$2.toStringAsFixed(6)}',
        latitude: rawCoords.$1,
        longitude: rawCoords.$2,
      ),
    ];
  }

  for (final attempt in _buildSearchAttempts(trimmed)) {
    final results = await _searchOnce(attempt.query);
    if (results.isEmpty) continue;

    if (!attempt.approx) return results;

    // ✅ ผลลัพธ์นี้มาจากการค้นหาแบบกว้าง (ตัดเลขที่บ้าน/ตัดชื่อร้านออกไปแล้ว)
    // ติดป้ายเตือนไว้ในชื่อที่อยู่ให้ผู้ใช้เห็นชัดเจนว่าอาจไม่ตรงเป๊ะ
    return results
        .map(
          (r) => PickedAddress(
            address: '${r.address} — (ตำแหน่งโดยประมาณ)',
            latitude: r.latitude,
            longitude: r.longitude,
          ),
        )
        .toList();
  }
  return [];
}

/// ✅ เช็คว่าข้อความที่พิมพ์/วางมาเป็นรูปแบบ "ละติจูด,ลองจิจูด" ดิบๆ หรือไม่
/// เช่น "16.2465287,103.2520751" หรือ "16.2465287, 103.2520751" ที่ก็อปมาจาก
/// แถบที่อยู่ของ Google Maps ตรงๆ — ถ้าใช่ คืนค่าพิกัด ถ้าไม่ใช่คืนค่า null
(double, double)? _tryParseRawCoordinates(String text) {
  final match = RegExp(
    r'^\s*(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)\s*$',
  ).firstMatch(text);
  if (match == null) return null;

  final lat = double.tryParse(match.group(1)!);
  final lon = double.tryParse(match.group(2)!);
  if (lat == null || lon == null) return null;
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;

  return (lat, lon);
}

/// ✅ สร้างรายการคำค้นหาไล่จากแคบไปกว้าง เพื่อเพิ่มโอกาสเจอที่อยู่จริง
/// 1. ข้อความเต็มตามที่พิมพ์มา
/// 2. ตัดคำนำหน้าเขตการปกครองไทย (ตำบล/อำเภอ/จังหวัด) ออก เพราะ Nominatim
///    มักรู้จักแค่ชื่อเฉยๆ โดยไม่มีคำนำหน้าเหล่านี้
/// 3. ตัดคำว่า "หมู่ที่ N" / "หมู่ N" ออกเพิ่ม เพราะรูปแบบที่อยู่ชนบทไทยแบบนี้
///    Nominatim ไม่รู้จัก ทำให้สับสนจนหาไม่เจอหรือจับคู่ผิดที่
/// 4. ตัดชื่อร้าน/คำนำหน้าที่ไม่ใช่ตัวเลขออก โดยเริ่มค้นหาจากเลขที่บ้านตัวแรกที่เจอ
///    (ชื่อร้าน เช่น "อู่รุ่งเรืองเซอร์วิส" มักไม่ถูกบันทึกใน OSM ทำให้ Nominatim
///    จับคู่กับสถานที่อื่นที่ไม่เกี่ยวข้องแทน — เป็นสาเหตุหลักที่ปักหมุดผิดที่)
/// 5-6. (โดยประมาณ) ตัดคำแรกออก แล้วถ้ายังไม่เจอ ลองแค่ 3 คำท้าย (ตำบล/อำเภอ/จังหวัด)
///    เพื่อได้อย่างน้อยตำแหน่งโดยประมาณของพื้นที่ พร้อมติดป้ายเตือนชัดเจน
List<_SearchAttempt> _buildSearchAttempts(String query) {
  final attempts = <_SearchAttempt>[_SearchAttempt(query)];
  final seen = <String>{query};

  void add(String q, {bool approx = false}) {
    final t = q.trim();
    if (t.isEmpty || seen.contains(t)) return;
    seen.add(t);
    attempts.add(_SearchAttempt(t, approx: approx));
  }

  final stripped = query
      .replaceAll(RegExp(r'(ตำบล|ต\.|อำเภอ|อ\.|จังหวัด|จ\.)\s*'), '')
      .trim();
  add(stripped);

  final noMoo = (stripped.isNotEmpty ? stripped : query)
      .replaceAll(RegExp(r'(หมู่ที่|หมู่)\s*\d+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  add(noMoo);

  final base = noMoo.isNotEmpty
      ? noMoo
      : (stripped.isNotEmpty ? stripped : query);

  // ✅ ตัดชื่อร้าน/คำนำหน้าออก เริ่มค้นหาจากเลขที่บ้านตัวแรกที่เจอในข้อความ
  final digitMatch = RegExp(r'\d').firstMatch(base);
  if (digitMatch != null && digitMatch.start > 0) {
    add(base.substring(digitMatch.start));
  }

  final tokens = base.split(RegExp(r'\s+'));
  if (tokens.length > 1) {
    add(tokens.sublist(1).join(' '), approx: true);
  }
  if (tokens.length > 3) {
    add(tokens.sublist(tokens.length - 3).join(' '), approx: true);
  }

  return attempts;
}

Future<List<PickedAddress>> _searchOnce(String query) async {
  final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
    queryParameters: {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': '10', // ✅ ดึงมาเยอะขึ้นเผื่อต้องกรองจุดเขตการปกครองออก
      'countrycodes':
          'th', // จำกัดผลลัพธ์ในไทย ลบบรรทัดนี้ได้ถ้าต้องการค้นหาทั่วโลก
    },
  );

  try {
    final response = await http
        .get(
          uri,
          headers: {
            // Nominatim usage policy กำหนดให้ใส่ User-Agent ที่ระบุตัวแอป/ผู้ติดต่อ
            'User-Agent': 'flutter_goodgarage_app (student project)',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return [];

    final List<dynamic> raw = jsonDecode(response.body);
    if (raw.isEmpty) return [];

    final candidates = raw
        .map((item) => _AddressCandidate.fromJson(item as Map<String, dynamic>))
        .toList();

    // ✅ ตัดจุดที่เป็นแค่เขตการปกครองออกก่อน ถ้าตัดแล้วไม่เหลือเลยค่อยใช้ของเดิมทั้งหมด
    // (กันกรณีค้นหาชื่ออำเภอ/จังหวัดตรงๆ ที่ไม่มีผลลัพธ์อื่นให้เลือก)
    final specific = candidates.where((c) => !c.isAdministrativeOnly).toList();
    final pool = specific.isNotEmpty ? specific : candidates;

    // ✅ เรียงตามคะแนนความจำเพาะเจาะจง (มีเลขที่บ้าน/ถนน ขึ้นก่อน)
    pool.sort((a, b) => b.specificityScore.compareTo(a.specificityScore));

    return pool
        .take(5)
        .map(
          (c) => PickedAddress(
            address: c.displayName,
            latitude: c.lat,
            longitude: c.lon,
          ),
        )
        .toList();
  } catch (e) {
    return [];
  }
}

/// เปิด bottom sheet สไตล์ "แชท" ให้พิมพ์หรือวาง(paste)ที่อยู่แล้วค้นหาพิกัด
/// หรือกดปุ่มใช้ตำแหน่งปัจจุบันเพื่อปักหมุดอัตโนมัติแบบแม่นยำ
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
  bool _isLocating = false; // ✅ กำลังขอตำแหน่งปัจจุบันอยู่
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
        _errorText =
            'ไม่พบที่อยู่นี้ในฐานข้อมูลแผนที่ฟรี (OpenStreetMap) — ที่อยู่แบบ'
            ' "บ้านเลขที่ + หมู่ที่" ในพื้นที่ชนบทมักไม่มีข้อมูลระดับบ้านในฐานข้อมูลนี้'
            ' วิธีที่แม่นยำที่สุดคือปิดหน้าต่างนี้แล้วแตะค้างบนแผนที่ตรงตำแหน่งจริงเพื่อปักหมุดเอง';
      }
    });
  }

  // ✅ ขอตำแหน่งปัจจุบันจาก GPS/browser แล้วปิด sheet พร้อมส่งพิกัดกลับทันที
  Future<void> _handleUseCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _errorText = null;
    });

    try {
      final position = await getCurrentPosition();
      final address = await reverseGeocodeOSM(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        PickedAddress(
          address:
              address ??
              'พิกัด ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place_outlined, color: Color(0xff2196F3)),
                const SizedBox(width: 8),
                const Text(
                  'ค้นหาที่อยู่',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ===== ปุ่มใช้ตำแหน่งปัจจุบัน =====
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLocating ? null : _handleUseCurrentLocation,
                icon: _isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(
                  _isLocating
                      ? 'กำลังค้นหาตำแหน่งของคุณ...'
                      : 'ใช้ตำแหน่งปัจจุบันของฉัน',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff2196F3),
                  side: const BorderSide(color: Color(0xff2196F3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'หรือพิมพ์/วางที่อยู่เอง',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 8),

            // ===== พื้นที่แสดงผลลัพธ์ (เหมือนข้อความในแชท) =====
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? Center(
                      child: Text(
                        _errorText ??
                            'พิมพ์หรือวางที่อยู่ที่ต้องการค้นหาด้านล่าง',
                        style: TextStyle(
                          color: _errorText != null ? Colors.red : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = _results[index];
                        final isApprox = r.address.contains(
                          '(ตำแหน่งโดยประมาณ)',
                        );
                        return InkWell(
                          onTap: () => Navigator.pop(context, r),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isApprox
                                  ? const Color(0xffFFF7E6)
                                  : const Color(0xffF0F6FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isApprox
                                      ? Icons.help_outline
                                      : Icons.location_on,
                                  color: isApprox
                                      ? Colors.orange
                                      : const Color(0xff2196F3),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r.address,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // ===== ช่องพิมพ์/วาง สไตล์แชท ปุ่มส่งอยู่ด้านขวา =====
            // หมายเหตุ: TextField รองรับการวาง (Ctrl+V หรือกดค้างแล้วเลือก "วาง")
            // ได้เองอยู่แล้วโดยไม่ต้องเขียนโค้ดเพิ่ม ดังนั้นก็อปที่อยู่จากที่อื่น
            // มาวางในช่องนี้แล้วกดส่งได้เลย ระบบจะค้นหาพิกัดและเด้งไปที่ตำแหน่งนั้นให้
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _handleSend(),
                    decoration: InputDecoration(
                      hintText:
                          'เช่น 123 ถ.สุขุมวิท กรุงเทพฯ หรือวางพิกัด 16.24,103.25',
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'garage_detail_page.dart'; // ✅ หน้ารายละเอียดอู่

/// หมวดบริการที่ใช้กรอง ตรงกับที่อู่เลือกไว้ในหน้าแก้ไขข้อมูลอู่
const List<String> kSearchServiceFilters = [
  'ทั้งหมด',
  'เครื่องยนต์',
  'ยาง',
  'แบตเตอรี่',
  'ซ่อมสี',
  'เบรก',
  'ช่วงล่าง',
  'ตัวถัง',
  'ระบบไฟ',
];

/// ตัวเลือกกรองระยะทาง (กม.) — null หมายถึง "ทั้งหมด"
const List<int?> kSearchDistanceFilters = [null, 5, 10, 20];

/// ตัวเลือกกรองคะแนนรีวิว — null หมายถึง "ทั้งหมด"
/// หมายเหตุ: ยังไม่มีระบบรีวิว/คะแนนในฐานข้อมูลจริง ตัวกรองนี้จึงเป็น UI เตรียมไว้ก่อน
/// ยังไม่ส่งผลต่อผลการค้นหาจนกว่าจะมีตารางรีวิวจริง
const List<double?> kSearchRatingFilters = [null, 4.0, 4.5];

class SearchPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? initialService;

  const SearchPage({super.key, required this.userData, this.initialService});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();

  String _selectedService = 'ทั้งหมด';
  int? _selectedDistance;
  double? _selectedRating;

  bool _isLoading = true;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialService != null &&
        kSearchServiceFilters.contains(widget.initialService)) {
      _selectedService = widget.initialService!;
    }
    _fetchGarages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchGarages() async {
    setState(() => _isLoading = true);

    final result = await ApiService.searchGarages(
      service: _selectedService == 'ทั้งหมด' ? null : _selectedService,
      keyword: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _results = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['garages'] ?? [])
          : [];
    });
  }

  // ===== คำนวณระยะทางจากตำแหน่งลูกค้า -> อู่ ด้วยสูตร Haversine =====
  double? _distanceKmTo(Map<String, dynamic> garage) {
    final myLat = double.tryParse(widget.userData['latitude']?.toString() ?? '');
    final myLng = double.tryParse(widget.userData['longitude']?.toString() ?? '');
    final gLat = double.tryParse(garage['latitude']?.toString() ?? '');
    final gLng = double.tryParse(garage['longitude']?.toString() ?? '');
    if (myLat == null || myLng == null || gLat == null || gLng == null) return null;
    return _haversineKm(myLat, myLng, gLat, gLng);
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  List<Map<String, dynamic>> get _filteredResults {
    if (_selectedDistance == null) return _results;
    return _results.where((g) {
      final d = _distanceKmTo(g);
      return d != null && d <= _selectedDistance!;
    }).toList();
  }

  void _onServiceTap(String service) {
    setState(() => _selectedService = service);
    _fetchGarages();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filteredResults;

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('ค้นหาอู่ซ่อมรถ', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _fetchGarages(),
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่ออู่ซ่อมรถ',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGarages,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('กรองผลการค้นหา',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            const Text('ประเภทการซ่อม', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: kSearchServiceFilters.map((service) {
                  final selected = _selectedService == service;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(service),
                      selected: selected,
                      onSelected: (_) => _onServiceTap(service),
                      selectedColor: const Color(0xffE3F2FD),
                      labelStyle: TextStyle(
                        color: selected ? const Color(0xff2196F3) : Colors.black87,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: selected ? const Color(0xff2196F3) : Colors.grey.shade300,
                      ),
                      backgroundColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),
            const Text('ระยะทาง', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: kSearchDistanceFilters.map((distance) {
                final selected = _selectedDistance == distance;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(distance == null ? 'ทั้งหมด' : '$distance กม.'),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedDistance = distance),
                    selectedColor: const Color(0xffE3F2FD),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xff2196F3) : Colors.black87,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: selected ? const Color(0xff2196F3) : Colors.grey.shade300,
                    ),
                    backgroundColor: Colors.white,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                const Text('คะแนนรีวิว', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 6),
                Text('(ยังไม่เปิดใช้งาน)',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: kSearchRatingFilters.map((rating) {
                final selected = _selectedRating == rating;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(rating == null ? 'ทั้งหมด' : '$rating+'),
                    selected: selected,
                    // ปิดใช้งานจริงไว้ก่อนเพราะยังไม่มีข้อมูลรีวิวในระบบ
                    onSelected: null,
                    selectedColor: const Color(0xffE3F2FD),
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    side: BorderSide(color: Colors.grey.shade200),
                    backgroundColor: Colors.grey.shade100,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text('พบ ${results.length} อู่ซ่อมรถ',
                  style: const TextStyle(fontSize: 15, color: Colors.grey)),
              const SizedBox(height: 12),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('ไม่พบอู่ซ่อมรถที่ตรงกับเงื่อนไข',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else
                ...results.map((garage) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _SearchGarageCard(
                        garage: garage,
                        userData: widget.userData,
                        distanceKm: _distanceKmTo(garage),
                      ),
                    )),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchGarageCard extends StatelessWidget {
  final Map<String, dynamic> garage;
  final Map<String, dynamic> userData;
  final double? distanceKm;

  const _SearchGarageCard({
    required this.garage,
    required this.userData,
    required this.distanceKm,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = garage['avatar']?.toString();
    final name = garage['shop_name']?.toString() ?? 'ไม่ระบุชื่อร้าน';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: avatar != null && avatar.isNotEmpty
                  ? Image.network(avatar, height: 160, width: double.infinity, fit: BoxFit.cover)
                  : Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: Icon(Icons.home_repair_service,
                          size: 48, color: Colors.grey.shade400),
                    ),
            ),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} กม.' : 'ไม่ทราบระยะทาง',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GarageDetailPage(garage: garage, userData: userData),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ดูรายละเอียด', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
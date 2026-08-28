import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_locale.dart'; // ✅ ระบบสลับภาษาไทย/อังกฤษ
import 'location_service.dart'; // ✅ ดึงตำแหน่งปัจจุบัน + หาเส้นทางถนนจริงผ่าน OSRM

/// หน้าจอแสดงตำแหน่งที่อยู่บนแผนที่ (ใช้ OpenStreetMap ผ่าน flutter_map — ฟรี ไม่ต้องใช้ Google API)
/// ใช้ร่วมกันได้ทั้งที่อยู่ลูกค้าและที่อยู่อู่ซ่อม แค่เปลี่ยน title/subtitle ที่ส่งเข้ามา
///
/// วิธีใช้งาน:
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => AddressMapPage(
///       title: 'อู่ซ่อมรถบ้านสวน',
///       subtitle: '123 ถนนสุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพมหานคร 10110',
///       latitude: 16.1845,
///       longitude: 103.3020,
///     ),
///   ),
/// );
class AddressMapPage extends StatefulWidget {
  final String title;
  final String? subtitle;
  final double latitude;
  final double longitude;

  const AddressMapPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<AddressMapPage> createState() => _AddressMapPageState();
}

class _AddressMapPageState extends State<AddressMapPage> {
  final MapController _mapController = MapController();

  late final LatLng _position = LatLng(widget.latitude, widget.longitude);

  // ✅ ตำแหน่งปัจจุบันของผู้ใช้ + เส้นทางถนนจริงไปยังหมุดปลายทาง (โหลดหลังเปิดหน้านี้)
  LatLng? _currentPosition;
  List<LatLng>? _routePoints;

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
    _loadRoute();
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  // ✅ ขอตำแหน่งปัจจุบัน แล้วหาเส้นทางถนนจริงไปยังหมุดปลายทางผ่าน OSRM (ฟรี ไม่ต้องใช้ API key)
  //     ถ้าขอตำแหน่งไม่สำเร็จ (ปิด GPS/ไม่ให้สิทธิ์) จะแสดงแค่หมุดปลายทางเหมือนเดิม ไม่ error ให้ผู้ใช้เห็น
  Future<void> _loadRoute() async {
    try {
      final pos = await getCurrentPosition();
      final current = LatLng(pos.latitude, pos.longitude);
      final route = await fetchRoute(current, _position);
      if (!mounted) return;
      setState(() {
        _currentPosition = current;
        _routePoints = route;
      });

      if (route != null && route.isNotEmpty) {
        // ✅ ปรับมุมมองแผนที่ให้เห็นทั้งจุดเริ่มต้นและปลายทางพอดี
        final bounds = LatLngBounds.fromPoints([...route, current, _position]);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.fromLTRB(40, 100, 40, 220)),
        );
      }
    } catch (e) {
      // เงียบไว้ — แค่ไม่มีเส้นทางโชว์ ผู้ใช้ยังกดปุ่ม "นำทาง" เปิดแอปแผนที่จริงได้ตามปกติ
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ===== แผนที่หลัก =====
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _position,
              initialZoom: 16,
            ),
            children: [
              // ✅ CartoDB Voyager — ต้องตรงกับ garage_detail_page.dart และ garage_location_page.dart เสมอ
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.goodgarage.app',
              ),
              // ✅ เส้นทางถนนจริงจากตำแหน่งปัจจุบันไปยังหมุดปลายทาง (ถ้าหาเส้นทางได้)
              if (_routePoints != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints!,
                      strokeWidth: 5,
                      color: const Color(0xff2196F3),
                    ),
                  ],
                ),
              // เลเยอร์หมุดปักตำแหน่ง
              MarkerLayer(
                markers: [
                  // ✅ จุดตำแหน่งปัจจุบันของผู้ใช้ (ถ้าขอตำแหน่งสำเร็จ)
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xff2196F3),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                        ),
                      ),
                    ),
                  Marker(
                    point: _position,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ],
              ),
              // ✅ เครดิตตามข้อกำหนดการใช้งานฟรีของ CARTO + OpenStreetMap
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                  TextSourceAttribution('© CARTO'),
                ],
              ),
            ],
          ),

          // ===== การ์ดข้อมูลด้านล่าง =====
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Color(0xff2196F3), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // ✅ เปิดแอปแผนที่ "เริ่มต้น" ของเครื่อง แทนที่จะบังคับเปิด Google Maps เสมอ
                      //     เว็บ/Chrome -> เปิดเว็บ Google Maps แท็บใหม่, iOS -> Apple Maps, Android/อื่นๆ -> geo:
                      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
                      final Uri uri;
                      if (kIsWeb) {
                        uri = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}');
                      } else if (isIOS) {
                        uri = Uri.parse(
                            'https://maps.apple.com/?daddr=${widget.latitude},${widget.longitude}&dirflg=d');
                      } else {
                        uri = Uri.parse(
                            'geo:${widget.latitude},${widget.longitude}?q=${widget.latitude},${widget.longitude}');
                      }
                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocale.instance.t('gd_open_maps_failed')), backgroundColor: Colors.red),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2196F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.directions, size: 18),
                    label: Text(AppLocale.instance.t('common_navigate')),
                  ),
                ],
              ),
            ),
          ),

          // ===== ปุ่มเลื่อนกลับมาที่หมุด =====
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                _mapController.move(_position, 16);
              },
              child: const Icon(Icons.my_location, color: Color(0xff2196F3)),
            ),
          ),
        ],
      ),
    );
  }
}
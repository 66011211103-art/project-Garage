import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_locale.dart';

/// หน้าจอแสดงตำแหน่งอู่บนแผนที่ (ใช้ OpenStreetMap ผ่าน flutter_map)
///
/// วิธีใช้งาน:
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => GarageLocationPage(
///       shopName: 'อู่ ออยคุง',
///       latitude: 16.1845,   // ตัวอย่าง: มหาสารคาม
///       longitude: 103.3020,
///     ),
///   ),
/// );
class GarageLocationPage extends StatefulWidget {
  final String shopName;
  final double latitude;
  final double longitude;

  const GarageLocationPage({
    super.key,
    required this.shopName,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<GarageLocationPage> createState() => _GarageLocationPageState();
}

class _GarageLocationPageState extends State<GarageLocationPage> {
  final MapController _mapController = MapController();

  late final LatLng _garagePosition = LatLng(
    widget.latitude,
    widget.longitude,
  );

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(
          widget.shopName,
          style: const TextStyle(color: Colors.white),
        ),
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
              initialCenter: _garagePosition,
              initialZoom: 16,
            ),
            children: [
              // ✅ CartoDB Voyager — ต้องตรงกับ garage_detail_page.dart และ address_map_page.dart เสมอ
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.goodgarage.app',
              ),
              // เลเยอร์หมุดปักตำแหน่งอู่
              MarkerLayer(
                markers: [
                  Marker(
                    point: _garagePosition,
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
                  const Icon(Icons.home_repair_service,
                      color: Color(0xff2196F3), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.shopName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.latitude.toStringAsFixed(5)}, '
                          '${widget.longitude.toStringAsFixed(5)}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // ✅ เปิดแอปแผนที่จริงของเครื่อง (Google Maps/Apple Maps)
                      final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}',
                      );
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
                _mapController.move(_garagePosition, 16);
              },
              child: const Icon(Icons.my_location, color: Color(0xff2196F3)),
            ),
          ),
        ],
      ),
    );
  }
}
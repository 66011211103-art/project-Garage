import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
              // เลเยอร์ภาพแผนที่จาก OpenStreetMap (ฟรี ไม่ต้องใช้ API key)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_goodgarage',
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
                    onPressed: () {
                      // ✅ จุดปรับ: ต่อกับแอปนำทางจริง (Google Maps / Apple Maps)
                      // ผ่าน package url_launcher เช่น:
                      // launchUrl(Uri.parse(
                      //   'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}',
                      // ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('เปิดแอปนำทาง (ต้องเพิ่ม url_launcher)'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff2196F3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('นำทาง'),
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
              // เลเยอร์ภาพแผนที่จาก OpenStreetMap (ฟรี ไม่ต้องใช้ API key)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_goodgarage',
              ),
              // เลเยอร์หมุดปักตำแหน่ง
              MarkerLayer(
                markers: [
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

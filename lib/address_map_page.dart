import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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
              // ✅ CartoDB Voyager — ต้องตรงกับ garage_detail_page.dart และ garage_location_page.dart เสมอ
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.goodgarage.app',
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
                      // ✅ เปิดแอปแผนที่จริงของเครื่อง (Google Maps/Apple Maps)
                      final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}',
                      );
                      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('เปิดแอปแผนที่ไม่สำเร็จ'), backgroundColor: Colors.red),
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
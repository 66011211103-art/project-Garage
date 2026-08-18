import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// ขอ permission + ดึงตำแหน่งปัจจุบันของอุปกรณ์ (GPS บนมือถือ หรือ browser location บนเว็บ)
/// คืนค่า Position ถ้าสำเร็จ หรือโยน Exception พร้อมข้อความอธิบายถ้าไม่สำเร็จ
/// (ผู้ใช้ปิด location service, ไม่ให้สิทธิ์ ฯลฯ)
/// ใช้ร่วมกันได้ทุกหน้าที่ต้องรู้ตำแหน่งปัจจุบันของผู้ใช้ (เลือกที่อยู่ / ดูแผนที่ / ค้นหาอู่ใกล้ฉัน)
Future<Position> getCurrentPosition() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('กรุณาเปิดบริการตำแหน่ง (Location Service) ก่อน');
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    // ✅ ตรงนี้คือจุดที่จะเด้ง popup "อนุญาตให้เข้าถึงตำแหน่งหรือไม่" ของ browser/OS
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception(
      'ตำแหน่งถูกปฏิเสธถาวร กรุณาไปเปิดสิทธิ์ในตั้งค่าเบราว์เซอร์/อุปกรณ์',
    );
  }

  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}

/// แปลงพิกัด (lat, lon) กลับเป็นที่อยู่แบบอ่านได้ (reverse geocoding) ผ่าน Nominatim (OSM)
/// ใช้ตอนได้พิกัดดิบมา (เช่นจาก GPS หรือแตะค้างบนแผนที่) แล้วอยากโชว์เป็นชื่อที่อยู่ให้อ่านง่าย
Future<String?> reverseGeocodeOSM(double lat, double lon) async {
  final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse').replace(
    queryParameters: {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'format': 'json',
      'addressdetails': '1',
    },
  );

  try {
    final response = await http
        .get(
          uri,
          headers: {'User-Agent': 'flutter_goodgarage_app (student project)'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['display_name']?.toString();
  } catch (e) {
    return null;
  }
}

/// เรียกเส้นทางถนนจริงระหว่างจุดสองจุด ผ่าน OSRM (Open Source Routing Machine)
/// ซึ่งเป็นบริการหาเส้นทางฟรีสาธารณะ ไม่ต้องใช้ API key
/// คืนค่ารายการจุดตามแนวถนนจริง (ใช้วาดเป็นเส้น Polyline บนแผนที่)
/// หรือ null ถ้าหาเส้นทางไม่ได้ (เช่น เน็ตหลุด, ไม่มีถนนเชื่อมระหว่างจุด)
Future<List<LatLng>?> fetchRoute(LatLng start, LatLng end) async {
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
    '?overview=full&geometries=geojson',
  );

  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['code'] != 'Ok') return null;

    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return null;

    final coordinates = routes[0]['geometry']['coordinates'] as List;
    return coordinates
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  } catch (e) {
    return null;
  }
}
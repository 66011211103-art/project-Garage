// ============================================================
// 📄 ไฟล์: promptpay_qr.dart
// 📌 หน้า/ฟีเจอร์: ตัวสร้าง QR Code พร้อมเพย์ (PromptPay) จริง ตามมาตรฐาน EMV QR
//     Code / Thai QR Payment — ใช้ในหน้าชำระเงินฝั่งลูกค้า (customer_payment_page.dart)
//     ตอนเลือกวิธี "QR Payment"
// 📝 คำอธิบาย: รับเลขพร้อมเพย์ของอู่ (เบอร์โทร 10 หลัก หรือเลขบัตรประชาชน/เลข
//     ผู้เสียภาษี 13 หลัก) + ยอดเงิน แล้วประกอบเป็น payload ตามสเปก EMVCo
//     (Merchant Account Info tag 29 + AID พร้อมเพย์ A000000677010111) คำนวณ
//     CRC16-CCITT (poly 0x1021, init 0xFFFF) ปิดท้าย แล้ว render เป็น QR ภาพจริง
//     ด้วยแพ็กเกจ qr_flutter — สแกนจ่ายได้จริงจากแอปธนาคารทุกเจ้าที่รองรับพร้อมเพย์
// ⚠️ ต้องเพิ่ม dependency ใน pubspec.yaml ก่อนใช้งาน:
//     dependencies:
//       qr_flutter: ^4.1.0
//     แล้วรัน `flutter pub get`
// ============================================================

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// คำนวณ CRC16-CCITT (XModem variant) ตามที่สเปก EMV QR กำหนด
int _crc16(String input) {
  int crc = 0xFFFF;
  for (final unit in input.codeUnits) {
    crc ^= (unit << 8);
    for (int i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc & 0xFFFF;
}

/// ประกอบ TLV (Tag-Length-Value) ตามสเปก EMV QR — ทุก field เป็น tag 2 หลัก + ความยาว 2 หลัก + ค่า
String _tlv(String tag, String value) => '$tag${value.length.toString().padLeft(2, '0')}$value';

/// แปลงเลขพร้อมเพย์ดิบ (เบอร์โทร/เลขบัตร) ให้เป็น sub-field ที่ถูกต้องตามสเปก
/// คืนค่า null ถ้ารูปแบบไม่ถูกต้อง (ไม่ใช่เบอร์โทร 10 หลัก หรือเลขบัตร 13 หลัก)
String? _promptPayTarget(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

  // เลขบัตรประชาชน / เลขผู้เสียภาษี 13 หลัก -> sub tag 02
  if (digits.length == 13) {
    return _tlv('02', digits);
  }

  // เบอร์มือถือ 10 หลัก (ขึ้นต้นด้วย 0) -> แปลงเป็นรูปแบบสากล 0066XXXXXXXXX (13 หลัก) -> sub tag 01
  if (digits.length == 10 && digits.startsWith('0')) {
    final national = '0066${digits.substring(1)}';
    return _tlv('01', national);
  }

  // เผื่อกรอกมาโดยไม่มี 0 นำหน้า (9 หลัก)
  if (digits.length == 9) {
    final national = '0066$digits';
    return _tlv('01', national);
  }

  return null;
}

/// สร้าง payload string ของ QR พร้อมเพย์ — คืนค่า null ถ้าเลขพร้อมเพย์รูปแบบไม่ถูกต้อง
/// ถ้าใส่ [amount] มา จะเป็น QR "แบบระบุยอด" (สแกนแล้วยอดขึ้นให้เลย แก้ไม่ได้)
/// ถ้าไม่ใส่ จะเป็น QR "แบบไม่ระบุยอด" (ให้ลูกค้ากรอกยอดเอง)
String? buildPromptPayPayload({required String promptPayId, double? amount}) {
  final target = _promptPayTarget(promptPayId);
  if (target == null) return null;

  final merchantAccountInfo = _tlv('00', 'A000000677010111') + target;

  final buffer = StringBuffer()
    ..write(_tlv('00', '01')) // Payload Format Indicator
    ..write(_tlv('01', (amount != null && amount > 0) ? '12' : '11')) // Point of Initiation Method
    ..write(_tlv('29', merchantAccountInfo)) // Merchant Account Info (พร้อมเพย์)
    ..write(_tlv('53', '764')); // Transaction Currency = THB

  if (amount != null && amount > 0) {
    buffer.write(_tlv('54', amount.toStringAsFixed(2))); // Transaction Amount
  }
  buffer.write(_tlv('58', 'TH')); // Country Code

  final withoutCrc = '${buffer.toString()}6304';
  final crc = _crc16(withoutCrc).toRadixString(16).padLeft(4, '0').toUpperCase();
  return '$withoutCrc$crc';
}

/// การ์ดแสดง QR พร้อมเพย์แบบสแกนจ่ายได้จริง — ใช้ในหน้าชำระเงินฝั่งลูกค้า
class PromptPayQrCode extends StatelessWidget {
  final String promptPayId;
  final double amount;
  final String? accountName;

  const PromptPayQrCode({
    super.key,
    required this.promptPayId,
    required this.amount,
    this.accountName,
  });

  @override
  Widget build(BuildContext context) {
    final payload = buildPromptPayPayload(promptPayId: promptPayId, amount: amount);

    if (payload == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xffFFF3E0), borderRadius: BorderRadius.circular(14)),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: Color(0xffE65100), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'เลขพร้อมเพย์ของอู่ไม่ถูกต้อง (ต้องเป็นเบอร์โทร 10 หลัก หรือเลขบัตรประชาชน 13 หลัก) กรุณาติดต่ออู่โดยตรง',
                style: TextStyle(color: Color(0xffE65100), fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xff1E4598), borderRadius: BorderRadius.circular(6)),
            child: const Text('พร้อมเพย์ PromptPay',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(height: 18),
          QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 16),
          Text('฿${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xff1E4598))),
          if ((accountName ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(accountName!, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          const Text('เปิดแอปธนาคาร (สแกน QR / พร้อมเพย์) แล้วสแกนโค้ดนี้เพื่อชำระเงินได้เลย',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

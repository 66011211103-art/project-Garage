// ============================================================
// 📄 ไฟล์: review_card.dart
// 📌 หน้า/ฟีเจอร์: การ์ดสรุป "รีวิวอู่ซ่อม" — ฝังอยู่ในหน้า "ประวัติคำขอซ่อม"
//     (my_repair_requests_page.dart) ของฝั่งลูกค้า เมื่อคำขอซ่อมสถานะเป็น "completed"
// 📝 คำอธิบาย: เป็นแค่การ์ดสรุปสั้นๆ ในลิสต์ (ยึด pattern เดียวกับ quotation_card.dart
//     ที่ฝังอยู่ในลิสต์) — กดแล้วไปเปิดหน้า "รีวิวอู่ซ่อมรถ" แบบเต็มหน้าจอ
//     (garage_review_page.dart ตาม Figma ที่ลูกค้าส่งมา) ทั้งกรณีเขียนรีวิวใหม่
//     และกรณีดูรายละเอียดรีวิวที่เคยส่งไปแล้ว (คะแนนย่อยรายด้าน + รูปภาพ ซึ่งการ์ด
//     สรุปนี้ไม่มีพื้นที่พอจะแสดงครบ จึงส่งไปดูที่หน้าเต็มแทน)
// ============================================================

import 'package:flutter/material.dart';
import 'garage_review_page.dart';

class ReviewCard extends StatelessWidget {
  final int repairRequestId;
  final int customerId;
  final String shopName;
  final String? garageAvatar;
  final String? garageAddress;
  final int? initialRating;
  final String? initialComment;
  final String? initialReply;

  /// เรียกกลับเมื่อกลับมาจากหน้ารีวิวแบบเต็มหลังส่งรีวิวสำเร็จ เพื่อให้หน้าลิสต์รีเฟรช
  final VoidCallback? onSubmitted;

  const ReviewCard({
    super.key,
    required this.repairRequestId,
    required this.customerId,
    required this.shopName,
    this.garageAvatar,
    this.garageAddress,
    this.initialRating,
    this.initialComment,
    this.initialReply,
    this.onSubmitted,
  });

  Future<void> _openFullPage(BuildContext context) async {
    final submitted = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GarageReviewPage(
          repairRequestId: repairRequestId,
          customerId: customerId,
          shopName: shopName,
          garageAvatar: garageAvatar,
          garageAddress: garageAddress,
        ),
      ),
    );
    if (submitted == true) onSubmitted?.call();
  }

  Widget _starRow(int rating, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: const Color(0xffFFC107),
          size: size,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReviewed = initialRating != null;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () => _openFullPage(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------- หัวการ์ด ----------
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xffFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.star_outline, size: 16, color: Color(0xffFF9800)),
                  ),
                  const SizedBox(width: 8),
                  const Text('รีวิวอู่ซ่อม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  if (isReviewed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('รีวิวแล้ว',
                          style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              if (isReviewed) ...[
                // ---------- รีวิวไปแล้ว — สรุปสั้นๆ ในลิสต์ ----------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xffFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text('คุณให้คะแนนอู่นี้แล้ว',
                          style: TextStyle(color: Colors.amber.shade800, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _starRow(initialRating!, size: 22),
                      if ((initialComment ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(initialComment!.trim(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, height: 1.4)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if ((initialReply ?? '').trim().isNotEmpty) ...[
                      Icon(Icons.reply, size: 14, color: Colors.blue.shade600),
                      const SizedBox(width: 4),
                      Text('อู่ตอบกลับแล้ว · ',
                          style: TextStyle(color: Colors.blue.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                    Text('ดูรายละเอียด', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade600),
                  ],
                ),
              ] else ...[
                // ---------- ยังไม่รีวิว — ชวนกดเข้าไปเขียน ----------
                const Text('งานซ่อมเสร็จแล้ว — ให้คะแนนความพึงพอใจของคุณได้เลย',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openFullPage(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffFF9800),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.star, color: Colors.white, size: 18),
                    label: const Text('ให้คะแนนอู่ซ่อม',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
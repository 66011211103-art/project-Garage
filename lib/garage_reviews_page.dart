// ============================================================
// 📄 ไฟล์: garage_reviews_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "รีวิวจากลูกค้า" ฝั่งอู่ (ตาม Figma ที่ส่งมา)
// 📝 คำอธิบาย: แสดงคะแนนเฉลี่ย + กราฟแท่งแจกแจงจำนวนรีวิวแต่ละดาว (1-5) ด้านบน
//     ตามด้วยลิสต์รีวิวทั้งหมดของอู่ — แต่ละรีวิวโชว์รูปที่ลูกค้าแนบมา (ถ้ามี กดดู
//     แบบเต็มจอได้) และอู่กด "ตอบกลับ" เขียนคำตอบให้ลูกค้าเห็นได้ (ตอบซ้ำ = แก้ไข
//     คำตอบเดิม)
// 📌 ใช้งานได้ 2 แบบ:
//   - embedded: true  → ไม่มี AppBar/ปุ่มย้อนกลับ (ใช้เป็นเนื้อหาของแท็บ "รีวิว"
//     ในหน้า garage_dashboard.dart)
//   - embedded: false (ค่าเริ่มต้น) → มี AppBar + ปุ่มย้อนกลับ (ใช้ตอน Navigator.push
//     จากเมนูด่วนในหน้า dashboard)
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';

class GarageReviewsPage extends StatefulWidget {
  final int garageId;
  final bool embedded;

  const GarageReviewsPage({super.key, required this.garageId, this.embedded = false});

  @override
  State<GarageReviewsPage> createState() => _GarageReviewsPageState();
}

class _GarageReviewsPageState extends State<GarageReviewsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0;
  int _totalReviews = 0;
  Map<int, int> _ratingCounts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getReviews(garageId: widget.garageId);
    if (!mounted) return;

    if (result.success && result.data != null) {
      final rawCounts = result.data!['ratingCounts'] as Map<String, dynamic>? ?? {};
      setState(() {
        _isLoading = false;
        _reviews = List<Map<String, dynamic>>.from(result.data!['reviews'] ?? []);
        _averageRating = (result.data!['averageRating'] as num?)?.toDouble() ?? 0;
        _totalReviews = (result.data!['totalReviews'] as num?)?.toInt() ?? 0;
        _ratingCounts = {
          for (var star = 1; star <= 5; star++) star: (rawCounts['$star'] as num?)?.toInt() ?? 0,
        };
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  String _timeAgo(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '');
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 7) return '${(diff.inDays / 7).floor()} สัปดาห์ที่แล้ว';
    if (diff.inDays >= 1) return '${diff.inDays} วันที่แล้ว';
    if (diff.inHours >= 1) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} นาทีที่แล้ว';
    return 'เมื่อสักครู่';
  }

  Widget _starRow(int rating, {double size = 16}) {
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

  void _viewPhoto(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(child: Image.network(url)),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReplySheet(Map<String, dynamic> review) async {
    final controller = TextEditingController(text: review['reply']?.toString() ?? '');
    final isEditing = (review['reply']?.toString() ?? '').isNotEmpty;

    final reply = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isEditing ? 'แก้ไขคำตอบกลับ' : 'ตอบกลับรีวิวลูกค้า',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'ขอบคุณสำหรับรีวิว หรือชี้แจงเพิ่มเติม...',
                  filled: true,
                  fillColor: const Color(0xffF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    Navigator.pop(context, controller.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('บันทึกคำตอบ', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (reply == null || reply.isEmpty) return;

    final result = await ApiService.replyToReview(
      reviewId: review['id'],
      garageId: widget.garageId,
      reply: reply,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) _fetchReviews();
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      onRefresh: _fetchReviews,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCard(),
                const SizedBox(height: 20),
                const Text('รีวิวทั้งหมด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 12),
                if (_reviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('ยังไม่มีรีวิวจากลูกค้า', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ..._reviews.map(_reviewCard),
              ],
            ),
    );

    if (widget.embedded) {
      return Scaffold(backgroundColor: const Color(0xffF5F5F5), body: body);
    }

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('รีวิวจากลูกค้า', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: body,
    );
  }

  Widget _summaryCard() {
    final maxCount = _ratingCounts.values.fold<int>(0, (m, v) => v > m ? v : m);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ---------- คะแนนเฉลี่ย ----------
          Expanded(
            child: Column(
              children: [
                Text(_averageRating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xff2196F3))),
                const SizedBox(height: 4),
                _starRow(_averageRating.round(), size: 20),
                const SizedBox(height: 6),
                Text('จาก $_totalReviews รีวิว', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ---------- แจกแจงรายดาว ----------
          Expanded(
            flex: 2,
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = _ratingCounts[star] ?? 0;
                final ratio = maxCount == 0 ? 0.0 : count / maxCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text('$star', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Icon(Icons.star, size: 12, color: Color(0xffFFC107)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: const Color(0xffEEEEEE),
                            color: const Color(0xffFFC107),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 24,
                        child: Text('$count', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final name = '${review['first_name'] ?? ''} ${review['last_name'] ?? ''}'.trim();
    final avatar = review['customer_avatar']?.toString();
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment']?.toString() ?? '';
    final photos = (review['photos'] is List) ? List<dynamic>.from(review['photos']) : [];
    final reply = review['reply']?.toString() ?? '';
    final hasReply = reply.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xffE3F2FD),
                backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                child: (avatar == null || avatar.isEmpty)
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Color(0xff2196F3), fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'ลูกค้า' : name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    _starRow(rating),
                  ],
                ),
              ),
              Text(_timeAgo(review['created_at']?.toString()),
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment, style: const TextStyle(fontSize: 13, height: 1.5)),
          ],

          // ---------- รูปที่ลูกค้าแนบมา ----------
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _viewPhoto(photos[i].toString()),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(photos[i].toString(), width: 72, height: 72, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // ---------- คำตอบกลับจากอู่ ----------
          if (hasReply) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xffE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, size: 14, color: Color(0xff2196F3)),
                      const SizedBox(width: 6),
                      const Text('การตอบกลับจากอู่',
                          style: TextStyle(color: Color(0xff2196F3), fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(reply, style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _openReplySheet(review),
                child: const Text('แก้ไขคำตอบ', style: TextStyle(fontSize: 12)),
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openReplySheet(review),
                icon: const Icon(Icons.reply, size: 15),
                label: const Text('ตอบกลับ', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff2196F3),
                  side: const BorderSide(color: Color(0xff2196F3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
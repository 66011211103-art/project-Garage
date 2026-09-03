// ============================================================
// 📄 ไฟล์: garage_reviews_page.dart
// 📌 หน้า/ฟีเจอร์: "ดูรีวิวทั้งหมด" ของอู่ซ่อม — เปิดจากปุ่ม "ดูรีวิว" ใน
//     garage_detail_page.dart
// 📝 คำอธิบาย: เชื่อมกับ ApiService.getReviews(garageId: ...) ที่มีอยู่แล้ว
//     (ไม่ต้องแก้ backend เลย — endpoint พร้อมส่ง averageRating, totalReviews,
//     ratingCounts แยกตามดาว 1-5 และรายการรีวิวแต่ละรายการมาให้ครบ)
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'network_image_helper.dart';
import 'app_locale.dart';

class GarageReviewsPage extends StatefulWidget {
  final int garageId;
  final String? shopName;
  /// ✅ true = ใช้ฝังอยู่ในแท็บอื่น (เช่น garage_dashboard.dart) ซ่อน AppBar ของตัวเอง
  final bool embedded;
  /// ✅ true = หน้านี้เปิดโดยอู่เจ้าของร้านเอง (ผ่านแท็บ "รีวิว" ในแดชบอร์ดของอู่) —
  ///     ให้ตอบกลับ/แก้ไขคำตอบรีวิวได้ ส่วนตอนลูกค้าเปิดดูรีวิวจาก garage_detail_page.dart
  ///     (ไม่ใช่เจ้าของร้าน) จะเป็น false เสมอ เห็นได้อย่างเดียว ตอบไม่ได้
  final bool canReply;

  const GarageReviewsPage({
    super.key,
    required this.garageId,
    this.shopName,
    this.embedded = false,
    this.canReply = false,
  });

  @override
  State<GarageReviewsPage> createState() => _GarageReviewsPageState();
}

class _GarageReviewsPageState extends State<GarageReviewsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0;
  int _totalReviews = 0;
  Map<String, dynamic> _ratingCounts = {};

  // ✅ สถานะกล่องตอบกลับรีวิว (แยกตาม reviewId เผื่ออนาคตอยากเปิดตอบหลายรีวิวพร้อมกัน)
  final Set<int> _editingReviewIds = {};
  final Map<int, TextEditingController> _replyControllers = {};
  final Set<int> _submittingReviewIds = {};

  @override
  void initState() {
    super.initState();
    _fetchReviews();
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getReviews(garageId: widget.garageId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success && result.data != null) {
        _reviews = List<Map<String, dynamic>>.from(result.data!['reviews'] ?? []);
        _averageRating = (result.data!['averageRating'] as num?)?.toDouble() ?? 0;
        _totalReviews = (result.data!['totalReviews'] as num?)?.toInt() ?? 0;
        _ratingCounts = Map<String, dynamic>.from(result.data!['ratingCounts'] ?? {});
      }
    });
  }

  int _countFor(int star) => (_ratingCounts['$star'] as num?)?.toInt() ?? 0;

  String get _shopLabel => widget.shopName ?? AppLocale.instance.t('grp_shop_fallback');

  String _formatDate(String? isoString) {
    // ✅ backend ส่งเวลาเป็น UTC ISO string — ไม่ .toLocal() ก่อน วันที่จะเพี้ยนได้
    final dt = DateTime.tryParse(isoString ?? '')?.toLocal();
    if (dt == null) return '-';
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final buddhistYear = dt.year + 543;
    return '${dt.day} ${months[dt.month - 1]} $buddhistYear';
  }

  Widget _starRow(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
            i < rating ? Icons.star : Icons.star_border,
            color: const Color(0xffFFC107),
            size: size,
          )),
    );
  }

  TextEditingController _replyControllerFor(int reviewId, String initialText) {
    return _replyControllers.putIfAbsent(reviewId, () => TextEditingController(text: initialText));
  }

  void _startEditingReply(int reviewId, String? existingReply) {
    setState(() {
      _editingReviewIds.add(reviewId);
      // ✅ set ค่า .text ตรงๆ ทุกครั้งที่เปิดกล่อง (ไม่พึ่ง putIfAbsent อย่างเดียว) กัน
      // กรณีเคยพิมพ์ร่างไว้ก่อนหน้าแล้วกด "ยกเลิก" — คอนโทรลเลอร์เดิมยังอยู่ในแคช
      // ถ้าไม่ set ซ้ำ เปิดใหม่จะเห็นข้อความร่างเก่าค้างอยู่แทนคำตอบปัจจุบันจริงๆ
      _replyControllerFor(reviewId, existingReply ?? '').text = existingReply ?? '';
    });
  }

  void _cancelEditingReply(int reviewId) {
    setState(() => _editingReviewIds.remove(reviewId));
  }

  // ✅ เรียก PUT /api/reviews/:id/reply ที่มีอยู่แล้วในฝั่ง backend (ตอบใหม่หรือแก้ไขคำตอบเดิมก็ endpoint เดียวกัน)
  Future<void> _submitReply(int reviewId) async {
    final loc = AppLocale.instance;
    final text = _replyControllers[reviewId]?.text.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('grp_reply_empty_error')), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _submittingReviewIds.add(reviewId));
    final result = await ApiService.replyToReview(reviewId: reviewId, garageId: widget.garageId, reply: text);
    if (!mounted) return;

    setState(() {
      _submittingReviewIds.remove(reviewId);
      if (result.success) {
        _editingReviewIds.remove(reviewId);
        // ✅ อัปเดตข้อมูลในลิสต์ทันที ไม่ต้องรอ fetch ใหม่ทั้งหน้า ผู้ใช้เห็นผลทันที
        final idx = _reviews.indexWhere((r) => (r['id'] as num?)?.toInt() == reviewId);
        if (idx != -1) _reviews[idx] = {..._reviews[idx], 'reply': text};
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    final body = RefreshIndicator(
        onRefresh: _fetchReviews,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _reviews.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 100),
                        child: Center(
                          child: Text(loc.t('grp_empty_state'), style: const TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ---------- สรุปคะแนนเฉลี่ย ----------
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Text(_averageRating.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                                _starRow(_averageRating.round()),
                                const SizedBox(height: 4),
                                Text(loc.t('grp_reviews_count').replaceAll('%s', '$_totalReviews'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                children: List.generate(5, (i) {
                                  final star = 5 - i;
                                  final count = _countFor(star);
                                  final ratio = _totalReviews > 0 ? count / _totalReviews : 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        Text('$star', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.star, size: 12, color: Color(0xffFFC107)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: LinearProgressIndicator(
                                              value: ratio,
                                              minHeight: 7,
                                              backgroundColor: const Color(0xffF0F0F0),
                                              valueColor: const AlwaysStoppedAnimation(Color(0xffFFC107)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 22,
                                          child: Text('$count', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(loc.t('grp_all_reviews_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),

                      ..._reviews.map((r) {
                        final name = '${r['first_name'] ?? ''} ${r['last_name'] ?? ''}'.trim();
                        final avatar = r['customer_avatar']?.toString();
                        final photos = (r['photos'] is List) ? List<dynamic>.from(r['photos']) : [];
                        final reply = r['reply']?.toString();
                        final reviewId = (r['id'] as num?)?.toInt();
                        final isEditing = reviewId != null && _editingReviewIds.contains(reviewId);
                        final isSubmitting = reviewId != null && _submittingReviewIds.contains(reviewId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xffE3F2FD),
                                    backgroundImage: (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
                                    child: (avatar == null || avatar.isEmpty)
                                        ? const Icon(Icons.person, color: Color(0xff2196F3), size: 18)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name.isEmpty ? loc.t('profile_type_customer') : name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text(_formatDate(r['created_at']?.toString()),
                                            style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  _starRow((r['rating'] as num?)?.toInt() ?? 0),
                                ],
                              ),
                              if ((r['comment']?.toString() ?? '').isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(r['comment'].toString(), style: const TextStyle(fontSize: 13.5, height: 1.4)),
                              ],
                              if (photos.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 78,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: photos.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                                    itemBuilder: (context, i) => ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: NetImage(photos[i].toString(), width: 78, height: 78, fit: BoxFit.cover),
                                    ),
                                  ),
                                ),
                              ],
                              // ✅ โชว์กล่องคำตอบเดิม เฉพาะตอนที่ "ไม่ได้" กำลังแก้ไขอยู่
                              if (!isEditing && reply != null && reply.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffF5F5F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.reply, size: 14, color: Color(0xff2196F3)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(loc.t('grp_reply_from_prefix').replaceAll('%s', _shopLabel),
                                                style: const TextStyle(
                                                    fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xff2196F3))),
                                          ),
                                          // ✅ อู่เจ้าของร้านแก้ไขคำตอบเดิมได้ (ลูกค้าที่เปิดดูจาก garage_detail_page.dart จะไม่เห็นปุ่มนี้)
                                          if (widget.canReply && reviewId != null)
                                            InkWell(
                                              onTap: () => _startEditingReply(reviewId, reply),
                                              child: Text(loc.t('grp_reply_edit_button'),
                                                  style: const TextStyle(
                                                      fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(reply, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                                    ],
                                  ),
                                ),
                              ],
                              // ✅ ยังไม่เคยตอบกลับ + เป็นอู่เจ้าของร้าน + ไม่ได้กำลังพิมพ์อยู่ -> โชว์ปุ่มเริ่มตอบ
                              if (widget.canReply && reviewId != null && !isEditing && (reply == null || reply.isEmpty)) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _startEditingReply(reviewId, null),
                                    icon: const Icon(Icons.reply, size: 16),
                                    label: Text(loc.t('grp_reply_button')),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xff2196F3),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                    ),
                                  ),
                                ),
                              ],
                              // ✅ กล่องพิมพ์ตอบกลับ/แก้ไขคำตอบ (ใช้ endpoint เดียวกันทั้งตอบใหม่และแก้ไขของเดิม)
                              if (widget.canReply && reviewId != null && isEditing) ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _replyControllerFor(reviewId, reply ?? ''),
                                  autofocus: true,
                                  maxLines: 3,
                                  minLines: 2,
                                  decoration: InputDecoration(
                                    hintText: loc.t('grp_reply_hint'),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.all(10),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: isSubmitting ? null : () => _cancelEditingReply(reviewId),
                                      child: Text(loc.t('grp_reply_cancel')),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      onPressed: isSubmitting ? null : () => _submitReply(reviewId),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff2196F3)),
                                      child: isSubmitting
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Text(loc.t('grp_reply_send')),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
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
        title: Text(loc.t('grp_page_title').replaceAll('%s', _shopLabel), style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: body,
    );
  }
}
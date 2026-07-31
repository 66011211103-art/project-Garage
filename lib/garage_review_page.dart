// ============================================================
// 📄 ไฟล์: garage_review_page.dart
// 📌 หน้า/ฟีเจอร์: หน้า "รีวิวอู่ซ่อมรถ" แบบเต็มหน้าจอ (ตาม Figma ที่ลูกค้าส่งมา)
// 📝 คำอธิบาย: ใช้ 2 โหมดในไฟล์เดียวกัน —
//   1) โหมดเขียนรีวิว (ยังไม่เคยรีวิวงานนี้): กดดาวรวม + ดาวรายด้าน (คุณภาพงาน/
//      ราคา/บริการ) + เขียนความเห็น + แนบรูปได้ แล้วกด "ส่งรีวิว"
//   2) โหมดดูรายละเอียด (รีวิวไปแล้ว): โชว์ค่าที่ส่งไปแบบอ่านอย่างเดียว ไม่มีปุ่มส่ง
//   เข้าถึงได้จากปุ่ม "ให้คะแนนอู่ซ่อม" / "ดูรายละเอียด" ในการ์ดรีวิวของหน้า
//   ประวัติคำขอซ่อม (my_repair_requests_page.dart ผ่าน review_card.dart)
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

const int kMaxReviewPhotos = 5;

class GarageReviewPage extends StatefulWidget {
  final int repairRequestId;
  final int customerId;
  final String shopName;
  final String? garageAvatar;
  final String? garageAddress;

  const GarageReviewPage({
    super.key,
    required this.repairRequestId,
    required this.customerId,
    required this.shopName,
    this.garageAvatar,
    this.garageAddress,
  });

  @override
  State<GarageReviewPage> createState() => _GarageReviewPageState();
}

class _GarageReviewPageState extends State<GarageReviewPage> {
  bool _isLoading = true;
  bool _isReadOnly = false;

  int _rating = 0;
  int _qualityRating = 0;
  int _priceRating = 0;
  int _serviceRating = 0;
  final _commentController = TextEditingController();

  // รูปที่เพิ่งเลือก (โหมดเขียน) VS รูปที่รีวิวไว้แล้ว (โหมดอ่าน เป็น URL จาก server)
  final List<Uint8List> _newPhotos = [];
  final List<String> _newPhotoNames = [];
  List<String> _existingPhotoUrls = [];

  // ✅ คำตอบกลับจากอู่ (ถ้ามี) — ให้ลูกค้าเห็นว่าอู่ตอบกลับรีวิวของตัวเองว่าอย่างไร
  String? _reply;
  String? _repliedAt;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchExistingReview();
  }

  // ✅ เช็กจาก server เสมอว่างานนี้มีรีวิวอยู่แล้วหรือยัง (เอาข้อมูลล่าสุด/ครบทุกฟิลด์
  // รวมคะแนนย่อยและรูปภาพ ไม่ต้องพึ่งข้อมูลที่การ์ดสรุปในหน้าลิสต์ส่งมา)
  Future<void> _fetchExistingReview() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getReviews(repairRequestId: widget.repairRequestId);
    if (!mounted) return;

    final existing = result.success ? (result.data?['review'] as Map<String, dynamic>?) : null;
    setState(() {
      _isLoading = false;
      _isReadOnly = existing != null;
      if (existing != null) {
        _rating = (existing['rating'] as num?)?.toInt() ?? 0;
        _qualityRating = (existing['quality_rating'] as num?)?.toInt() ?? 0;
        _priceRating = (existing['price_rating'] as num?)?.toInt() ?? 0;
        _serviceRating = (existing['service_rating'] as num?)?.toInt() ?? 0;
        _commentController.text = existing['comment']?.toString() ?? '';
        _existingPhotoUrls = (existing['photos'] is List) ? List<String>.from(existing['photos']) : [];
        _reply = existing['reply']?.toString();
        _repliedAt = existing['replied_at']?.toString();
      }
    });
  }


  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1:
        return 'แย่มาก';
      case 2:
        return 'ต้องปรับปรุง';
      case 3:
        return 'พอใช้';
      case 4:
        return 'ดีมาก';
      case 5:
        return 'ยอดเยี่ยม';
      default:
        return '';
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

  Future<void> _pickPhotos() async {
    final remaining = kMaxReviewPhotos - _newPhotos.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).toList();
    final bytesList = await Future.wait(toAdd.map((f) => f.readAsBytes()));

    if (!mounted) return;
    setState(() {
      for (var i = 0; i < toAdd.length; i++) {
        _newPhotos.add(bytesList[i]);
        _newPhotoNames.add(toAdd[i].name);
      }
    });
  }

  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotos.removeAt(index);
      _newPhotoNames.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาให้คะแนนบริการอย่างน้อย 1 ดาว'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ApiService.submitReview(
      repairRequestId: widget.repairRequestId,
      customerId: widget.customerId,
      rating: _rating,
      qualityRating: _qualityRating == 0 ? null : _qualityRating,
      priceRating: _priceRating == 0 ? null : _priceRating,
      serviceRating: _serviceRating == 0 ? null : _serviceRating,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      photos: _newPhotos,
      photoNames: _newPhotoNames,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red),
    );

    if (result.success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('รีวิวอู่ซ่อมรถ', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---------- ข้อมูลอู่ ----------
                _card(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: widget.garageAvatar != null && widget.garageAvatar!.isNotEmpty
                            ? Image.network(widget.garageAvatar!, width: 56, height: 56, fit: BoxFit.cover)
                            : Container(
                                width: 56,
                                height: 56,
                                color: const Color(0xffE3F2FD),
                                child: const Icon(Icons.store, color: Color(0xff2196F3)),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.shopName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            if (widget.garageAddress != null && widget.garageAddress!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.garageAddress!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ---------- ให้คะแนนบริการ (คะแนนรวม) ----------
                _card(
                  child: Column(
                    children: [
                      const Text('ให้คะแนนบริการ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 14),
                      _starRow(
                        _rating,
                        size: 36,
                        interactive: !_isReadOnly,
                        onTap: (v) => setState(() => _rating = v),
                      ),
                      if (_rating > 0) ...[
                        const SizedBox(height: 8),
                        Text(_ratingLabel(_rating),
                            style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ---------- ประเมินด้านต่างๆ ----------
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ประเมินด้านต่างๆ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      _subRatingRow(
                        icon: Icons.thumb_up_outlined,
                        color: const Color(0xff2196F3),
                        label: 'คุณภาพงานซ่อม',
                        value: _qualityRating,
                        onTap: (v) => setState(() => _qualityRating = v),
                      ),
                      const SizedBox(height: 12),
                      _subRatingRow(
                        icon: Icons.attach_money,
                        color: const Color(0xff4CAF50),
                        label: 'ราคาเหมาะสม',
                        value: _priceRating,
                        onTap: (v) => setState(() => _priceRating = v),
                      ),
                      const SizedBox(height: 12),
                      _subRatingRow(
                        icon: Icons.support_agent_outlined,
                        color: const Color(0xff9C27B0),
                        label: 'บริการและพนักงาน',
                        value: _serviceRating,
                        onTap: (v) => setState(() => _serviceRating = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text('เขียนรีวิว', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 10),
                if (_isReadOnly)
                  _card(
                    child: Text(
                      _commentController.text.trim().isNotEmpty
                          ? _commentController.text.trim()
                          : 'ไม่มีความเห็นเพิ่มเติม',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: _commentController.text.trim().isNotEmpty ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'บอกเล่าประสบการณ์ของคุณกับอู่แห่งนี้...',
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                // ---------- รูปภาพประกอบ ----------
                if (!_isReadOnly || _existingPhotoUrls.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(_isReadOnly ? 'รูปภาพที่แนบมา' : 'เพิ่มรูปภาพ (ถ้ามี)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 88,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _isReadOnly
                          ? _existingPhotoUrls
                              .map((url) => Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(url, width: 88, height: 88, fit: BoxFit.cover),
                                    ),
                                  ))
                              .toList()
                          : [
                              ..._newPhotos.asMap().entries.map((entry) {
                                final index = entry.key;
                                final bytes = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.memory(bytes, width: 88, height: 88, fit: BoxFit.cover),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _removeNewPhoto(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration:
                                                const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (_newPhotos.length < kMaxReviewPhotos)
                                InkWell(
                                  onTap: _pickPhotos,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400),
                                        const SizedBox(height: 6),
                                        Text('เพิ่มรูป',
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                    ),
                  ),
                ],

                // ---------- คำตอบกลับจากอู่ ----------
                if (_isReadOnly && (_reply ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('การตอบกลับจากอู่', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xffE3F2FD),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.store, size: 16, color: Color(0xff2196F3)),
                            const SizedBox(width: 6),
                            Text(widget.shopName,
                                style: const TextStyle(
                                    color: Color(0xff2196F3), fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                            if (_repliedAt != null)
                              Text(_timeAgo(_repliedAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_reply!, style: const TextStyle(fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),

          // ===== ปุ่มส่งรีวิว ติดด้านล่างเสมอ (โหมดเขียนเท่านั้น) =====
          if (!_isReadOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                  label: Text(_isSubmitting ? 'กำลังส่ง...' : 'ส่งรีวิว',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _subRatingRow({
    required IconData icon,
    required Color color,
    required String label,
    required int value,
    required void Function(int) onTap,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        _starRow(value, size: 18, interactive: !_isReadOnly, onTap: onTap),
      ],
    );
  }

  Widget _starRow(int rating, {required double size, bool interactive = false, void Function(int)? onTap}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        final star = Icon(
          filled ? Icons.star : Icons.star_border,
          color: const Color(0xffFFC107),
          size: size,
        );
        if (!interactive || onTap == null) return star;
        return InkWell(
          onTap: () => onTap(i + 1),
          borderRadius: BorderRadius.circular(size),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: star),
        );
      }),
    );
  }
}
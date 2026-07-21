import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

const int kMaxLogPhotos = 5;

class AddRepairLogPage extends StatefulWidget {
  final int repairRequestId;
  final int technicianId;

  const AddRepairLogPage({super.key, required this.repairRequestId, required this.technicianId});

  @override
  State<AddRepairLogPage> createState() => _AddRepairLogPageState();
}

class _AddRepairLogPageState extends State<AddRepairLogPage> {
  final _noteController = TextEditingController();
  final _partsController = TextEditingController();
  final List<Uint8List> _photos = [];
  final List<String> _photoNames = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    _partsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = kMaxLogPhotos - _photos.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    final toAdd = picked.take(remaining).toList();
    final bytesList = await Future.wait(toAdd.map((f) => f.readAsBytes()));

    if (!mounted) return;
    setState(() {
      for (var i = 0; i < toAdd.length; i++) {
        _photos.add(bytesList[i]);
        _photoNames.add(toAdd[i].name);
      }
    });
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
      _photoNames.removeAt(index);
    });
  }

  Future<void> _handleSubmit() async {
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกรายละเอียดความคืบหน้า'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ApiService.createRepairLog(
      repairRequestId: widget.repairRequestId,
      technicianId: widget.technicianId,
      note: _noteController.text.trim(),
      partsUsed: _partsController.text.trim(),
      photos: _photos,
      photoNames: _photoNames,
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
        title: const Text('บันทึกความคืบหน้า', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รายละเอียดที่ทำไป', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'เช่น ถอดเครื่องยนต์ตรวจเช็ค พบว่าปั๊มน้ำรั่ว...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text('อะไหล่ที่ใช้ (ถ้ามี)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _partsController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'เช่น ปั๊มน้ำ 1 ชิ้น, สายพานราวลิ้น 1 เส้น',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                const Text('รูปภาพความคืบหน้า', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text('(${_photos.length}/$kMaxLogPhotos)',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._photos.asMap().entries.map((entry) {
                    final index = entry.key;
                    final bytes = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(bytes, width: 92, height: 92, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removePhoto(index),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_photos.length < kMaxLogPhotos)
                    InkWell(
                      onTap: _pickPhotos,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 92,
                        height: 92,
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
                            Text('เพิ่มรูปภาพ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'กำลังบันทึก...' : 'บันทึกความคืบหน้า',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 📄 ไฟล์: chat_screen.dart
// 📌 หน้า/ฟีเจอร์: หน้าสนทนา 1 บทสนทนา — ใช้ร่วมกันทั้งฝั่งลูกค้าและฝั่งอู่
//     (สลับด้วย myType: 'customer' หรือ 'repair')
// 📝 คำอธิบาย: ของจริงแล้ว — โหลดประวัติข้อความจาก DB, ส่งข้อความ/แนบรูปได้จริง,
//     รับข้อความใหม่แบบ real-time ผ่าน Socket.IO (event 'chat_message' จาก
//     socket_notification_service.dart ตัวเดียวกับที่ใช้ส่ง push notification)
//     มาร์คข้อความว่าอ่านแล้วอัตโนมัติตอนเปิดหน้า
// ============================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'socket_notification_service.dart';

class ChatScreen extends StatefulWidget {
  final int conversationId;
  final int myId;
  final String myType; // 'customer' | 'repair'
  final String otherPartyName;
  final String? otherPartyAvatar;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.myId,
    required this.myType,
    required this.otherPartyName,
    this.otherPartyAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isLoading = true;
  final List<Map<String, dynamic>> _messages = [];
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  Uint8List? _pendingImage;
  String? _pendingImageName;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    // ✅ ฟังข้อความใหม่แบบ real-time จาก socket ตัวเดียวกับระบบแจ้งเตือน
    SocketNotificationService.socket?.on('chat_message', _onIncomingMessage);
  }

  @override
  void dispose() {
    SocketNotificationService.socket?.off('chat_message', _onIncomingMessage);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onIncomingMessage(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['conversation_id']?.toString() != widget.conversationId.toString()) return;
    if (!mounted) return;
    setState(() => _messages.add(map));
    _scrollToBottom();
  }

  Future<void> _fetchMessages() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getMessages(conversationId: widget.conversationId, viewerType: widget.myType);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _messages
        ..clear()
        ..addAll(result.success && result.data != null
            ? List<Map<String, dynamic>>.from(result.data!['messages'] ?? [])
            : []);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animate: false));
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingImage = bytes;
      _pendingImageName = picked.name;
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingImage == null) return;

    setState(() => _isSending = true);
    final result = await ApiService.sendMessage(
      conversationId: widget.conversationId,
      senderId: widget.myId,
      senderType: widget.myType,
      message: text.isEmpty ? null : text,
      imageBytes: _pendingImage,
      imageName: _pendingImageName,
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.success) {
      setState(() {
        _messages.add(Map<String, dynamic>.from(result.data!['message']));
        _messageController.clear();
        _pendingImage = null;
        _pendingImageName = null;
      });
      _scrollToBottom();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  String _formatTime(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '');
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'วันนี้';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(dt, yesterday)) return 'เมื่อวาน';
    final buddhistYear2Digit = (dt.year + 543) % 100;
    return '${dt.day}/${dt.month}/${buddhistYear2Digit.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: (widget.otherPartyAvatar != null && widget.otherPartyAvatar!.isNotEmpty)
                  ? NetworkImage(widget.otherPartyAvatar!)
                  : null,
              child: (widget.otherPartyAvatar == null || widget.otherPartyAvatar!.isEmpty)
                  ? const Icon(Icons.store, color: Colors.white, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.otherPartyName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('ยังไม่มีข้อความ เริ่มทักทายกันได้เลย', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final isMe = m['sender_type']?.toString() == widget.myType;
                          final dt = DateTime.tryParse(m['created_at']?.toString() ?? '');
                          final showDayDivider = index == 0 ||
                              (dt != null &&
                                  !_isSameDay(dt, DateTime.tryParse(_messages[index - 1]['created_at']?.toString() ?? '') ?? dt));

                          return Column(
                            children: [
                              if (showDayDivider && dt != null) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(_dayLabel(dt),
                                            style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                ),
                              ],
                              Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (m['image'] != null) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(m['image'].toString(),
                                            width: 200, fit: BoxFit.cover),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    if ((m['message']?.toString() ?? '').isNotEmpty)
                                      Container(
                                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                        margin: const EdgeInsets.only(bottom: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isMe ? const Color(0xff2196F3) : Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(m['message'].toString(),
                                            style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
                                      ),
                                    Text(_formatTime(m['created_at']?.toString()),
                                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          if (_pendingImage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_pendingImage!, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('พร้อมส่งรูปภาพ', style: TextStyle(fontSize: 13, color: Colors.grey))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() {
                      _pendingImage = null;
                      _pendingImageName = null;
                    }),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: Colors.grey),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        filled: true,
                        fillColor: const Color(0xffF5F5F5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send, color: Color(0xff2196F3)),
                    onPressed: _isSending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
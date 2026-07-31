// ============================================================
// 📄 ไฟล์: chat_list_page.dart
// 📌 หน้า/ฟีเจอร์: ลิสต์บทสนทนาทั้งหมดของลูกค้า (แท็บ "แชท" ในหน้าแรก)
// 📝 คำอธิบาย: เดิมแท็บนี้เปิด ChatScreen() ตรงๆ (มีแค่บทสนทนาเดียว/ข้อมูลตัวอย่าง)
//     ตอนนี้เปลี่ยนเป็นลิสต์บทสนทนาจริงจาก DB ก่อน แล้วค่อยกดเข้าไปคุยแต่ละอู่
// ============================================================

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'chat_screen.dart';

class ChatListPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ChatListPage({super.key, required this.userData});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations.where((c) {
      final shopName = (c['shop_name']?.toString() ?? '').toLowerCase();
      final lastMessage = (c['last_message']?.toString() ?? '').toLowerCase();
      return shopName.contains(_searchQuery) || lastMessage.contains(_searchQuery);
    }).toList();
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getConversations(customerId: widget.userData['id']);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _conversations = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['conversations'] ?? [])
          : [];
    });
  }

  String _timeAgo(String? isoString) {
    final dt = DateTime.tryParse(isoString ?? '');
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 1) return '${diff.inDays} วันที่แล้ว';
    if (diff.inHours >= 1) return '${diff.inHours} ชม.ที่แล้ว';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} นาทีที่แล้ว';
    return 'เมื่อสักครู่';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchConversations,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('แชท', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาแชท',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _conversations.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 80),
                                child: Center(
                                  child: Text('ยังไม่มีบทสนทนา\nแชทกับอู่ได้จากหน้ารายละเอียดคำขอซ่อม',
                                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                                ),
                              ),
                            ],
                          )
                        : _filteredConversations.isEmpty
                            ? const Center(child: Text('ไม่พบแชทที่ค้นหา', style: TextStyle(color: Colors.grey)))
                            : ListView.separated(
                                itemCount: _filteredConversations.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
                                itemBuilder: (context, index) {
                                  final c = _filteredConversations[index];
                                  final unread = (c['unread_count'] as num?)?.toInt() ?? 0;
                                  final isUnread = unread > 0;
                                  final lastMessage = c['last_message']?.toString() ?? '';
                                  final hasImage = c['last_image'] != null;

                                  return InkWell(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            conversationId: c['id'],
                                            myId: widget.userData['id'],
                                            myType: 'customer',
                                            otherPartyName: c['shop_name']?.toString() ?? 'อู่ซ่อมรถ',
                                            otherPartyAvatar: c['garage_avatar']?.toString(),
                                          ),
                                        ),
                                      );
                                      _fetchConversations();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      child: Row(
                                        children: [
                                          // ✅ จุดฟ้าซ้ายสุดบอกว่ามีข้อความยังไม่ได้อ่าน (แบบ Messenger)
                                          SizedBox(
                                            width: 8,
                                            child: isUnread
                                                ? const Center(
                                                    child: CircleAvatar(radius: 4, backgroundColor: Color(0xff2196F3)))
                                                : null,
                                          ),
                                          const SizedBox(width: 6),
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: const Color(0xffE3F2FD),
                                            backgroundImage: c['garage_avatar'] != null
                                                ? NetworkImage(c['garage_avatar'].toString())
                                                : null,
                                            child: c['garage_avatar'] == null
                                                ? const Icon(Icons.store, color: Color(0xff2196F3), size: 26)
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(c['shop_name']?.toString() ?? 'อู่ซ่อมรถ',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                    )),
                                                const SizedBox(height: 2),
                                                Text(
                                                  lastMessage.isNotEmpty ? lastMessage : (hasImage ? '📷 รูปภาพ' : 'เริ่มการสนทนา'),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isUnread ? Colors.black87 : Colors.grey,
                                                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(_timeAgo(c['last_message_at']?.toString()),
                                                  style: TextStyle(
                                                    color: isUnread ? const Color(0xff2196F3) : Colors.grey,
                                                    fontSize: 12,
                                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                                  )),
                                              if (isUnread) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: const BoxDecoration(
                                                      color: Color(0xff2196F3), shape: BoxShape.circle),
                                                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                                                  child: Text('$unread',
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
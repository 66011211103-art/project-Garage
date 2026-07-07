import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'สวัสดีครับ\nรับคำขอซ่อมของคุณแล้วนะครับ',
      'isMe': false,
      'time': '10:30',
      'image': null,
    },
    {
      'text': 'ช่างจะออกไปถึงที่ประมาณ 30 นาทีครับ',
      'isMe': false,
      'time': '10:31',
      'image': null,
    },
    {
      'text': 'ได้เลยครับ รอที่นี่อยู่',
      'isMe': true,
      'time': '10:32',
      'image': null,
    },
    {
      'text': 'ขอถามว่าประมาณค่าซ่อมเท่าไหร่ครับ',
      'isMe': true,
      'time': '10:33',
      'image': null,
    },
    {
      'text': 'ต้องตรวจสอบก่อนนะครับ แต่ประมาณ 3,000-4,000 บาทครับ',
      'isMe': false,
      'time': '10:35',
      'image': null,
    },
    {
      'text': null,
      'isMe': false,
      'time': '10:36',
      'image': 'https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?w=400',
    },
    {
      'text': 'เข้าใจแล้วครับ ขอบคุณครับ',
      'isMe': true,
      'time': '10:37',
      'image': null,
    },
  ];

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': timeStr,
        'image': null,
      });
    });

    _controller.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),

      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.home_work, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'อู่ซ่อมรถบ้านสวน',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ออนไลน์',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),

      body: Column(
        children: [

          // ===== Messages List =====
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {

                // วันที่
                if (index == 0) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(child: Divider(indent: 20, endIndent: 10)),
                          Text('วันนี้', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          Expanded(child: Divider(indent: 10, endIndent: 20)),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index - 1];
                final isMe = msg['isMe'] as bool;
                final time = msg['time'] as String;
                final text = msg['text'] as String?;
                final image = msg['image'] as String?;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [

                      // Avatar ฝั่งอู่
                      if (!isMe) ...[
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xff2196F3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.home_work,
                              color: Colors.white, size: 20),
                        ),
                      ],

                      // Bubble
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (image != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  image,
                                  width: 220,
                                  height: 160,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xff2196F3)
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 16),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                                child: Text(
                                  text ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black87,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              time,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ===== Input Bar =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: Row(
              children: [

                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                  onPressed: () {},
                ),

                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'พิมพ์ข้อความ...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xffF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  icon: const Icon(Icons.image_outlined, color: Colors.grey),
                  onPressed: () {},
                ),

                const SizedBox(width: 4),

                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xff2196F3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
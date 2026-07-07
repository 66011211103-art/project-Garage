import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'profile_page.dart';
import 'chat_screen.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData; // ✅ รับ userData

  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeContent(userData: widget.userData), // ✅ ส่งไปที่ HomeContent
      const Center(child: Text("ประวัติ", style: TextStyle(fontSize: 24))),
      const ChatScreen(),
      ProfilePage(userData: widget.userData), // ✅ ส่งไปที่ ProfilePage
    ];

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "หน้าหลัก"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "ประวัติ"),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "แชท"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "โปรไฟล์"),
        ],
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomeContent({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    // ดึงชื่อจาก userData
    final firstName = userData['first_name'] ?? userData['shop_name'] ?? 'ผู้ใช้';

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [

            //================ Header ===================
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff2196F3), Color(0xff1976D2)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "สวัสดี",
                              style: TextStyle(color: Colors.white70, fontSize: 20),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              firstName, // ✅ ใช้ชื่อจริงจาก DB
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ไม่มีปุ่มแจ้งเตือน ✅
                    ],
                  ),

                  const SizedBox(height: 30),

                  TextField(
                    decoration: InputDecoration(
                      hintText: "ค้นหาอู่ซ่อมรถ...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            //================ Categories ==================
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "ประเภทงานซ่อม",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      CategoryItem(icon: FontAwesomeIcons.car, title: "เครื่องยนต์"),
                      CategoryItem(icon: FontAwesomeIcons.circle, title: "ยาง"),
                      CategoryItem(icon: FontAwesomeIcons.carBattery, title: "แบตเตอรี่"),
                      CategoryItem(icon: FontAwesomeIcons.sprayCanSparkles, title: "ซ่อมสี"),
                    ],
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff42A5F5), Color(0xff1E88E5)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.build, color: Colors.white, size: 35),
                        ),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "กำลังซ่อม",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26,
                                ),
                              ),
                              Text(
                                "อู่ซ่อมรถบ้านสวน\nเครื่องยนต์",
                                style: TextStyle(color: Colors.white, fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {},
                          child: const Row(
                            children: [
                              Text("ติดตาม"),
                              SizedBox(width: 5),
                              Icon(Icons.arrow_forward_ios, size: 15),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("อู่แนะนำ", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                      Text("ดูทั้งหมด", style: TextStyle(color: Colors.blue, fontSize: 20)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const GarageCard(
                    image: "https://images.unsplash.com/photo-1487754180451-c456f719a1fc?w=800",
                    title: "อู่ซ่อมรถบ้านสวน",
                    rating: "4.8",
                    reviews: "124",
                    distance: "2.5 กม.",
                  ),

                  const SizedBox(height: 20),

                  const GarageCard(
                    image: "https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?w=800",
                    title: "ศูนย์ซ่อมรถยนต์ชัยภูมิ",
                    rating: "4.6",
                    reviews: "89",
                    distance: "3.8 กม.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const CategoryItem({super.key, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        Text(title),
      ],
    );
  }
}

class GarageCard extends StatelessWidget {
  final String image;
  final String title;
  final String rating;
  final String reviews;
  final String distance;

  const GarageCard({
    super.key,
    required this.image,
    required this.title,
    required this.rating,
    required this.reviews,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(image, height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 5),
                Text("$rating ($reviews)", style: const TextStyle(fontSize: 18)),
                const Spacer(),
                const Icon(Icons.location_on, color: Colors.grey),
                Text(distance),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
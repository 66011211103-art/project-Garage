import 'package:flutter/material.dart';
import 'api_service.dart';

const List<String> kTechnicianSpecialtyOptions = [
  'เครื่องยนต์', 'ไฟฟ้า', 'เบรก', 'ช่วงล่าง', 'ตัวถัง', 'สี', 'แอร์', 'ยาง',
];

/// หน้าจัดการช่างในสังกัดอู่ — ดูรายชื่อ + เพิ่มช่างใหม่
class ManageTechniciansPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ManageTechniciansPage({super.key, required this.userData});

  @override
  State<ManageTechniciansPage> createState() => _ManageTechniciansPageState();
}

class _ManageTechniciansPageState extends State<ManageTechniciansPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _technicians = [];

  @override
  void initState() {
    super.initState();
    _fetchTechnicians();
  }

  Future<void> _fetchTechnicians() async {
    setState(() => _isLoading = true);
    final result = await ApiService.getTechnicians(garageId: widget.userData['id']);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _technicians = result.success && result.data != null
          ? List<Map<String, dynamic>>.from(result.data!['technicians'] ?? [])
          : [];
    });
  }

  Future<void> _toggleStatus(Map<String, dynamic> tech) async {
    final newStatus = tech['status'] == 'active' ? 'inactive' : 'active';
    final result = await ApiService.updateTechnicianStatus(
      technicianId: tech['id'],
      status: newStatus,
    );
    if (!mounted) return;
    if (result.success) {
      _fetchTechnicians();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openAddTechnician() async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AddTechnicianSheet(garageId: widget.userData['id']),
      ),
    );
    if (added == true) _fetchTechnicians();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: const Text('จัดการช่าง', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTechnician,
        backgroundColor: const Color(0xff2196F3),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('เพิ่มช่าง', style: TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTechnicians,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _technicians.isEmpty
                ? ListView(
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 100),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.engineering_outlined, size: 56, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('ยังไม่มีช่างในสังกัด', style: TextStyle(color: Colors.grey)),
                              SizedBox(height: 4),
                              Text('กดปุ่ม "เพิ่มช่าง" ด้านล่างเพื่อเริ่มต้น',
                                  style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _technicians.length,
                    itemBuilder: (context, index) => _technicianCard(_technicians[index]),
                  ),
      ),
    );
  }

  Widget _technicianCard(Map<String, dynamic> tech) {
    final isActive = tech['status'] == 'active';
    final specialties = (tech['specialties']?.toString() ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final activeJobs = tech['active_job_count'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xff2196F3),
                backgroundImage: (tech['avatar']?.toString().isNotEmpty ?? false)
                    ? NetworkImage(tech['avatar'])
                    : null,
                child: (tech['avatar']?.toString().isEmpty ?? true)
                    // ✅ กัน RangeError เวลา name เป็น "" (ว่างแต่ไม่ null) — .substring(0,1)
                    // บนสตริงว่างจะ throw ถ้าไม่เช็ค isNotEmpty ก่อน
                    ? Text(
                        ((tech['name']?.toString().isNotEmpty ?? false) ? tech['name'].toString() : '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tech['name']?.toString() ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(tech['phone']?.toString() ?? tech['email']?.toString() ?? '',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeColor: const Color(0xff4CAF50),
                onChanged: (_) => _toggleStatus(tech),
              ),
            ],
          ),
          if (specialties.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: specialties.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xffE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s.trim(), style: const TextStyle(fontSize: 11, color: Color(0xff2196F3))),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                activeJobs > 0 ? Icons.circle : Icons.circle,
                size: 8,
                color: activeJobs > 0 ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 6),
              Text(
                activeJobs > 0 ? 'ไม่ว่าง' : 'ว่าง',
                style: TextStyle(
                    fontSize: 12,
                    color: activeJobs > 0 ? Colors.orange : Colors.green,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Icon(Icons.work_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text('รับงานอยู่: $activeJobs งาน',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              if (!isActive) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                  child: const Text('ปิดใช้งาน',
                      style: TextStyle(fontSize: 11, color: Colors.red)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// ฟอร์มเพิ่มช่างใหม่ (bottom sheet เต็มหน้าจอ)
class _AddTechnicianSheet extends StatefulWidget {
  final int garageId;
  const _AddTechnicianSheet({required this.garageId});

  @override
  State<_AddTechnicianSheet> createState() => _AddTechnicianSheetState();
}

class _AddTechnicianSheetState extends State<_AddTechnicianSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final Set<String> _selectedSpecialties = {};
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อ อีเมล และรหัสผ่านให้ครบ'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ApiService.createTechnician(
      garageId: widget.garageId,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      specialties: _selectedSpecialties.join(','),
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
        title: const Text('เพิ่มช่างใหม่', style: TextStyle(color: Colors.white)),
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
            const Text('ชื่อช่าง', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _textField(_nameController, hint: 'เช่น สมชาย ช่างดี'),

            const SizedBox(height: 16),
            const Text('เบอร์โทร', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _textField(_phoneController, hint: '08xxxxxxxx', keyboardType: TextInputType.phone),

            const SizedBox(height: 16),
            const Text('อีเมล (ใช้ล็อกอิน)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _textField(_emailController, hint: 'technician@email.com', keyboardType: TextInputType.emailAddress),

            const SizedBox(height: 16),
            const Text('รหัสผ่าน (ใช้ล็อกอิน)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'อย่างน้อย 6 ตัวอักษร',
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text('ความถนัด (เลือกได้หลายอย่าง)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kTechnicianSpecialtyOptions.map((s) {
                final selected = _selectedSpecialties.contains(s);
                return ChoiceChip(
                  label: Text(s),
                  selected: selected,
                  selectedColor: const Color(0xffE3F2FD),
                  labelStyle: TextStyle(color: selected ? const Color(0xff2196F3) : Colors.black87),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedSpecialties.add(s);
                    } else {
                      _selectedSpecialties.remove(s);
                    }
                  }),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('เพิ่มช่าง', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, {required String hint, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
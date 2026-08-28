import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_locale.dart';

const List<String> kTechnicianSpecialtyOptions = [
  'เครื่องยนต์', 'ไฟฟ้า', 'เบรก', 'ช่วงล่าง', 'ตัวถัง', 'สี', 'แอร์', 'ยาง',
];

// ✅ kTechnicianSpecialtyOptions ยังคงเป็นภาษาไทยเสมอ (คือค่าจริงที่ join ด้วย ','
// แล้วส่งเก็บ/เทียบกับ _selectedSpecialties) — ฟังก์ชันนี้ใช้แค่แปลข้อความที่โชว์
// ให้ผู้ใช้เห็น (ไม่ว่าจะหน้าไหนก็ตาม)
String specialtyDisplayLabel(String specialty) {
  const map = {
    'เครื่องยนต์': 'cat_engine',
    'ไฟฟ้า': 'spec_electrical',
    'เบรก': 'svc_brakes',
    'ช่วงล่าง': 'svc_suspension',
    'ตัวถัง': 'svc_body',
    'สี': 'spec_paint',
    'แอร์': 'spec_ac',
    'ยาง': 'cat_tires',
  };
  final key = map[specialty];
  return key != null ? AppLocale.instance.t(key) : specialty;
}

// ✅ วาดกรอบเส้นประโค้งมน (Flutter ไม่มี built-in dashed border ให้ใช้ CustomPainter เอง
// แทนที่จะเพิ่ม dependency ใหม่ลง pubspec.yaml ซึ่งไม่สามารถ verify การ build ได้ในสภาพแวดล้อมนี้)
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  _DashedRectPainter({
    required this.color,
    this.radius = 16,
    this.dashWidth = 6,
    this.dashGap = 4,
    this.strokeWidth = 1.4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dashPath.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + dashGap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

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
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
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
    final loc = AppLocale.instance;
    final total = _technicians.length;
    final activeCount = _technicians.where((t) => t['status'] == 'active').length;
    final inactiveCount = total - activeCount;

    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('mtp_page_title'), style: const TextStyle(color: Colors.white)),
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
        label: Text(loc.t('mtp_add_tech_button'), style: const TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTechnicians,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _technicians.isEmpty
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 100),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: const BoxDecoration(
                                  color: Color(0xffE3F2FD),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.engineering_outlined,
                                    size: 42, color: Color(0xff2196F3)),
                              ),
                              const SizedBox(height: 18),
                              Text(loc.t('atp_no_techs_title'),
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(loc.t('mtp_empty_subtitle'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _openAddTechnician,
                                icon: const Icon(Icons.person_add, size: 18, color: Colors.white),
                                label: Text(loc.t('mtp_add_tech_button'),
                                    style: const TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff2196F3),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _technicians.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _statsHeader(loc, total, activeCount, inactiveCount),
                        );
                      }
                      return _technicianCard(_technicians[index - 1]);
                    },
                  ),
      ),
    );
  }

  Widget _statsHeader(AppLocale loc, int total, int activeCount, int inactiveCount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Expanded(child: _statTile(icon: Icons.groups_outlined, iconColor: const Color(0xff2196F3), value: '$total', label: loc.t('mtp_stat_total'))),
          _statDivider(),
          Expanded(child: _statTile(icon: Icons.check_circle_outline, iconColor: const Color(0xff4CAF50), value: '$activeCount', label: loc.t('mtp_stat_active'))),
          _statDivider(),
          Expanded(child: _statTile(icon: Icons.pause_circle_outline, iconColor: Colors.grey.shade500, value: '$inactiveCount', label: loc.t('mtp_disabled_badge'))),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 36, color: Colors.grey.shade200);

  Widget _statTile({required IconData icon, required Color iconColor, required String value, required String label}) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _technicianCard(Map<String, dynamic> tech) {
    final loc = AppLocale.instance;
    final isActive = tech['status'] == 'active';
    final specialties = (tech['specialties']?.toString() ?? '')
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final activeJobs = tech['active_job_count'] ?? 0;
    final isBusy = activeJobs > 0;
    final statusColor = !isActive
        ? Colors.grey.shade400
        : (isBusy ? const Color(0xffF59E0B) : const Color(0xff4CAF50));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(tech['name']?.toString() ?? '-',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                        ),
                        if (!isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
                            child: Text(loc.t('mtp_disabled_badge'),
                                style: const TextStyle(fontSize: 10.5, color: Colors.red, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.call_outlined, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(tech['phone']?.toString() ?? tech['email']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                        ),
                      ],
                    ),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: specialties.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xffE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(specialtyDisplayLabel(s.trim()),
                      style: const TextStyle(fontSize: 11.5, color: Color(0xff2196F3), fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        isBusy ? loc.t('atp_unavailable') : loc.t('atp_available'),
                        style: TextStyle(fontSize: 11.5, color: statusColor, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.work_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(loc.t('atp_active_jobs_prefix').replaceAll('%s', '$activeJobs'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
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
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSubmit() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.t('mtp_form_required')), backgroundColor: Colors.red),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.instance.t('mtp_password_min_length')), backgroundColor: Colors.red),
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
    final loc = AppLocale.instance;
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xff2196F3),
        title: Text(loc.t('mtp_add_new_title'), style: const TextStyle(color: Colors.white)),
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
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(color: Color(0xffE3F2FD), shape: BoxShape.circle),
                    child: const Icon(Icons.person_add_alt_1, size: 32, color: Color(0xff2196F3)),
                  ),
                  const SizedBox(height: 10),
                  Text(loc.t('mtp_add_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(loc.t('mtp_name_label'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _textField(_nameController, hint: loc.t('mtp_name_hint'), icon: Icons.person_outline),

            const SizedBox(height: 16),
            Text(loc.t('mtp_phone_label'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _textField(_phoneController,
                hint: '08xxxxxxxx', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),

            const SizedBox(height: 16),
            Text(loc.t('mtp_email_label'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _textField(_emailController,
                hint: 'technician@email.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),

            const SizedBox(height: 16),
            Text(loc.t('mtp_password_label'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: loc.t('mtp_password_hint'),
                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade500),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey.shade500),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text(loc.t('mtp_specialty_label'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kTechnicianSpecialtyOptions.map((s) {
                final selected = _selectedSpecialties.contains(s);
                return ChoiceChip(
                  label: Text(specialtyDisplayLabel(s)),
                  selected: selected,
                  showCheckmark: false,
                  shape: StadiumBorder(
                      side: BorderSide(color: selected ? const Color(0xff2196F3) : Colors.grey.shade300)),
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xffE3F2FD),
                  labelStyle: TextStyle(
                      color: selected ? const Color(0xff2196F3) : Colors.black87,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
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
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                icon: _isSubmitting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                label: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(loc.t('mtp_add_tech_button'),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller,
      {required String hint, IconData? icon, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade500) : null,
        filled: true,
        fillColor: const Color(0xFFF5F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
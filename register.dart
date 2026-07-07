import 'package:flutter/material.dart';
import 'api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // ลูกค้า
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // อู่ซ่อม
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();

  // ใช้ร่วมกัน
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String selectedUserType = 'customer';
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.register(
      firstName: selectedUserType == 'customer'
          ? _firstNameController.text.trim()
          : _shopNameController.text.trim(),
      lastName: selectedUserType == 'customer'
          ? _lastNameController.text.trim()
          : _ownerNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      userType: selectedUserType,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );

    if (result.success) Navigator.pop(context);
  }

  InputDecoration customInput({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF5F6FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget userTypeCard({
    required String value,
    required IconData icon,
    required String label,
  }) {
    bool selected = selectedUserType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedUserType = value),
        child: Container(
          height: 110,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.withOpacity(.08) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.blue : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: selected ? Colors.blue : Colors.grey),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.blue : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRepair = selectedUserType == 'repair';

    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF5FF),
        elevation: 0,
        title: Text(
          isRepair ? 'สมัครสมาชิกอู่ซ่อมรถ' : 'สมัครสมาชิกลูกค้า',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const SizedBox(height: 10),

                // ===== เลือกประเภทก่อน =====
                const Text('ประเภทผู้ใช้', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    userTypeCard(
                      value: 'customer',
                      icon: Icons.person_outline,
                      label: 'ลูกค้า',
                    ),
                    userTypeCard(
                      value: 'repair',
                      icon: Icons.home_repair_service_outlined,
                      label: 'อู่ซ่อม',
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ===== ฟอร์มลูกค้า =====
                if (!isRepair) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ชื่อ'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _firstNameController,
                              decoration: customInput(hint: 'ชื่อ', icon: Icons.person_outline),
                              validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('นามสกุล'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: customInput(hint: 'นามสกุล', icon: Icons.person_outline),
                              validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกนามสกุล' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                // ===== ฟอร์มอู่ซ่อม =====
                if (isRepair) ...[
                  const Text('ชื่อร้านอู่ซ่อมรถ'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _shopNameController,
                    decoration: customInput(hint: 'ชื่ออู่ซ่อมรถ', icon: Icons.store_outlined),
                    validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อร้าน' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('ชื่อเจ้าของอู่'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: customInput(hint: 'ชื่อ-นามสกุล', icon: Icons.person_outline),
                    validator: (v) => v == null || v.trim().isEmpty ? 'กรุณากรอกชื่อเจ้าของ' : null,
                  ),
                ],

                // ===== ใช้ร่วมกัน =====
                const SizedBox(height: 16),
                const Text('เบอร์โทรศัพท์'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: customInput(hint: '0xx-xxx-xxxx', icon: Icons.phone_outlined),
                ),

                const SizedBox(height: 16),
                const Text('อีเมล'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: customInput(hint: 'example@email.com', icon: Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'กรุณากรอกอีเมล';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
                      return 'รูปแบบอีเมลไม่ถูกต้อง';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                const Text('รหัสผ่าน'),
                const SizedBox(height: 8),
                TextFormField(
                  obscureText: true,
                  controller: _passwordController,
                  decoration: customInput(hint: '••••••••', icon: Icons.lock_outline),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                    if (v.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                const Text('ยืนยันรหัสผ่าน'),
                const SizedBox(height: 8),
                TextFormField(
                  obscureText: true,
                  controller: _confirmPasswordController,
                  decoration: customInput(hint: '••••••••', icon: Icons.lock_outline),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
                    if (v != _passwordController.text) return 'รหัสผ่านไม่ตรงกัน';
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'สมัครสมาชิก',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('มีบัญชีอยู่แล้ว? '),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'เข้าสู่ระบบ',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
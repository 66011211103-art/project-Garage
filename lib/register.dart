import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_locale.dart'; // ✅ ระบบสลับภาษาไทย/อังกฤษ

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
  bool _obscurePassword = true; // ✅ ควบคุมการซ่อน/แสดงรหัสผ่าน
  bool _obscureConfirmPassword = true; // ✅ ควบคุมการซ่อน/แสดงยืนยันรหัสผ่าน

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
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
    final loc = AppLocale.instance;
    final isRepair = selectedUserType == 'repair';

    return Scaffold(
      backgroundColor: const Color(0xFFEAF5FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF5FF),
        elevation: 0,
        title: Text(
          isRepair ? loc.t('reg_title_repair') : loc.t('reg_title_customer'),
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
                Text(loc.t('reg_user_type_label'), style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    userTypeCard(
                      value: 'customer',
                      icon: Icons.person_outline,
                      label: loc.t('profile_type_customer'),
                    ),
                    userTypeCard(
                      value: 'repair',
                      icon: Icons.home_repair_service_outlined,
                      label: loc.t('reg_type_repair'),
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
                            Text(loc.t('reg_first_name_label')),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _firstNameController,
                              decoration: customInput(hint: loc.t('reg_first_name_label'), icon: Icons.person_outline),
                              validator: (v) => v == null || v.trim().isEmpty ? loc.t('reg_first_name_required') : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.t('reg_last_name_label')),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: customInput(hint: loc.t('reg_last_name_label'), icon: Icons.person_outline),
                              validator: (v) => v == null || v.trim().isEmpty ? loc.t('reg_last_name_required') : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                // ===== ฟอร์มอู่ซ่อม =====
                if (isRepair) ...[
                  Text(loc.t('reg_shop_name_label')),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _shopNameController,
                    decoration: customInput(hint: loc.t('reg_shop_name_hint'), icon: Icons.store_outlined),
                    validator: (v) => v == null || v.trim().isEmpty ? loc.t('reg_shop_name_required') : null,
                  ),
                  const SizedBox(height: 16),
                  Text(loc.t('reg_owner_name_label')),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: customInput(hint: loc.t('reg_owner_name_hint'), icon: Icons.person_outline),
                    validator: (v) => v == null || v.trim().isEmpty ? loc.t('reg_owner_name_required') : null,
                  ),
                ],

                // ===== ใช้ร่วมกัน =====
                const SizedBox(height: 16),
                Text(loc.t('reg_phone_label')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: customInput(hint: '0xx-xxx-xxxx', icon: Icons.phone_outlined),
                  // ✅ เดิมไม่มี validator เลย ทำให้ฟอร์มผ่านและสมัครได้ทั้งที่เบอร์โทรว่าง
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return loc.t('reg_phone_required');
                    if (!RegExp(r'^[0-9]{9,10}$').hasMatch(v.trim().replaceAll('-', ''))) {
                      return loc.t('reg_phone_invalid');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                Text(loc.t('auth_email_label')),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: customInput(hint: 'example@email.com', icon: Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return loc.t('auth_email_required');
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim())) {
                      return loc.t('reg_email_format_invalid');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                Text(loc.t('auth_password_label')),
                const SizedBox(height: 8),
                TextFormField(
                  obscureText: _obscurePassword,
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return loc.t('auth_password_required');
                    if (v.length < 6) return loc.t('reset_pw_min_length');
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                Text(loc.t('reg_confirm_password_label')),
                const SizedBox(height: 8),
                TextFormField(
                  obscureText: _obscureConfirmPassword,
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return loc.t('reg_confirm_password_required');
                    if (v != _passwordController.text) return loc.t('reset_pw_mismatch');
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
                        : Text(
                            loc.t('auth_signup'),
                            style: const TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(loc.t('reg_have_account')),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          loc.t('auth_login_title'),
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
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
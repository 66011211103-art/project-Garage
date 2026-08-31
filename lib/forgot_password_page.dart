import 'package:flutter/material.dart';
import 'api_service.dart';
import 'reset_password_page.dart';
import 'app_locale.dart'; // ✅ ระบบสลับภาษาไทย/อังกฤษ

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(); // ✅ ใหม่ — รองรับขอ OTP ทางเบอร์โทร
  bool _isPhone = false; // ✅ ใหม่ — false = ส่งทางอีเมล, true = ส่งทาง SMS
  bool _isLoading = false;

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
    _emailController.dispose();
    _phoneController.dispose(); // ✅ ใหม่
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // ✅ ใหม่ — เลือกช่องทางตาม _isPhone แทนที่จะใช้อีเมลตายตัวเหมือนเดิม
    final identifier = _isPhone
        ? _phoneController.text.trim()
        : _emailController.text.trim();

    final result = _isPhone
        ? await ApiService.forgotPassword(phone: identifier)
        : await ApiService.forgotPassword(email: identifier);

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (result.success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ResetPasswordPage(identifier: identifier, isPhone: _isPhone),
        ),
      );
    }
  }

  // ✅ ใหม่ — การ์ดปุ่มสลับช่องทาง (อีเมล/เบอร์โทร) แบบ pill ให้เข้าชุดกับดีไซน์เดิม
  Widget _buildChannelTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffE3F2FD) : const Color(0xffF5F6FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xff2196F3) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? const Color(0xff2196F3) : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: selected ? const Color(0xff2196F3) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F7),
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(loc.t('forgot_pw_title')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.lock_reset, size: 70, color: Colors.blue),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  loc.t('forgot_pw_instructions'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ ใหม่ — สลับช่องทางรับ OTP ระหว่างอีเมล/เบอร์โทร
                      Row(
                        children: [
                          Expanded(
                            child: _buildChannelTab(
                              label: loc.t('forgot_pw_channel_email'),
                              icon: Icons.email_outlined,
                              selected: !_isPhone,
                              onTap: () => setState(() => _isPhone = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildChannelTab(
                              label: loc.t('forgot_pw_channel_phone'),
                              icon: Icons.phone_outlined,
                              selected: _isPhone,
                              onTap: () => setState(() => _isPhone = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(_isPhone ? loc.t('auth_phone_label') : loc.t('auth_email_label')),
                      const SizedBox(height: 8),
                      if (!_isPhone)
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'example@email.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: const Color(0xFFF5F6FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return loc.t('auth_email_required');
                            }
                            if (!value.contains('@')) {
                              return loc.t('auth_email_invalid');
                            }
                            return null;
                          },
                        )
                      else
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: '0812345678',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            filled: true,
                            fillColor: const Color(0xFFF5F6FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return loc.t('auth_phone_required');
                            }
                            final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
                            if (digits.length < 9 || digits.length > 10) {
                              return loc.t('auth_phone_invalid');
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  loc.t('forgot_pw_send_otp'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

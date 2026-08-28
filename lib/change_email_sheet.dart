import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_locale.dart'; // ✅ ระบบสลับภาษาไทย/อังกฤษ

/// เปิด bottom sheet ให้เปลี่ยนอีเมล ยืนยันตัวตนด้วย OTP ที่ส่งไปอีเมลใหม่
/// คืนค่าอีเมลใหม่ (String) เมื่อเปลี่ยนสำเร็จ หรือ null ถ้าปิดโดยไม่สำเร็จ
Future<String?> showChangeEmailSheet(
  BuildContext context, {
  required int userId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ChangeEmailSheet(userId: userId),
  );
}

class _ChangeEmailSheet extends StatefulWidget {
  final int userId;
  const _ChangeEmailSheet({required this.userId});

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  // step 1 = กรอกอีเมลใหม่, step 2 = กรอก OTP ยืนยัน
  int _step = 1;
  bool _isLoading = false;
  String? _errorText;

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
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = AppLocale.instance.t('change_email_invalid'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final result = await ApiService.requestEmailChange(
      userId: widget.userId,
      newEmail: email,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() => _step = 2);
    } else {
      setState(() => _errorText = result.message);
    }
  }

  Future<void> _handleConfirmOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _errorText = AppLocale.instance.t('change_email_otp_required'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final result = await ApiService.confirmEmailChange(
      userId: widget.userId,
      otp: otp,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pop(context, _emailController.text.trim());
    } else {
      setState(() => _errorText = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: Color(0xff2196F3)),
                const SizedBox(width: 8),
                Text(
                  _step == 1 ? loc.t('change_email') : loc.t('change_email_step2_title'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (_step == 1) ...[
              Text(
                loc.t('change_email_step1_instructions'),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: loc.t('change_email_hint'),
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(loc.t('forgot_pw_send_otp'),
                          style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ] else ...[
              Text(
                loc.t('change_email_otp_sent_to').replaceAll('%s', _emailController.text.trim()),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                autofocus: true,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _step = 1;
                            _errorText = null;
                            _otpController.clear();
                          });
                        },
                  child: Text(loc.t('change_email_resend')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleConfirmOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2196F3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(loc.t('change_email_confirm'),
                          style: const TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

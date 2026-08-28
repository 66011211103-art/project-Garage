import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.dart';
import 'garage_dashboard.dart';
import 'technician_dashboard.dart'; // ✅ หน้าหลักฝั่งช่าง
import 'register.dart';
import 'api_service.dart';
import 'forgot_password_page.dart';
import 'app_locale.dart'; // ✅ ระบบสลับภาษา ไทย/อังกฤษ

/// ✅ เพิ่มใหม่: เก็บ/โหลด/ล้าง session ผู้ใช้ที่ล็อกอินไว้ ให้แอปจำสถานะล็อกอินข้ามการ
/// เปิดปิดแอปได้จริง — เดิมแอปไม่เคยบันทึก session เลย (home: const LoginPage() ตายตัว)
/// ทำให้ทุกครั้งที่ระบบปฏิบัติการ (โดยเฉพาะ Android) เคลียร์แอปออกจากหน่วยความจำ
/// เบื้องหลัง (เกิดขึ้นบ่อยมากบนมือถือทั่วไป แค่สลับไปแอปอื่นหรือปิดหน้าจอทิ้งไว้สักพัก)
/// พอกลับมาเปิดแอปใหม่ก็จะเจอหน้า login เปล่าๆ ทุกครั้ง ทั้งที่ผู้ใช้ไม่เคยกด logout เลย
/// ผู้ใช้จึงรู้สึกว่า "แอปเด้ง/หลุดล็อกอินเอง" ทั้งที่จริงคือแอปไม่เคยจำ session ไว้ตั้งแต่แรก
class SessionStore {
  static const _key = 'session_user';

  static Future<void> save(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user));
    // ignore: avoid_print
    print('[SessionStore] saved session for userType=${user['userType']} id=${user['id']}');
  }

  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    // ignore: avoid_print
    print('[SessionStore] load(): raw=${raw == null ? 'null' : '(${raw.length} chars)'}');
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      // ignore: avoid_print
      print('[SessionStore] load(): parsed userType=${parsed['userType']} id=${parsed['id']}');
      return parsed;
    } catch (e) {
      // ignore: avoid_print
      print('[SessionStore] load(): FAILED TO PARSE: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    // ignore: avoid_print
    print('[SessionStore] cleared session');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ โหลดภาษาที่ผู้ใช้เคยเลือกไว้ก่อนเริ่ม runApp เสมอ ไม่งั้นต้องรอเข้าหน้าตั้งค่าก่อนถึงจะโหลด
  await AppLocale.instance.load();

  // ✅ เพิ่มใหม่: เช็ค session ที่เคยล็อกอินไว้ก่อนตัดสินใจว่าจะเปิดหน้าไหน (ดู SessionStore ด้านบน)
  final savedUser = await SessionStore.load();

  // ✅ กันไม่ให้แอปโชว์ "หน้าจอแดง" (Flutter error screen) เวลามี widget พัง
  //     ไม่ว่าจะเกิดที่หน้าไหนก็ตาม — โชว์การ์ดข้อความสุภาพแทน
  //     ผู้ใช้จะไม่เห็นหน้าจอแดงเต็มจออีกต่อไป (ต้อง full restart ไม่ใช่
  //     hot reload ถึงจะ apply โค้ดตรงนี้)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xffF5F5F5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.grey.shade400, size: 48),
              const SizedBox(height: 12),
              Text(
                AppLocale.instance.t('error_generic'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runApp(MyApp(savedUser: savedUser));
}

class MyApp extends StatelessWidget {
  final Map<String, dynamic>? savedUser;

  const MyApp({super.key, this.savedUser});

  // ✅ เพิ่มใหม่: เลือกหน้าแรกจาก session ที่บันทึกไว้ ให้ตรงกับ userType เดิม
  // (ไม่มี session บันทึกไว้ -> ไปหน้า login ตามปกติ)
  Widget _resolveHome() {
    final user = savedUser;
    if (user == null) return const LoginPage();
    final userType = user['userType'] ?? 'customer';
    if (userType == 'repair') {
      return GarageDashboard(userData: user);
    } else if (userType == 'technician') {
      return TechnicianDashboard(userData: user);
    }
    return HomePage(userData: user);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ ฟัง AppLocale ที่ราก MaterialApp เลย เวลากดเปลี่ยนภาษาจากหน้าตั้งค่า
    // ทั้งต้นคือจะรีบิลด์ ขึ้นใหม่ทั้งต้นทีมทันที (ไม่ต้องรอหน้านั้นๆ ผูกตัวเอง)
    // หน้าไหนจะเห็นภาษาเปลี่ยนจริง ขึ้นอยู่กับว่าหน้านั้นใช้ AppLocale.instance.t() หรือยัง
    return AnimatedBuilder(
      animation: AppLocale.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: _resolveHome(),
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const int _maxSavedAccounts = 5;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  // ✅ ควบคุม dropdown เอง แบบ inline ธรรมดา ไม่ใช้ Overlay/Autocomplete
  // ✅ แก้ไข: เอา dropdown บัญชีที่จดจำไว้ออกจากช่องรหัสผ่าน ให้เหลือแสดงใต้ช่องอีเมล
  // ที่เดียวตามที่ขอ (เดิมแตะช่องไหนก็ขึ้น dropdown ได้ทั้งคู่ ดูซ้ำซ้อน)
  bool _showEmailSuggestions = false;

  // ✅ รายการบัญชีที่เคยบันทึกไว้ (สูงสุด 5 บัญชีล่าสุด)
  List<Map<String, String>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
    // ✅ รีบิลด์หน้าล็อกอินอัตโนมัติเมื่อผู้ใช้เปลี่ยนภาษาจากหน้าตั้งค่า (เผื่อย้อนกลับมาหน้านี้)
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_accounts');

    if (raw != null && raw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(raw);
      final accounts = decoded
          .map((e) => Map<String, String>.from(e as Map))
          .toList();

      setState(() {
        _savedAccounts = accounts;
        if (accounts.isNotEmpty) {
          _emailController.text = accounts.first['email'] ?? '';
          _passwordController.text = accounts.first['password'] ?? '';
          _rememberMe = true;
        }
      });
    }
  }

  Future<void> _updateSavedAccounts() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final updated = List<Map<String, String>>.from(_savedAccounts);
    updated.removeWhere((a) => a['email'] == email);

    if (_rememberMe) {
      updated.insert(0, {'email': email, 'password': password});
      if (updated.length > _maxSavedAccounts) {
        updated.removeRange(_maxSavedAccounts, updated.length);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_accounts', jsonEncode(updated));

    setState(() => _savedAccounts = updated);
  }

  // ✅ ลบบัญชีออกจากรายการ dropdown (ตอนนี้เป็น widget ปกติ ไม่ใช่ Overlay แล้ว รับประกันกดได้)
  Future<void> _removeSavedAccount(String email) async {
    final updated = List<Map<String, String>>.from(_savedAccounts)
      ..removeWhere((a) => a['email'] == email);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_accounts', jsonEncode(updated));

    setState(() => _savedAccounts = updated);
  }

  void _toggleRememberMe(bool value) {
    setState(() {
      _rememberMe = value;
      if (!value) {
        _passwordController.clear();
      }
    });
  }

  void _selectAccount(String email) {
    final account = _savedAccounts.firstWhere(
      (a) => a['email'] == email,
      orElse: () => {},
    );
    setState(() {
      _emailController.text = email;
      _passwordController.text = account['password'] ?? '';
      _rememberMe = true;
      _showEmailSuggestions = false;
    });
  }

  void _closeSuggestions() {
    if (_showEmailSuggestions) {
      setState(() => _showEmailSuggestions = false);
    }
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await ApiService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      await _updateSavedAccounts();
      // ✅ เพิ่มใหม่: บันทึก session ไว้ ให้เปิดแอปครั้งต่อไปไม่ต้องล็อกอินซ้ำ (ดู SessionStore ด้านบน)
      await SessionStore.save(result.data!['user']);

      final userType = result.data?['user']?['userType'] ?? 'customer';

      if (!mounted) return;

      if (userType == 'repair') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                GarageDashboard(userData: result.data!['user']),
          ),
        );
      } else if (userType == 'technician') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TechnicianDashboard(userData: result.data!['user']),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(userData: result.data!['user']),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ✅ เพิ่มใหม่: กล่องกรอกที่เห็นขอบชัดเจน + คอนทราสต์สูงขึ้น ใช้ร่วมกันทั้งช่อง
  // อีเมล/รหัสผ่าน แก้ปัญหาเดิมที่พื้นหลังจางเกินไปจนแยกจากพื้นขาวรอบๆ ไม่ออก
  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500),
      prefixIcon: Icon(icon, color: Colors.blueGrey.shade400),
      suffixIcon: suffixIcon,
      filled: true,
      // ✅ พื้นหลังเข้มขึ้นเล็กน้อยจากเดิม (0xFFF5F6FA) ให้แยกจากพื้นขาวรอบๆ ชัดขึ้น
      fillColor: const Color(0xFFEDF0F5),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      // ✅ เพิ่มเส้นขอบที่มองเห็นได้ตลอดเวลา (เดิมไม่มีเส้นขอบเลย)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade400, width: 1.2),
      ),
      // ✅ ขอบหนา+สีฟ้าเด่นชัดตอนกำลังกรอกอยู่ ให้รู้ทันทีว่าโฟกัสช่องไหนอยู่
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff2196F3), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  // ✅ dropdown ตัวเดียว ใช้ร่วมกันทั้งช่องอีเมล/รหัสผ่าน เป็น widget ปกติในหน้าจอ
  Widget _buildAccountsDropdown(List<Map<String, String>> accounts) {
    if (accounts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.white,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final email = accounts[index]['email'] ?? '';
              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.account_circle,
                  size: 22,
                  color: Colors.blue,
                ),
                title: Text(email, style: const TextStyle(fontSize: 14)),
                subtitle: const Text('••••••••', style: TextStyle(fontSize: 12)),
                trailing: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _removeSavedAccount(
                    email,
                  ), // ✅ widget ปกติ ไม่มี Overlay แย่งโฟกัส กดลบได้แน่นอน
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ),
                onTap: () => _selectAccount(email),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocale.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        // ✅ แตะที่อื่นในหน้าจอ -> ปิด dropdown
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _closeSuggestions,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),

                Column(
                  children: [
                    const Image(
                      image: AssetImage('images/logo.png'),
                      width: 220,
                      height: 212,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loc.t('auth_app_name'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.t('auth_tagline'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
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
                        Center(
                          child: Text(
                            loc.t('auth_login_title'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(loc.t('auth_email_label')),
                        const SizedBox(height: 8),

                        // ✅ กันไม่ให้แตะในช่องอีเมล/รหัสผ่านไปโดน GestureDetector ปิด dropdown ของตัวเอง
                        GestureDetector(
                          onTap:
                              () {}, // กันการไหลของ tap ไปโดน parent ปิด dropdown ตัวเอง
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                onTap: () {
                                  setState(() {
                                    _showEmailSuggestions =
                                        _savedAccounts.isNotEmpty;
                                  });
                                },
                                onChanged: (_) => setState(() {}),
                                decoration: _fieldDecoration(
                                  hint: 'example@email.com',
                                  icon: Icons.email_outlined,
                                  suffixIcon: _savedAccounts.isNotEmpty
                                      ? Icon(
                                          Icons.arrow_drop_down,
                                          color: Colors.blueGrey.shade400,
                                        )
                                      : null,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return loc.t('auth_email_required');
                                  }
                                  return null;
                                },
                              ),
                              if (_showEmailSuggestions)
                                _buildAccountsDropdown(
                                  _savedAccounts
                                      .where(
                                        (a) => (a['email'] ?? '')
                                            .toLowerCase()
                                            .contains(
                                              _emailController.text
                                                  .toLowerCase(),
                                            ),
                                      )
                                      .toList(),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(loc.t('auth_password_label')),
                        const SizedBox(height: 8),

                        GestureDetector(
                          onTap: () {},
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                                onFieldSubmitted: (_) => _handleLogin(),
                                onTap: () {
                                  if (_showEmailSuggestions) {
                                    setState(() => _showEmailSuggestions = false);
                                  }
                                },
                                decoration: _fieldDecoration(
                                  hint: '••••••••',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: const Color.fromARGB(
                                        255,
                                        144,
                                        168,
                                        180,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return loc.t('auth_password_required');
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => _toggleRememberMe(!_rememberMe),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: Colors.blue,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (value) =>
                                          _toggleRememberMe(value ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    loc.t('auth_remember_me'),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: Text(
                                loc.t('auth_forgot_password'),
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
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
                                    loc.t('auth_login_title'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(loc.t('auth_or_divider')),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(loc.t('auth_no_account')),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: Text(
                                loc.t('auth_signup'),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard.dart';
import 'garage_dashboard.dart';
import 'register.dart';
import 'api_service.dart';
import 'forgot_password_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
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
  bool _showEmailSuggestions = false;
  bool _showPasswordSuggestions = false;

  // ✅ รายการบัญชีที่เคยบันทึกไว้ (สูงสุด 5 บัญชีล่าสุด)
  List<Map<String, String>> _savedAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
  }

  Future<void> _loadSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_accounts');

    if (raw != null && raw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(raw);
      final accounts = decoded.map((e) => Map<String, String>.from(e as Map)).toList();

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
      _showPasswordSuggestions = false;
    });
  }

  void _closeSuggestions() {
    if (_showEmailSuggestions || _showPasswordSuggestions) {
      setState(() {
        _showEmailSuggestions = false;
        _showPasswordSuggestions = false;
      });
    }
  }

  @override
  void dispose() {
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

      final userType = result.data?['user']?['userType'] ?? 'customer';

      if (!mounted) return;

      if (userType == 'repair') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GarageDashboard(userData: result.data!['user']),
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

  // ✅ dropdown ตัวเดียว ใช้ร่วมกันทั้งช่องอีเมล/รหัสผ่าน เป็น widget ปกติในหน้าจอ
  Widget _buildAccountsDropdown(List<Map<String, String>> accounts) {
    if (accounts.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final email = accounts[index]['email'] ?? '';
          return ListTile(
            dense: true,
            leading: const Icon(Icons.account_circle, size: 22, color: Colors.blue),
            title: Text(email, style: const TextStyle(fontSize: 14)),
            subtitle: const Text('••••••••', style: TextStyle(fontSize: 12)),
            trailing: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _removeSavedAccount(email), // ✅ widget ปกติ ไม่มี Overlay แย่งโฟกัส กดลบได้แน่นอน
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, size: 18, color: Colors.grey),
              ),
            ),
            onTap: () => _selectAccount(email),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  children: const [
                    Image(
                      image: AssetImage('images/logo-2.png'),
                      width: 220,
                      height: 212,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'อู่ที่ไว้วางใจ',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 25 , fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'ค้นหาอู่ซ่อมรถใกล้คุณ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
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
                        color: Colors.black.withOpacity(0.05),
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
                        const Center(
                          child: Text(
                            'เข้าสู่ระบบ',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text('อีเมล'),
                        const SizedBox(height: 8),

                        // ✅ กันไม่ให้แตะในช่องอีเมล/รหัสผ่านไปโดน GestureDetector ปิด dropdown ของตัวเอง
                        GestureDetector(
                          onTap: () {}, // กันการไหลของ tap ไปโดน parent ปิด dropdown ตัวเอง
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                onTap: () {
                                  setState(() {
                                    _showPasswordSuggestions = false;
                                    _showEmailSuggestions = _savedAccounts.isNotEmpty;
                                  });
                                },
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'example@email.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  suffixIcon: _savedAccounts.isNotEmpty
                                      ? const Icon(Icons.arrow_drop_down, color: Colors.grey)
                                      : null,
                                  filled: true,
                                  fillColor: const Color(0xFFF5F6FA),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'กรุณากรอกอีเมล';
                                  }
                                  return null;
                                },
                              ),
                              if (_showEmailSuggestions)
                                _buildAccountsDropdown(
                                  _savedAccounts
                                      .where((a) => (a['email'] ?? '')
                                          .toLowerCase()
                                          .contains(_emailController.text.toLowerCase()))
                                      .toList(),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Text('รหัสผ่าน'),
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
                                onFieldSubmitted: (_) => _handleLogin(),
                                onTap: () {
                                  setState(() {
                                    _showEmailSuggestions = false;
                                    _showPasswordSuggestions = _savedAccounts.isNotEmpty;
                                  });
                                },
                                decoration: InputDecoration(
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
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'กรุณากรอกรหัสผ่าน';
                                  }
                                  return null;
                                },
                              ),
                              if (_showPasswordSuggestions) _buildAccountsDropdown(_savedAccounts),
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
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (value) => _toggleRememberMe(value ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('จดจำฉัน', style: TextStyle(color: Colors.black87, fontSize: 14)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                                );
                              },
                              child: const Text('ลืมรหัสผ่าน?', style: TextStyle(color: Colors.blue)),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: const [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('หรือ'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('ยังไม่มีบัญชี? '),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                                );
                              },
                              child: const Text(
                                'สมัครสมาชิก',
                                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
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
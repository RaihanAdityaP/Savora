import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/supabase_client.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _signUp() async {
    // Validasi input
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _fullNameController.text.isEmpty) {
      _showSnackBar('Semua field harus diisi!');
      return;
    }

    // Validasi email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _showSnackBar('Format email tidak valid!');
      return;
    }

    // Validasi password minimal 6 karakter
    if (_passwordController.text.length < 6) {
      _showSnackBar('Password minimal 6 karakter!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Sign up dengan timeout
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'username': _usernameController.text.trim(),
          'full_name': _fullNameController.text.trim(),
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Registration timeout. Silakan coba lagi.'),
      );

      if (!mounted) return;

      if (response.user != null) {
        // Tunggu sebentar untuk memastikan trigger selesai
        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;

        // Verifikasi profile sudah dibuat
        try {
          final profileCheck = await supabase
              .from('profiles')
              .select('id')
              .eq('id', response.user!.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 5));

          if (!mounted) return;

          if (profileCheck == null) {
            // Profile belum dibuat, coba buat manual
            await supabase.from('profiles').insert({
              'id': response.user!.id,
              'username': _usernameController.text.trim(),
              'full_name': _fullNameController.text.trim(),
              'role': 'user',
            }).timeout(const Duration(seconds: 5));
          }
        } catch (profileError) {
          debugPrint('Profile creation check error: $profileError');
          // Continue anyway, profile might be created by trigger
        }

        if (!mounted) return;

        _showSnackBar(
          'Registrasi berhasil! Silakan cek email untuk verifikasi.',
          backgroundColor: Colors.green,
        );

        // Sign out untuk memaksa user login setelah verifikasi
        await supabase.auth.signOut();

        if (!mounted) return;

        // Navigate ke login screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        throw Exception('User tidak ditemukan setelah registrasi');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      
      String message = 'Error: ${e.message}';

      // Custom error messages
      if (e.message.contains('User already registered')) {
        message = 'Email sudah terdaftar. Silakan gunakan email lain atau login.';
      } else if (e.message.contains('Password should be at least')) {
        message = 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      } else if (e.message.contains('Unable to validate email')) {
        message = 'Format email tidak valid.';
      } else if (e.message.contains('Email rate limit exceeded')) {
        message = 'Terlalu banyak percobaan. Tunggu beberapa menit.';
      }

      _showSnackBar(message);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      
      String message = 'Error database: ${e.message}';
      
      if (e.message.contains('duplicate key')) {
        message = 'Username atau email sudah digunakan.';
      }

      _showSnackBar(message);
    } catch (e) {
      if (!mounted) return;
      
      String errorMsg = e.toString();
      if (errorMsg.contains('timeout')) {
        errorMsg = 'Koneksi timeout. Periksa internet Anda dan coba lagi.';
      } else if (errorMsg.contains('Database error')) {
        errorMsg = 'Terjadi kesalahan sistem. Silakan coba lagi dalam beberapa saat.';
      } else {
        errorMsg = 'Terjadi kesalahan: $e';
      }

      _showSnackBar(errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5BFA5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Logo Savora
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 18,
                          child: Icon(
                            Icons.restaurant,
                            size: 40,
                            color: const Color(0xFFFF6B35),
                          ),
                        ),
                        Positioned(
                          right: 18,
                          child: Transform.rotate(
                            angle: 0.2,
                            child: Icon(
                              Icons.restaurant,
                              size: 40,
                              color: const Color(0xFF8BC34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Savora',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C4033),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Daftar Akun',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 35),

                // Full Name TextField
                Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: TextField(
                    controller: _fullNameController,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Nama Lengkap',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.95),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6B35),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Username TextField
                Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: TextField(
                    controller: _usernameController,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Username',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.95),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6B35),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Email TextField
                Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.95),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6B35),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password TextField
                Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Password (min. 6 karakter)',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.95),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF6B35),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey.shade600,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Register Button
                Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.95),
                      foregroundColor: const Color(0xFF5C4033),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                      elevation: 2,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: const Color(0xFF5C4033),
                            ),
                          )
                        : const Text(
                            'DAFTAR',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
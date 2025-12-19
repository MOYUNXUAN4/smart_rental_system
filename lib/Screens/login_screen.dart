import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Compoents/animated_bottom_nav.dart';
import '../Services/account_check_screen.dart';
import 'forgot_password_screen.dart'; // 🔥 确保导入了找回密码页面
import 'home_screen.dart';
// ✅ 导入相关屏幕
import 'register_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedType = "Tenant"; 
  bool _isLoading = false;
  int _currentNavIndex = 3; 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 登录逻辑
  Future<void> _login() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        // 登录成功，跳转到账户检查/分发页面
        Navigator.pushReplacement( 
          context,
          MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
        );
      }
      
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = "Login failed";
        if (e.code == 'user-not-found') message = "User not found";
        else if (e.code == 'wrong-password') message = "Incorrect password";
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 底部导航栏逻辑
  void _onNavTap(int index) {
    setState(() {
      _currentNavIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFF153a44),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景渐变
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF153a44),
                  Color(0xFF295a68),
                  Color(0xFF5d8fa0),
                  Color(0xFF94bac4),
                ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        
                        // Logo
                        Image.asset(
                          'assets/images/my_logo.png',
                          width: 200,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) => 
                            const Icon(Icons.image_not_supported, color: Colors.white60, size: 100),
                        ),
                        const SizedBox(height: 16),

                        // 用户类型切换
                        Row(
                          children: [
                            _buildUserTypeButton("Landlord"),
                            const SizedBox(width: 16),
                            _buildUserTypeButton("Tenant"),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 邮箱
                        _buildTextField(
                          controller: _emailController,
                          hintText: "Email",
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),
                        
                        // 密码
                        _buildTextField(
                          controller: _passwordController,
                          hintText: "Password",
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),

                        // 登录按钮
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D5DC7),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Text("Login",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 🔥 修改部分：找回密码 / 注册
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 找回密码按钮
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: Colors.white70,
                                  decoration: TextDecoration.underline, // 加下划线提示可点击
                                  decorationColor: Colors.white70,
                                ),
                              ),
                            ),
                            
                            // 注册按钮
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RegisterScreen(userType: _selectedType),
                                  ),
                                );
                              },
                              child: const Text(
                                "Register", 
                                style: TextStyle(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentNavIndex, 
        onTap: _onNavTap,
        items: const [
          BottomNavItem(icon: Icons.home, label: "Home Page"),
          BottomNavItem(icon: Icons.list, label: "List"),
          BottomNavItem(icon: Icons.star, label: "Favorites"),
          BottomNavItem(icon: Icons.person, label: "My Account"),
        ],
      ),
    );
  }

  // --- 辅助 Widget ---
  Widget _buildUserTypeButton(String type) {
    final bool isSelected = _selectedType == type;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedType = type;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
          foregroundColor: isSelected ? const Color(0xFF1D5DC7) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: isSelected ? 8.0 : 2.0,
        ),
        child: Text(type),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
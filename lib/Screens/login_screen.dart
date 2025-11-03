import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- 检查导入路径 ---
import 'register_screen.dart';
import 'home_screen.dart';
import '../Compoents/animated_bottom_nav.dart';
import '../Services/account_check_screen.dart'; 
// --- 导入结束 ---

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

  // ✅ 【修复 2 - 动画】: 重新引入状态变量，并初始化为 3
  int _currentNavIndex = 3; 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ 【修复 1 - 登录导航】: 
  // 登录成功后，手动导航到 AccountCheckScreen
  Future<void> _login() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 步骤 1: 登录
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 步骤 2: 登录成功后，手动导航到 AccountCheckScreen
      // (这是我们从“点击 Account 按钮”中学到的有效逻辑)
      if (mounted) {
        Navigator.pushReplacement( // 使用 pushReplacement 替换登录页
          context,
          MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
        );
      }
      
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.message ?? "Unknown error"}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ 【修复 2 - 动画】: 
  // 在导航前调用 setState 来更新 _currentNavIndex
  void _onNavTap(int index) {
    // 立即更新状态以触发动画
    setState(() {
      _currentNavIndex = index;
    });

    if (index == 0) {
      // 点击 Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 3) {
      // 点击 Account (当前页)
      // 导航到 AccountCheckScreen (允许用户在已登录时刷新状态)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
      );
    }
    // 其他索引 (List, Favorites) 仅触发动画，不导航
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

                        // 找回密码 / 注册
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () { /* TODO: 实现找回密码 */ },
                              child: const Text("Find Password", style: TextStyle(color: Colors.white70)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RegisterScreen(userType: _selectedType),
                                  ),
                                );
                              },
                              child: const Text("Register", style: TextStyle(color: Colors.white)),
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
      // ✅ 【修复 2 - 动画】: 使用 _currentNavIndex 状态变量
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

  // --- 辅助 Widget (保持不变) ---

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
          backgroundColor: isSelected
              ? Colors.white
              : Colors.white.withOpacity(0.2),
          foregroundColor: isSelected
              ? const Color(0xFF1D5DC7)
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
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
        hintStyle: TextStyle(color: Colors.white70),
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
import 'dart:ui'; // 导入毛玻璃效果
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ 导入 AccountCheckScreen 以修复导航
import '../Services/account_check_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String userType;

  const RegisterScreen({
    super.key,
    required this.userType,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 注册逻辑
  Future<void> _registerUser() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // 1. 验证密码
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!")),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 2. 创建 Auth 用户
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 3. 存储 Firestore 信息
      User? user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'userType': widget.userType, // 存储从 LoginScreen 传入的类型
          'createdAt': Timestamp.now(),
        });

        // 4. ✅ 关键修复：导航到 AccountCheckScreen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registration Successful! Welcome!")),
          );
          // 清除堆栈并导航到检查器，以显示正确的 Dashboard
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AccountCheckScreen()),
            (Route<dynamic> route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = e.message ?? "An unknown error occurred.";
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ 1. 允许 body 延伸到 AppBar 后面
      extendBodyBehindAppBar: true, 
      backgroundColor: const Color(0xFF153a44), // 匹配登录页的背景色

      // ✅ 2. 添加透明的 AppBar 以便返回
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),

      // ✅ 3. 移除底边栏
      // bottomNavigationBar: ... (已移除)

      // ✅ 4. 使用与 LoginScreen 相同的毛玻璃 UI 结构
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
                        
                        // 标题
                        const Text(
                          "Create Account",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // 显示选定的用户类型 (不可更改)
                        _buildUserTypeDisplay(widget.userType),
                        const SizedBox(height: 24),

                        // 表单字段
                        _buildTextField(
                          controller: _nameController,
                          hintText: "Name",
                          icon: Icons.person_outline,
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          hintText: "Email",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          hintText: "Phone Number",
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _passwordController,
                          hintText: "Password",
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hintText: "Confirm Password",
                          icon: Icons.lock_reset_outlined,
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),

                        // 注册按钮
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _registerUser,
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
                                : const Text("Register",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 16)),
                          ),
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
    );
  }

  // --- 辅助 Widget ---

  // 辅助函数：创建统一样式的输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
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

  // 辅助函数：创建用户类型 *显示* (不可切换)
  Widget _buildUserTypeDisplay(String type) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: null, // 禁用按钮
            style: ElevatedButton.styleFrom(
              backgroundColor: type == "Landlord"
                  ? Colors.white
                  : Colors.white.withOpacity(0.2),
              foregroundColor: type == "Landlord"
                  ? const Color(0xFF1D5DC7)
                  : Colors.white,
              disabledBackgroundColor: type == "Landlord"
                  ? Colors.white.withOpacity(0.8) // 更亮，表示选中
                  : Colors.white.withOpacity(0.2), // 更暗，表示未选中
              disabledForegroundColor: type == "Landlord"
                  ? const Color(0xFF1D5DC7).withOpacity(0.8)
                  : Colors.white.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text("Landlord"),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: null, // 禁用按钮
            style: ElevatedButton.styleFrom(
              backgroundColor: type == "Tenant"
                  ? Colors.white
                  : Colors.white.withOpacity(0.2),
              foregroundColor: type == "Tenant"
                  ? const Color(0xFF1D5DC7)
                  : Colors.white,
              disabledBackgroundColor: type == "Tenant"
                  ? Colors.white.withOpacity(0.8)
                  : Colors.white.withOpacity(0.2),
              disabledForegroundColor: type == "Tenant"
                  ? const Color(0xFF1D5DC7).withOpacity(0.8)
                  : Colors.white.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: const Text("Tenant"),
          ),
        ),
      ],
    );
  }
}
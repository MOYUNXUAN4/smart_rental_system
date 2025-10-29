// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 【修改点 1】: 不再需要导入 HomeScreen 和 cloud_firestore
// import 'home_screen.dart'; 
// import 'package:cloud_firestore/cloud_firestore.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedType = "Tenant";
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- 【修改点 2】: 极大地简化登录方法 ---
  Future<void> _loginUser() async {
    // 检查 widget 是否还在树中
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      // 步骤 1: 只进行登录，不再检查用户类型或手动导航
      // AuthGate 中的 StreamBuilder 会自动监听这个变化
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _accountController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // 如果登录成功，AuthGate 会自动处理后续跳转，这里什么都不用做
      
    } on FirebaseAuthException catch (e) {
      // 错误处理逻辑保持不变，这部分做得很好
      String message = "An error occurred. Please check your credentials.";
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Wrong email or password.';
      } else {
        message = e.message ?? message;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An error occurred: $e")),
        );
       }
    } finally {
      // 无论成功失败，最后都停止加载动画
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UI 部分 (build 方法) 不需要任何修改，您的 UI 代码写得很好！
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimaryContainer),
          onPressed: () { if (Navigator.canPop(context)) Navigator.pop(context); },
        ),
        title: Text(
          "Log in",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onPrimaryContainer),
            onPressed: () { /* TODO */ },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 4.0,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 5),
                      // 确保你的 'assets/images/my_logo.png' 路径在 pubspec.yaml 中已配置
                      Image.asset(
                        'assets/images/my_logo.png',
                        width: 250, 
                        height: 250,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedScale(
                              scale: _selectedType == "Landlord" ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() { _selectedType = "Landlord"; });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedType == "Landlord"
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  foregroundColor: _selectedType == "Landlord"
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  elevation: _selectedType == "Landlord" ? 8.0 : 2.0,
                                ),
                                child: const Text("Landlord"),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: AnimatedScale(
                              scale: _selectedType == "Tenant" ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() { _selectedType = "Tenant"; });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedType == "Tenant"
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  foregroundColor: _selectedType == "Tenant"
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  elevation: _selectedType == "Tenant" ? 8.0 : 2.0,
                                ),
                                child: const Text("Tenant"),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24.0),
                      TextFormField(
                        controller: _accountController,
                        decoration: const InputDecoration(
                          labelText: "Account",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password", // 修正拼写：Password
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginUser,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                              : const Text(
                                  "Log in",
                                  style: TextStyle(fontSize: 18.0),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () { /* TODO: 实现找回密码 */ },
                            child: const Text("Find Password"), // 修正拼写
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterScreen(
                                    // Landlord/Tenant 的选择现在只对注册页有意义
                                    userType: _selectedType,
                                  ),
                                ),
                              );
                            },
                            child: const Text("Register"),
                          ),
                        ],
                      ),
                      const Spacer(flex: 5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        currentIndex: 3, // 保持在 "My Account"
        onTap: (index) { /* TODO */ },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home Page"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "List"),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: "Favorites"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "My Account"),
        ],
      ),
    );
  }
}
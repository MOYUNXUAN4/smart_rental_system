// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- 1. 导入
import 'home_screen.dart'; // <-- 2. 导入
// 导入 cloud_firestore 以便未来检查 userType
import 'package:cloud_firestore/cloud_firestore.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _selectedType = "Tenant";
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // --- 3. 添加 loading 状态 ---
  bool _isLoading = false;

  // --- 4. 添加 登录 方法 ---
  Future<void> _loginUser() async {
    // 检查 widget 是否还在树中
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      // 步骤 1: 登录
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _accountController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // --- 步骤 2: (重要!) 检查 userType 是否匹配 ---
      User? user = userCredential.user;
      if (user != null) {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          // 使用 Map<String, dynamic> 来安全地获取数据
          final data = userDoc.data() as Map<String, dynamic>;
          final String actualUserType = data.containsKey('userType') ? data['userType'] : '';
          
          if (actualUserType == _selectedType) {
            // 类型匹配，登录成功
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (Route<dynamic> route) => false,
              );
            }
          } else {
            // 类型不匹配，登出并显示错误
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Login failed. You are not a $_selectedType.")),
              );
            }
          }
        } else {
          // 在 Auth 中存在，但在数据库中不存在 (不应该发生)
          await FirebaseAuth.instance.signOut();
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("User data not found. Please contact support.")),
            );
           }
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred. Please check your credentials.";
      // 捕获 'invalid-credential' 错误，这是新版 Firebase 的常见错误
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        // ... (AppBar UI 保持不变)
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimaryContainer),
          onPressed: () { /* TODO */ },
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
            minHeight: MediaQuery.of(context).size.height - kToolbarHeight - 32,
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
                      Image.asset(
                        'assets/images/my_logo.png',
                        width: 300,
                        height: 300,
                      ),
                      Row(
                        // ... (Landlord/Tenant 按钮 UI 保持不变)
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
                        keyboardType: TextInputType.emailAddress, // 明确设为 email
                      ),
                      const SizedBox(height: 16.0),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Passwords",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24.0), // <-- 增加间距

                      // --- 5. 添加 登录 按钮 ---
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
                      
                      // --- Find Passwords / Register Row 保持不变 ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () { /* TODO */ },
                            child: const Text("Find Passwords"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterScreen(
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
        // ... (底部导航栏 UI 保持不变)
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        currentIndex: 3,
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
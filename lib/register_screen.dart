// lib/register_screen.dart

import 'package:flutter/material.dart';
// --- 1. 导入 Firebase 包 ---
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart'; // <-- 导入 HomeScreen

// RegisterScreen (StatefulWidget) 保持不变
class RegisterScreen extends StatefulWidget {
  // --- 步骤 1: 添加这个变量来接收数据 ---
  final String userType;

  // --- 步骤 2: 在构造函数中要求传入这个值 ---
  const RegisterScreen({
    super.key,
    required this.userType, // 告诉 Flutter 这个参数是必须的
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ... (Controllers 保持不变)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // --- 3. 添加一个 loading 状态 ---
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

  // --- 4. 创建 Firebase 注册方法 ---
  Future<void> _registerUser() async {
    // 检查所有控制器是否已挂载
    if (!mounted) return;

    // a. 开始加载
    setState(() {
      _isLoading = true;
    });

    // b. 验证密码
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!")),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // c. 步骤 1: 在 Firebase Auth 中创建用户
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // d. 步骤 2: 在 Cloud Firestore 中存储额外信息
      User? user = userCredential.user;
      if (user != null) {
        // 我们使用 user.uid 作为文档 ID
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'userType': widget.userType, // <-- 成功传入并存储了 userType！
          'createdAt': Timestamp.now(), // 记录创建时间
        });

        // --- 5. 这是被修改的部分 ---
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registration Successful! Welcome!")),
          );
          // 注册成功后，跳转到主页并清除所有旧路由
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) => false,
          );
        }
        // --- 修改结束 ---
      }
    } on FirebaseAuthException catch (e) {
      // f. 处理 Auth 错误
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else {
        message = e.message ?? "An unknown error occurred.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      // g. 处理其他错误
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: $e")),
      );
    } finally {
      // h. 停止加载
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        title: Text(
          "Create Account",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 标题
                  Text(
                    "Register",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // --- 步骤 3: 显示继承过来的 userType ---
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          // 设置为 null 来禁用按钮
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.userType == "Landlord"
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            foregroundColor: widget.userType == "Landlord"
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            // 当按钮被禁用时，Flutter 会自动应用一层透明度
                            disabledBackgroundColor: widget.userType == "Landlord"
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                             disabledForegroundColor: widget.userType == "Landlord"
                                ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.5)
                                : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          child: const Text("Landlord"),
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: ElevatedButton(
                          // 设置为 null 来禁用按钮
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.userType == "Tenant"
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            foregroundColor: widget.userType == "Tenant"
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            disabledBackgroundColor: widget.userType == "Tenant"
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                             disabledForegroundColor: widget.userType == "Tenant"
                                ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.5)
                                : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          child: const Text("Tenant"),
                        ),
                      ),
                    ],
                  ),
                  // --- 继承显示结束 ---

                  const SizedBox(height: 24.0),

                  // "Name" 输入框
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Name",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16.0),

                  // "Email" 输入框
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16.0),

                  // "Phone Number" 输入框
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16.0),

                  // "Password" 输入框
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // "Confirm Password" 输入框
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Confirm Password",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32.0),

                  // 注册按钮
                  ElevatedButton(
                    // --- 6. 修改 onPressed 和 child ---
                    onPressed: _isLoading ? null : _registerUser, // a. 正在加载时禁用按钮
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator( // b. 显示加载动画
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text( // c. 显示文字
                            "Register",
                            style: TextStyle(fontSize: 18.0),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // 底部导航栏保持不变
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        currentIndex: 3,
        onTap: (index) {
          // TODO: 处理底部导航点击事件
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home Page",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: "List",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: "Favorites",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "My Account",
          ),
        ],
      ),
    );
  }
}

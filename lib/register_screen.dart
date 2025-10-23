// lib/register_screen.dart

import 'package:flutter/material.dart';

// 对应 Composable fun RegisterScreen(onBackClick: () -> Unit)
class RegisterScreen extends StatefulWidget {
  // --- 步骤 1: 添加这个变量来接收数据 ---
  final String userType;

  // --- 步骤 2: 在构造函数中要求传入这个值 ---
  const RegisterScreen({
    Key? key,
    required this.userType, // 告诉 Flutter 这个参数是必须的
  }) : super(key: key);

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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
                  // 我们使用和 LoginScreen 一样的按钮，但是让它们不可点击 (onPressed: null)
                  // 我们可以通过 "widget.userType" 来访问传递过来的值
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          // 设置为 null 来禁用按钮
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.userType == "Landlord"
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceVariant,
                            foregroundColor: widget.userType == "Landlord"
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            // 当按钮被禁用时，Flutter 会自动应用一层透明度
                            disabledBackgroundColor: widget.userType == "Landlord"
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
                                : Theme.of(context).colorScheme.surfaceVariant,
                            foregroundColor: widget.userType == "Tenant"
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            disabledBackgroundColor: widget.userType == "Tenant"
                                ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
                    onPressed: () {
                      /* TODO: 在这里处理 Firebase 注册 */
                      // 注册时，你可以使用 widget.userType 来区分是房东还是租户
                      print("Registering new user as: ${widget.userType}");
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    child: const Text(
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
// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'register_screen.dart'; // 导入我们创建的注册页面

// 对应 Compose 的 @Composable fun LoginScreen(...)
// 我们使用 StatefulWidget，因为它需要管理状态 (selectedType)
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 对应
  // var selectedType by remember { mutableStateOf("Tenant") }
  String _selectedType = "Tenant";

  // 对应
  // var account by remember { mutableStateOf("") }
  // var password by remember { mutableStateOf("") }
  // 在 Flutter 中，我们使用 TextEditingController 来管理输入框
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 别忘了释放 Controller
  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 对应 Compose 的 Column(fillMaxSize, background)
    // 在 Flutter 中，Scaffold 是页面的根布局
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,

      // 对应顶部的 Row (TopAppBar)
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onPrimaryContainer),
          onPressed: () { /* TODO: 处理返回事件 */ },
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
            onPressed: () { /* TODO: 处理通知点击 */ },
          ),
        ],
      ),

      // 对应中间的 Column(weight(1f))
      // SingleChildScrollView 可以在内容过多时（比如弹出键盘）防止溢出
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // 确保内容至少填满屏幕（减去 AppBar 和 Padding 的高度）
            minHeight: MediaQuery.of(context).size.height - kToolbarHeight - 32,
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              // 对应中间的 Card
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 4.0,
                // 卡片内部的 Column
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 对应 Spacer(modifier = Modifier.weight(0.5f))
                      const Spacer(flex: 5), // flex 类似于 weight

                      // 对应 Image(R.drawable.my_logo)
                      Image.asset(
                        'assets/images/my_logo.png', // 确保这个路径与 pubspec.yaml 中一致
                        width: 300,
                        height: 300,
                      ),

                      // 对应 Landlord/Tenant 按钮的 Row
                      Row(
                        children: [
                          // Landlord 按钮
                          Expanded(
                            // 对应 animateFloatAsState (scale)
                            child: AnimatedScale(
                              scale: _selectedType == "Landlord" ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              // 对应 animateDpAsState (elevation) 和 animateColorAsState (colors)
                              // Flutter 的 ElevatedButton/OutlinedButton 会自动为其样式的变化添加动画
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedType = "Landlord";
                                  });
                                },
                                // 根据状态动态改变样式
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedType == "Landlord"
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surfaceVariant,
                                  foregroundColor: _selectedType == "Landlord"
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  elevation: _selectedType == "Landlord" ? 8.0 : 2.0,
                                ),
                                child: const Text("Landlord"),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 16.0), // 对应 Spacer(width(16.dp))

                          // Tenant 按钮
                          Expanded(
                            child: AnimatedScale(
                              scale: _selectedType == "Tenant" ? 1.1 : 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedType = "Tenant";
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedType == "Tenant"
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surfaceVariant,
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
                      const SizedBox(height: 24.0), // 对应 Spacer(height(24.dp))

                      // 对应 Account 的 OutlinedTextField
                      TextFormField(
                        controller: _accountController,
                        decoration: const InputDecoration(
                          labelText: "Account",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // 对应 Password 的 OutlinedTextField
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true, // 对应 PasswordVisualTransformation
                        decoration: const InputDecoration(
                          labelText: "Passwords",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // 对应 "Find Passwords" 和 "Register" 的 Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () { /* TODO */ },
                            child: const Text("Find Passwords"),
                          ),
                          TextButton(
                            onPressed: () {
                              // *** 这是唯一的修改 ***
                              // 我们把 _selectedType 变量传递给 RegisterScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterScreen(
                                    userType: _selectedType, // <-- 修改在这里
                                  ),
                                ),
                              );
                            },
                            child: const Text("Register"),
                          ),
                        ],
                      ),

                      // 对应 Spacer(modifier = Modifier.weight(0.5f))
                      const Spacer(flex: 5),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // 对应底部的 Row (BottomNavBar)
      // Flutter 中使用 BottomNavigationBar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        type: BottomNavigationBarType.fixed, // 确保所有项都可见
        selectedItemColor: Theme.of(context).colorScheme.primary, // "My Account" 选中颜色
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant, // 未选中颜色
        currentIndex: 3, // "My Account" 是第 4 项 (索引为 3)
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
            label: "Favorites", // 我修正了拼写
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
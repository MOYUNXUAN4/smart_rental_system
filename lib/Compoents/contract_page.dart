// lib/Compoents/contract_page.dart
import 'package:flutter/material.dart';
import 'contract_generator.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';

class ContractPage extends StatefulWidget {
  const ContractPage({super.key});

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage> {
  String _selectedLanguage = 'zh';
  bool _isGenerating = false;

  // 测试数据
  final String landlordName = "John Doe";
  final String tenantName = "Alice Lee";
  final String propertyAddress = "123, Jalan Bukit, Kuala Lumpur";
  final String rentAmount = "1200";
  final String startDate = "2025-11-01";
  final String endDate = "2026-10-31";

 // lib/Compoents/contract_page.dart

// ... (build 方法和变量保持不变) ...

// ✅ 2. 替换这个函数
Future<void> _generateAndOpenPDF() async {
  setState(() => _isGenerating = true);
  try {
    // 步骤 1: 调用新的函数名 (generateAndSaveContract)
    // 并接收返回的 File 对象
    final File generatedFile = await ContractGenerator.generateAndSaveContract(
      landlordName: landlordName,
      tenantName: tenantName,
      propertyAddress: propertyAddress,
      rentAmount: rentAmount,
      startDate: startDate,
      endDate: endDate,
      language: _selectedLanguage,
    );

    // 步骤 2: 手动打开已保存的文件
    await OpenFile.open(generatedFile.path);

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 生成失败: $e')));
  } finally {
    setState(() => _isGenerating = false);
  }
}

// ... (build 方法保持不变) ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('租赁合同生成'), backgroundColor: Colors.teal),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('选择语言: ', style: TextStyle(fontSize: 16)),
                DropdownButton<String>(
                  value: _selectedLanguage,
                  items: const [
                    DropdownMenuItem(value: 'zh', child: Text('中文')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLanguage = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 50),
            _isGenerating
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _generateAndOpenPDF,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('生成并打开合同 PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                  ),
            const SizedBox(height: 30),
            const Text(
              '合同内容使用默认测试数据，无需手动输入',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

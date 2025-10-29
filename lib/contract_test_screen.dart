import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:smart_rental_system/Compoents/contract_generator.dart';

class ContractTestScreen extends StatefulWidget {
  const ContractTestScreen({super.key});

  @override
  State<ContractTestScreen> createState() => _ContractTestScreenState();
}

class _ContractTestScreenState extends State<ContractTestScreen> {
  String _selectedLanguage = 'zh';
  bool _isGenerating = false;

  // 测试数据
  final String landlordName = "John Doe";
  final String tenantName = "Alice Lee";
  final String propertyAddress = "123, Jalan Bukit, Kuala Lumpur";
  final String rentAmount = "1200";
  final String startDate = "2025-11-01";
  final String endDate = "2026-10-31";

  Future<void> _generateAndOpenPDF() async {
    setState(() => _isGenerating = true);
    try {
      await ContractGenerator.generateAndOpenContract(
        landlordName: landlordName,
        tenantName: tenantName,
        propertyAddress: propertyAddress,
        rentAmount: rentAmount,
        startDate: startDate,
        endDate: endDate,
        language: _selectedLanguage,
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ 生成失败: $e')));
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  // ---------------- 毛玻璃语言选择 ----------------
  Widget _buildLanguageSelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '选择语言',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButton<String>(
                value: _selectedLanguage,
                dropdownColor: Colors.white.withOpacity(0.15),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                underline: const SizedBox(),
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
        ),
      ),
    );
  }

  // ---------------- 主界面 ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('测试合同生成', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildLanguageSelector(),
                  const SizedBox(height: 50),
                  _isGenerating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : ElevatedButton.icon(
                          onPressed: _generateAndOpenPDF,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('生成并打开合同 PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D5DC7),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
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
          ),
        ],
      ),
    );
  }
}


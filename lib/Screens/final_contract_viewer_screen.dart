import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class FinalContractViewerScreen extends StatefulWidget {
  final String contractUrlZh; // 中文版链接
  final String contractUrlEn; // 英文版链接
  final String defaultLang;   // 默认进入时的语言

  const FinalContractViewerScreen({
    super.key,
    required this.contractUrlZh,
    required this.contractUrlEn,
    this.defaultLang = 'zh',
  });

  @override
  State<FinalContractViewerScreen> createState() => _FinalContractViewerScreenState();
}

class _FinalContractViewerScreenState extends State<FinalContractViewerScreen> {
  String _currentLanguage = 'zh';
  String? _localPdfPath;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.defaultLang;
    _loadPdf();
  }

  // 下载 PDF 到本地缓存
  Future<void> _loadPdf() async {
    setState(() => _isLoading = true);
    try {
      final String targetUrl = _currentLanguage == 'zh' ? widget.contractUrlZh : widget.contractUrlEn;
      
      if (targetUrl.isEmpty) throw Exception("Contract URL is missing for $_currentLanguage");

      final response = await http.get(Uri.parse(targetUrl));
      if (response.statusCode != 200) throw Exception("Failed to download PDF");

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/final_contract_${_currentLanguage}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        setState(() {
          _localPdfPath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _toggleLanguage() {
    setState(() {
      _currentLanguage = _currentLanguage == 'zh' ? 'en' : 'zh';
    });
    _loadPdf(); // 切换语言后重新下载对应的文件
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_currentLanguage == 'zh' ? "最终合同预览" : "Final Contract", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _toggleLanguage,
              icon: const Icon(Icons.language, color: Colors.white, size: 18),
              label: Text(_currentLanguage == 'zh' ? 'Switch to English' : '切换中文', 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          // 背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF153a44), Color(0xFF295a68)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage != null
                    ? Center(child: Text("Error: $_errorMessage", style: const TextStyle(color: Colors.redAccent)))
                    : Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: PDFView(
                            key: Key(_localPdfPath!), // 强制刷新
                            filePath: _localPdfPath,
                            enableSwipe: true,
                            swipeHorizontal: false,
                            autoSpacing: true,
                            pageFling: true,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
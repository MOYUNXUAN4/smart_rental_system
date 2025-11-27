import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_pdfview/flutter_pdfview.dart';

class SignContractScreen extends StatefulWidget {
  final String docId;
  final String contractUrl;

  const SignContractScreen({super.key, required this.docId, required this.contractUrl});

  @override
  State<SignContractScreen> createState() => _SignContractScreenState();
}

class _SignContractScreenState extends State<SignContractScreen> {
  // ▼▼▼ 优化 1: 笔触调细至 3.0，视觉上会感觉响应更快 ▼▼▼
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3.0, 
    penColor: const Color(0xFF0D47A1), // 更深的蓝色，像签字笔
    exportBackgroundColor: Colors.transparent,
  );
  
  String? _localPdfPath;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf() async {
    try {
      final response = await http.get(Uri.parse(widget.contractUrl));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/contract_${widget.docId}.pdf');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) setState(() { _localPdfPath = file.path; _isLoading = false; });
    } catch (e) {
      print(e);
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_sigController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign before submitting."), backgroundColor: Colors.redAccent)
      ); 
      return;
    }
    setState(() => _isSubmitting = true);
    
    try {
      final Uint8List? data = await _sigController.toPngBytes();
      if (data != null) {
        final ref = FirebaseStorage.instance.ref().child('signatures/${widget.docId}_tenant.png');
        await ref.putData(data);
        final url = await ref.getDownloadURL();
        
        await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
          'status': 'tenant_signed',
          'tenantSignatureUrl': url,
          'tenantSignedAt': Timestamp.now(),
          'isReadByLandlord': false,
        });
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Contract Signed Successfully!"), backgroundColor: Colors.green)
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1D5DC7);
    const Color glassBorder = Colors.white24;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Sign Contract", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // --- 背景层 ---
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
                stops: [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: _isLoading 
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text("Loading Contract...", style: TextStyle(color: Colors.white70))
                    ],
                  )
                )
              : Column(
                  children: [
                    // --- 1. PDF 预览区域 ---
                    Expanded(
                      flex: 5, 
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: glassBorder),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                color: Colors.white.withOpacity(0.15),
                                child: const Row(
                                  children: [
                                    Icon(Icons.description, color: Colors.white70, size: 16),
                                    SizedBox(width: 8),
                                    Text("Contract Preview", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: PDFView(
                                  filePath: _localPdfPath,
                                  enableSwipe: true,
                                  swipeHorizontal: false,
                                  autoSpacing: true,
                                  pageFling: true,
                                  pageSnap: false,
                                  fitEachPage: false,
                                  backgroundColor: Colors.grey[200],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // --- 2. 签名区域 (性能优化版) ---
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      // 移除复杂的 Shadow，减少渲染压力
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2D33).withOpacity(0.8), // 稍微不透明一点，减少混合计算
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: glassBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.draw, color: Colors.white.withOpacity(0.9), size: 18),
                                const SizedBox(width: 8),
                                const Text("Your Signature", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          
                          // 签名板容器
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 160, 
                                color: Colors.white, // 白纸背景
                                child: Stack(
                                  children: [
                                    // 背景提示字
                                    const Center(
                                      child: Text("Sign Here", 
                                        style: TextStyle(color: Color(0xFFEEEEEE), fontSize: 40, fontWeight: FontWeight.bold)
                                      ),
                                    ),
                                    
                                    // ▼▼▼ 优化 2: 使用 RepaintBoundary 包裹签名组件 ▼▼▼
                                    // 这告诉 Flutter：这一块独立渲染，不要因为外界背景变化而重绘，也不要因为我重绘而影响背景
                                    RepaintBoundary(
                                      child: Signature(
                                        controller: _sigController,
                                        backgroundColor: Colors.transparent,
                                        height: 160, // 明确指定高度
                                      ),
                                    ),
                                    // ▲▲▲ 优化结束 ▲▲▲

                                    // 悬浮清除按钮 (放在这里操作更顺手)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () => _sigController.clear(),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 16, color: Colors.black54),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- 3. 提交按钮 ---
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: primaryBlue.withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isSubmitting 
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 20),
                                  SizedBox(width: 8),
                                  Text("Confirm & Submit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}
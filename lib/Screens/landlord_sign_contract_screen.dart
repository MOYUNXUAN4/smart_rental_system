import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../Compoents/contract_generator.dart'; 

class LandlordSignContractScreen extends StatefulWidget {
  final String docId;

  const LandlordSignContractScreen({super.key, required this.docId});

  @override
  State<LandlordSignContractScreen> createState() => _LandlordSignContractScreenState();
}

class _LandlordSignContractScreenState extends State<LandlordSignContractScreen> {
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3.0,
    penColor: const Color(0xFF0D47A1),
    exportBackgroundColor: Colors.transparent,
  );

  String? _currentDisplayPdfPath; 
  File? _finalSignedPdfFile;
  Uint8List? _tenantSignatureBytes; 
  
  bool _isLoading = true;
  bool _isPreviewMode = false;
  bool _isUploading = false;
  // 新增：错误信息变量，方便调试
  String? _errorMessage; 

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  Future<void> _prepareData() async {
    try {
      // 1. 下载租客签名
      // ⚠️ 如果租客端没有成功上传签名图，这里会报错
      final pngRef = FirebaseStorage.instance.ref().child('signatures/${widget.docId}_tenant.png');
      
      try {
        final tenantBytes = await pngRef.getData(5 * 1024 * 1024);
        _tenantSignatureBytes = tenantBytes;
      } catch (e) {
        print("Tenant signature not found or error: $e");
        // 如果找不到租客签名，我们可以选择继续（单签名）或者报错
        // 这里我们继续，但租客签名位会是空的
      }

      // 2. 获取数据
      final docSnapshot = await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).get();
      if (!docSnapshot.exists) throw Exception("Booking data not found");
      final data = docSnapshot.data() as Map<String, dynamic>;

      // 3. 生成初始预览
      final File initialPdf = await ContractGenerator.generateAndSaveContract(
        landlordName: data['landlordName'] ?? 'Unknown',
        tenantName: data['tenantName'] ?? 'Unknown',
        propertyAddress: data['propertyName'] ?? 'Unknown Address',
        rentAmount: (data['rentAmount'] ?? 0).toString(),
        startDate: data['startDate'] ?? '',
        endDate: data['endDate'] ?? '',
        paymentDay: (data['paymentDay'] ?? '1st').toString(),
        language: 'en',
        tenantSignature: _tenantSignatureBytes, 
        landlordSignature: null, 
      );

      if (mounted) {
        setState(() {
          _currentDisplayPdfPath = initialPdf.path;
          _isLoading = false;
          _errorMessage = null; // 清除错误
        });
      }
    } catch (e) {
      print("Error preparing data: $e");
      if(mounted) {
        setState(() {
          _isLoading = false;
          // 记录错误信息，不让界面崩溃
          _errorMessage = "Failed to load contract data: $e"; 
        });
      }
    }
  }

  Future<void> _generatePreview() async {
    if (_sigController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign first."), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Uint8List? landlordBytes = await _sigController.toPngBytes();

      if (landlordBytes != null) {
        final docSnapshot = await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).get();
        final data = docSnapshot.data() as Map<String, dynamic>;

        final File signedFile = await ContractGenerator.generateAndSaveContract(
          landlordName: data['landlordName'] ?? '',
          tenantName: data['tenantName'] ?? '',
          propertyAddress: data['propertyName'] ?? '',
          rentAmount: (data['rentAmount'] ?? 0).toString(),
          startDate: data['startDate'] ?? '',
          endDate: data['endDate'] ?? '',
          paymentDay: (data['paymentDay'] ?? '1st').toString(),
          language: 'en',
          tenantSignature: _tenantSignatureBytes, 
          landlordSignature: landlordBytes, 
        );

        if (mounted) {
          setState(() {
            _finalSignedPdfFile = signedFile;
            _currentDisplayPdfPath = signedFile.path;
            _isPreviewMode = true;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print(e);
      if(mounted) setState(() {
         _isLoading = false;
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating preview: $e")));
      });
    }
  }

  void _resetToSigning() {
    setState(() {
      _sigController.clear();
      _isPreviewMode = false;
      _finalSignedPdfFile = null;
    });
  }

  Future<void> _uploadAndFinish() async {
    if (_finalSignedPdfFile == null) return;
    setState(() => _isUploading = true);

    try {
      final storageRef = FirebaseStorage.instance.ref().child('contracts/${widget.docId}_final.pdf');
      await storageRef.putFile(_finalSignedPdfFile!);
      final String finalUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
        'status': 'awaiting_payment', // ✅ 状态更新为等待付款
        'contractUrl': finalUrl, 
        'landlordSignedAt': Timestamp.now(),
        'isReadByTenant': false, 
      });

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contract Finalized!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e")));
    } finally {
      if(mounted) setState(() => _isUploading = false);
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
        title: Text(_isPreviewMode ? "Final Review" : "Landlord Signature", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
                stops: [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage != null // ✅ 1. 检查是否有错误
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      ))
                    : _currentDisplayPdfPath == null // ✅ 2. 核心修复：检查路径是否为空
                        ? const Center(child: Text("Error: PDF path is missing", style: TextStyle(color: Colors.white)))
                        : Column(
                            children: [
                              // --- PDF 显示区域 ---
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
                                          child: Row(
                                            children: [
                                              const Icon(Icons.description, color: Colors.white70, size: 16),
                                              const SizedBox(width: 8),
                                              Text(
                                                _isPreviewMode 
                                                  ? "Final Version (Both Signed)" 
                                                  : "Current Version (Tenant Signed Only)", 
                                                style: const TextStyle(color: Colors.white70, fontSize: 12)
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          // ✅ 现在这里是安全的，因为上面检查了 _currentDisplayPdfPath != null
                                          child: PDFView(
                                            key: Key(_currentDisplayPdfPath!), 
                                            filePath: _currentDisplayPdfPath,
                                            enableSwipe: true,
                                            swipeHorizontal: false,
                                            autoSpacing: true,
                                            pageFling: true,
                                            backgroundColor: Colors.grey[200],
                                            onError: (error) {
                                              print("PDFView error: $error");
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // --- 交互区域 ---
                              if (_isPreviewMode)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      const Text(
                                        "Please review the final document before activating.",
                                        style: TextStyle(color: Colors.white70, fontSize: 14),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 55,
                                              child: OutlinedButton(
                                                onPressed: _isUploading ? null : _resetToSigning,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  side: const BorderSide(color: Colors.white70),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                ),
                                                child: const Text("Re-sign"),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: SizedBox(
                                              height: 55,
                                              child: ElevatedButton(
                                                onPressed: _isUploading ? null : _uploadAndFinish,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                ),
                                                child: _isUploading
                                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                                    : const Text("Finalize", style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E2D33).withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: glassBorder),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            child: Row(
                                              children: [
                                                Icon(Icons.draw, color: Colors.white, size: 18),
                                                SizedBox(width: 8),
                                                Text("Landlord Signature", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                height: 160,
                                                color: Colors.white,
                                                child: Stack(
                                                  children: [
                                                    const Center(
                                                      child: Text("Sign Here",
                                                          style: TextStyle(color: Color(0xFFEEEEEE), fontSize: 40, fontWeight: FontWeight.bold)),
                                                    ),
                                                    RepaintBoundary(
                                                      child: Signature(
                                                        controller: _sigController,
                                                        backgroundColor: Colors.transparent,
                                                        height: 160,
                                                      ),
                                                    ),
                                                    Positioned(
                                                      top: 8, right: 8,
                                                      child: GestureDetector(
                                                        onTap: () => _sigController.clear(),
                                                        child: Container(
                                                          padding: const EdgeInsets.all(6),
                                                          decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
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
                                    
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: SizedBox(
                                        width: double.infinity,
                                        height: 55,
                                        child: ElevatedButton(
                                          onPressed: _generatePreview,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryBlue,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.visibility, size: 20),
                                              SizedBox(width: 8),
                                              Text("Preview with Signature", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}
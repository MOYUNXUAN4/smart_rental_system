import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

// ⚠️ 确保路径拼写与你项目一致
import '../Compoents/contract_generator.dart';

class SignContractScreen extends StatefulWidget {
  final String docId;
  final String? contractUrl; // 租客签合约场景有这个参数

  const SignContractScreen({
    super.key,
    required this.docId,
    this.contractUrl,
  });

  @override
  State<SignContractScreen> createState() => _SignContractScreenState();
}

class _SignContractScreenState extends State<SignContractScreen> {
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

  // ===========================
  // 1. 准备数据：下载旧签名 + 生成初版 PDF
  // ===========================
  Future<void> _prepareData() async {
    try {
      // A. 下载租客旧签名
      final pngRef = FirebaseStorage.instance.ref().child('signatures/${widget.docId}_tenant.png');
      try {
        final tenantBytes = await pngRef.getData(5 * 1024 * 1024);
        _tenantSignatureBytes = tenantBytes;
      } catch (_) {}

      // B. Booking 基本数据
      final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).get();
      if (!bookingDoc.exists) throw Exception("Booking not found");
      final bookingData = bookingDoc.data() as Map<String, dynamic>;

      // C. 相关详情
      final String propertyId = bookingData['propertyId'];
      final String tenantUid = bookingData['tenantUid'];
      final String? landlordUid = bookingData['landlordUid'];

      // 房源信息
      final propertyDoc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      final propertyData = propertyDoc.data() ?? {};
      final String address = "${propertyData['unitNumber'] ?? ''}, ${propertyData['communityName'] ?? ''}";
      final String rent = (propertyData['price'] ?? 0).toString();

      // 房东名
      String landlordName = "Landlord";
      if (landlordUid != null) {
        final lDoc = await FirebaseFirestore.instance.collection('users').doc(landlordUid).get();
        if (lDoc.exists) landlordName = lDoc.data()?['name'] ?? "Landlord";
      }

      // 租客名
      final tDoc = await FirebaseFirestore.instance.collection('users').doc(tenantUid).get();
      final String tenantName = tDoc.exists ? (tDoc.data()?['name'] ?? "Tenant") : "Tenant";

      // 日期处理
      String startStr = "";
      String endStr = "";
      String paymentDay = "1";

      if (bookingData['leaseStartDate'] != null) {
        DateTime s = (bookingData['leaseStartDate'] as Timestamp).toDate();
        startStr = "${s.year}-${s.month}-${s.day}";
        paymentDay = "${s.day}";
      }

      if (bookingData['leaseEndDate'] != null) {
        DateTime e = (bookingData['leaseEndDate'] as Timestamp).toDate();
        endStr = "${e.year}-${e.month}-${e.day}";
      }

      // D. 生成初始 PDF（仅租客签）
      final File initialPdf = await ContractGenerator.generateAndSaveContract(
        landlordName: landlordName,
        tenantName: tenantName,
        propertyAddress: address,
        rentAmount: rent,
        startDate: startStr,
        endDate: endStr,
        paymentDay: paymentDay,
        language: 'en',
        tenantSignature: _tenantSignatureBytes,
        landlordSignature: null,
      );

      if (mounted) {
        setState(() {
          _currentDisplayPdfPath = initialPdf.path;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load: $e";
        });
      }
    }
  }

  // ==================================
  // 2. 生成房东签名后的预览 PDF
  // ==================================
  Future<void> _generatePreview() async {
    if (_sigController.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please sign"), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Uint8List? landlordBytes = await _sigController.toPngBytes();
      if (landlordBytes == null) return;

      // 重新拉取数据以确保准确
      final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).get();
      final bookingData = bookingDoc.data() as Map<String, dynamic>;

      final String propertyId = bookingData['propertyId'];
      final String tenantUid = bookingData['tenantUid'];
      final String? landlordUid = bookingData['landlordUid'];

      final propertyDoc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      final propertyData = propertyDoc.data() ?? {};

      // 房东名字
      String landlordName = "Landlord";
      if (landlordUid != null) {
        final lDoc = await FirebaseFirestore.instance.collection('users').doc(landlordUid).get();
        if (lDoc.exists) landlordName = lDoc.data()?['name'] ?? "Landlord";
      }

      // 租客名字
      final tDoc = await FirebaseFirestore.instance.collection('users').doc(tenantUid).get();
      final String tenantName = tDoc.exists ? (tDoc.data()?['name'] ?? "Tenant") : "Tenant";

      // 日期
      String startStr = "";
      String endStr = "";
      String paymentDay = "1";

      if (bookingData['leaseStartDate'] != null) {
        DateTime s = (bookingData['leaseStartDate'] as Timestamp).toDate();
        startStr = "${s.year}-${s.month}-${s.day}";
        paymentDay = "${s.day}";
      }

      if (bookingData['leaseEndDate'] != null) {
        DateTime e = (bookingData['leaseEndDate'] as Timestamp).toDate();
        endStr = "${e.year}-${e.month}-${e.day}";
      }

      // 最终双签 PDF
      final File signedFile = await ContractGenerator.generateAndSaveContract(
        landlordName: landlordName,
        tenantName: tenantName,
        propertyAddress: "${propertyData['unitNumber'] ?? ''}, ${propertyData['communityName'] ?? ''}",
        rentAmount: (propertyData['price'] ?? 0).toString(),
        startDate: startStr,
        endDate: endStr,
        paymentDay: paymentDay,
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
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ===========================
  // 3. 重新签字
  // ===========================
  void _resetToSigning() {
    setState(() {
      _sigController.clear();
      _isPreviewMode = false;
      _finalSignedPdfFile = null;
    });
  }

  // =======================================
  // 4. 上传最终 PDF 并将状态设为 awaiting_payment
  // =======================================
  Future<void> _uploadAndFinish() async {
    if (_finalSignedPdfFile == null) return;

    setState(() => _isUploading = true);

    try {
      final storageRef =
          FirebaseStorage.instance.ref().child('contracts/${widget.docId}_final.pdf');
      await storageRef.putFile(_finalSignedPdfFile!);
      final String finalUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
        'status': 'awaiting_payment',
        'contractUrl': finalUrl,
        'landlordSignedAt': Timestamp.now(),
        'isReadByTenant': false,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contract Finalized"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ===========================
  // 5. UI
  // ===========================
  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1D5DC7);
    const Color glassBorder = Colors.white24;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _isPreviewMode ? "Final Review" : "Sign Contract",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF153a44),
                  Color(0xFF295a68),
                  Color(0xFF5d8fa0),
                  Color(0xFF94bac4)
                ],
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!,
                            style:
                                const TextStyle(color: Colors.redAccent, fontSize: 16)),
                      )
                    : _currentDisplayPdfPath == null
                        ? const Center(
                            child: Text("PDF path missing",
                                style: TextStyle(color: Colors.white)))
                        : Column(
                            children: [
                              // ======= PDF 区域 =======
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
                                    child: PDFView(
                                      key: Key(_currentDisplayPdfPath!),
                                      filePath: _currentDisplayPdfPath!,
                                      enableSwipe: true,
                                      autoSpacing: true,
                                      backgroundColor: Colors.grey[200],
                                    ),
                                  ),
                                ),
                              ),

                              // ======= 操作按钮区域 =======
                              if (_isPreviewMode)
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      const Text("Please review the final document",
                                          style: TextStyle(
                                              color: Colors.white70, fontSize: 14)),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: _isUploading ? null : _resetToSigning,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                side: const BorderSide(color: Colors.white70),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16)),
                                              ),
                                              child: const Text("Re-sign"),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed:
                                                  _isUploading ? null : _uploadAndFinish,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16)),
                                              ),
                                              child: _isUploading
                                                  ? const SizedBox(
                                                      height: 24,
                                                      width: 24,
                                                      child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white),
                                                    )
                                                  : const Text("Finalize",
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              else
                                // ======= 签名区域 =======
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
                                            padding: EdgeInsets.all(12.0),
                                            child: Row(
                                              children: [
                                                Icon(Icons.draw,
                                                    color: Colors.white, size: 18),
                                                SizedBox(width: 8),
                                                Text("Landlord Signature",
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                height: 160,
                                                color: Colors.white,
                                                child: Stack(
                                                  children: [
                                                    const Center(
                                                        child: Text(
                                                      "Sign Here",
                                                      style: TextStyle(
                                                          color: Color(0xFFEEEEEE),
                                                          fontSize: 40,
                                                          fontWeight: FontWeight.bold),
                                                    )),
                                                    Signature(
                                                      controller: _sigController,
                                                      backgroundColor: Colors.transparent,
                                                    ),
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: GestureDetector(
                                                        onTap: () => _sigController.clear(),
                                                        child: Container(
                                                          padding: const EdgeInsets.all(6),
                                                          decoration: BoxDecoration(
                                                              color: Colors.grey[200],
                                                              shape: BoxShape.circle),
                                                          child: const Icon(Icons.close,
                                                              size: 14,
                                                              color: Colors.black54),
                                                        ),
                                                      ),
                                                    )
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
                                        height: 55,
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _generatePreview,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryBlue,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16)),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.visibility, size: 20),
                                              SizedBox(width: 8),
                                              Text("Preview with Signature",
                                                  style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    )
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

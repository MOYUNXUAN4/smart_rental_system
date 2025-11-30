import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:signature/signature.dart';

// ⚠️ 确保路径与你的项目一致
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
  Uint8List? _tenantSignatureBytes; // 租客的签名数据
  Uint8List? _mySignatureBytes;     // 房东自己的签名缓存
  
  bool _isLoading = true;
  bool _isPreviewMode = false;      // 是否处于预览最终版模式
  bool _isUploading = false;
  String? _errorMessage; 

  // 语言控制
  String _currentLanguage = 'en';
  
  // 缓存数据 (避免反复读库)
  Map<String, dynamic>? _cachedData;

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

  // ==========================================
  // 1. 初始化数据：下载租客签名 + 准备合同文本
  // ==========================================
  Future<void> _prepareData() async {
    try {
      // A. 下载租客签名 (必须步骤)
      final pngRef = FirebaseStorage.instance.ref().child('signatures/${widget.docId}_tenant.png');
      try {
        final tenantBytes = await pngRef.getData(5 * 1024 * 1024); // Max 5MB
        _tenantSignatureBytes = tenantBytes;
      } catch (e) {
        print("Warning: Tenant signature missing or download failed: $e");
        // 即使租客签名下载失败，也允许房东查看，但签名位会空缺
      }

      // B. 获取 Booking 和 Property 数据
      if (_cachedData == null) {
        final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).get();
        if (!bookingDoc.exists) throw Exception("Booking not found");
        final bookingData = bookingDoc.data() as Map<String, dynamic>;

        final String propertyId = bookingData['propertyId'];
        final String tenantUid = bookingData['tenantUid'];
        final String? landlordUid = bookingData['landlordUid'];

        final propertyDoc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
        final propertyData = propertyDoc.data() ?? {};
        
        String landlordName = "Landlord";
        if (landlordUid != null) {
          final lDoc = await FirebaseFirestore.instance.collection('users').doc(landlordUid).get();
          if (lDoc.exists) landlordName = lDoc.data()?['name'] ?? "Landlord";
        }

        final tDoc = await FirebaseFirestore.instance.collection('users').doc(tenantUid).get();
        final String tenantName = tDoc.exists ? (tDoc.data()?['name'] ?? "Tenant") : "Tenant";

        _cachedData = {
          'landlordName': landlordName,
          'tenantName': tenantName,
          'address': "${propertyData['unitNumber'] ?? ''}, ${propertyData['communityName'] ?? ''}",
          'rent': (propertyData['price'] ?? 0).toString(),
          'leaseStartDate': bookingData['leaseStartDate'],
          'leaseEndDate': bookingData['leaseEndDate'],
        };
      }

      // C. 生成初始 PDF (此时只有租客签名，房东签名传 null)
      await _renderPdf(landlordSignature: null); 

    } catch (e) {
      print("Error in _prepareData: $e");
      if(mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load contract data. Please try again."; 
        });
      }
    }
  }

  // ==========================================
  // 2. 核心渲染方法 (调用 Generator)
  // ==========================================
  Future<void> _renderPdf({required Uint8List? landlordSignature}) async {
    if (_cachedData == null) return;

    String startStr = "";
    String endStr = "";
    String paymentDay = "1";
    if (_cachedData!['leaseStartDate'] != null) {
       DateTime s = (_cachedData!['leaseStartDate'] as Timestamp).toDate();
       startStr = "${s.year}-${s.month}-${s.day}";
       paymentDay = "${s.day}";
    }
    if (_cachedData!['leaseEndDate'] != null) {
       DateTime e = (_cachedData!['leaseEndDate'] as Timestamp).toDate();
       endStr = "${e.year}-${e.month}-${e.day}";
    }

    // 调用通用的 PDF 生成器
    final File pdfFile = await ContractGenerator.generateAndSaveContract(
      landlordName: _cachedData!['landlordName'],
      tenantName: _cachedData!['tenantName'],
      propertyAddress: _cachedData!['address'],
      rentAmount: _cachedData!['rent'],
      startDate: startStr,
      endDate: endStr,
      paymentDay: paymentDay,
      language: _currentLanguage, // 动态语言
      tenantSignature: _tenantSignatureBytes, // 始终传入租客签名
      landlordSignature: landlordSignature,   // 根据状态传入房东签名
    );

    if (mounted) {
      setState(() {
        _currentDisplayPdfPath = pdfFile.path;
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  // ==========================================
  // 3. 交互逻辑 (语言切换 & 预览)
  // ==========================================
  void _toggleLanguage() {
    setState(() {
      _currentLanguage = _currentLanguage == 'zh' ? 'en' : 'zh';
      _isLoading = true;
    });
    // 切换语言时，如果处于预览模式，需要保持房东的签名显示
    // 如果还没预览，则不显示房东签名
    _renderPdf(landlordSignature: _isPreviewMode ? _mySignatureBytes : null);
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
      // 获取房东签名的图片数据
      final Uint8List? landlordBytes = await _sigController.toPngBytes();
      
      if (landlordBytes != null) {
        _mySignatureBytes = landlordBytes; // 缓存起来供上传使用
        await _renderPdf(landlordSignature: landlordBytes);
        if (mounted) setState(() => _isPreviewMode = true);
      }
    } catch (e) {
      if(mounted) setState(() {
         _isLoading = false;
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating preview: $e")));
      });
    }
  }

  void _resetToSigning() {
    setState(() {
      _sigController.clear();
      _mySignatureBytes = null;
      _isPreviewMode = false;
      _isLoading = true;
    });
    // 重置回只有租客签名的状态
    _renderPdf(landlordSignature: null);
  }

  // ==========================================
  // 4. 最终提交 (生成双语版 -> 上传 -> 删旧文件 -> 更新库)
  // ==========================================
  Future<void> _uploadAndFinish() async {
    // 确保有签名数据
    if (_mySignatureBytes == null) {
      if (_sigController.isNotEmpty) {
        _mySignatureBytes = await _sigController.toPngBytes();
      }
      if (_mySignatureBytes == null) return;
    }
    
    setState(() => _isUploading = true);

    try {
      // ✅ 1. 先获取旧文件的 URL (为了上传成功后删除)
      final docSnap = await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).get();
      final oldData = docSnap.data() ?? {};
      
      // 收集待删除列表
      List<String> urlsToDelete = [];
      if (oldData['contractUrl'] != null) urlsToDelete.add(oldData['contractUrl']);
      if (oldData['contractUrlZh'] != null) urlsToDelete.add(oldData['contractUrlZh']);
      if (oldData['contractUrlEn'] != null) urlsToDelete.add(oldData['contractUrlEn']);

      final storage = FirebaseStorage.instance;

      // ✅ 2. 上传房东签名图片 (用于存档)
      await storage.ref().child('signatures/${widget.docId}_landlord.png').putData(_mySignatureBytes!);

      // ✅ 3. 生成并上传 【中文最终版】
      File zhPdf = await _generateFinalPdfFile('zh', _mySignatureBytes!);
      // 加个时间戳后缀防止覆盖缓存问题
      String timeSuffix = DateTime.now().millisecondsSinceEpoch.toString();
      String zhPath = 'contracts/${widget.docId}_final_zh_$timeSuffix.pdf';
      await storage.ref().child(zhPath).putFile(zhPdf);
      String zhUrl = await storage.ref().child(zhPath).getDownloadURL();

      // ✅ 4. 生成并上传 【英文最终版】
      File enPdf = await _generateFinalPdfFile('en', _mySignatureBytes!);
      String enPath = 'contracts/${widget.docId}_final_en_$timeSuffix.pdf';
      await storage.ref().child(enPath).putFile(enPdf);
      String enUrl = await storage.ref().child(enPath).getDownloadURL();

      // ✅ 5. 决定主显示链接
      String mainUrl = _currentLanguage == 'zh' ? zhUrl : enUrl;

      // ✅ 6. 更新 Firestore 状态
      await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
        'status': 'awaiting_payment',      // 状态流转到等待付款
        'contractUrl': mainUrl,            // 主链接
        'contractUrlZh': zhUrl,            // 备份链接 (中文)
        'contractUrlEn': enUrl,            // 备份链接 (英文)
        'landlordSignedAt': Timestamp.now(),
        'isReadByTenant': false,           // 通知租客
      });

      // ✅ 7. 🔥 清理旧文件 (核心新功能)
      print("Starting cleanup of old contract files...");
      for (String url in urlsToDelete) {
        // 只有当旧 URL 和新 URL 不一样时才删 (防止误删)
        if (url != zhUrl && url != enUrl) {
          try {
            await storage.refFromURL(url).delete();
            print("Deleted old file: $url");
          } catch (e) {
            print("Could not delete file (maybe already gone): $e");
          }
        }
      }
      
      // 尝试清理可能存在的租客中间态文件
      try {
         await storage.ref().child('contracts/${widget.docId}_tenant_signed.pdf').delete();
      } catch (e) { /* Ignore */ }

      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contract Finalized & Old drafts cleaned!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
       print("Upload error: $e");
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e")));
    } finally {
      if(mounted) setState(() => _isUploading = false);
    }
  }

  // 辅助：生成特定语言的 PDF 文件对象
  Future<File> _generateFinalPdfFile(String lang, Uint8List landlordBytes) async {
    String startStr = ""; String endStr = ""; String paymentDay = "1";
    if (_cachedData!['leaseStartDate'] != null) {
       DateTime s = (_cachedData!['leaseStartDate'] as Timestamp).toDate();
       startStr = "${s.year}-${s.month}-${s.day}"; paymentDay = "${s.day}";
    }
    if (_cachedData!['leaseEndDate'] != null) {
       DateTime e = (_cachedData!['leaseEndDate'] as Timestamp).toDate();
       endStr = "${e.year}-${e.month}-${e.day}";
    }

    return await ContractGenerator.generateAndSaveContract(
      landlordName: _cachedData!['landlordName'],
      tenantName: _cachedData!['tenantName'],
      propertyAddress: _cachedData!['address'],
      rentAmount: _cachedData!['rent'],
      startDate: startStr,
      endDate: endStr,
      paymentDay: paymentDay,
      language: lang,
      tenantSignature: _tenantSignatureBytes, // 包含租客签名
      landlordSignature: landlordBytes,       // 包含房东签名
    );
  }

  // ==========================================
  // 5. UI 构建
  // ==========================================
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
        actions: [
          // 语言切换按钮 (仅在非上传状态显示)
          if (!_isUploading) 
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton.icon(
                onPressed: _toggleLanguage,
                icon: const Icon(Icons.language, color: Colors.white, size: 18),
                label: Text(_currentLanguage == 'zh' ? 'EN' : '中文', 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            )
        ],
      ),
      body: Stack(
        children: [
          // 背景渐变
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
                : _errorMessage != null 
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                      ))
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
                                    // 状态栏条
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                      color: Colors.black12,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.description, color: Colors.white70, size: 16),
                                              const SizedBox(width: 8),
                                              Text(
                                                _isPreviewMode 
                                                  ? (_currentLanguage == 'zh' ? "最终预览 (双签生效)" : "Final Version (Both Signed)")
                                                  : (_currentLanguage == 'zh' ? "当前版本 (等待房东签字)" : "Draft Version (Waiting for Landlord)"),
                                                style: const TextStyle(color: Colors.white70, fontSize: 12)
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // PDF 视图
                                    Expanded(
                                      child: _currentDisplayPdfPath != null 
                                        ? PDFView(
                                            key: Key(_currentDisplayPdfPath! + _currentLanguage + _isPreviewMode.toString()), 
                                            filePath: _currentDisplayPdfPath,
                                            enableSwipe: true,
                                            swipeHorizontal: false,
                                            autoSpacing: true,
                                            pageFling: true,
                                            backgroundColor: Colors.grey[200],
                                            onError: (e) => print("PDF Load Error: $e"),
                                          )
                                        : const Center(child: Text("Generating PDF...", style: TextStyle(color: Colors.white))),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // --- 底部交互区域 ---
                          if (_isPreviewMode)
                            // 模式 A: 确认上传
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    _currentLanguage == 'zh'
                                      ? "请确认合同内容，提交后将立即生效。"
                                      : "Please review. The contract becomes effective immediately upon submission.",
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    textAlign: TextAlign.center,
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
                                            child: Text(_currentLanguage == 'zh' ? "重新签字" : "Re-sign"),
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
                                              : Text(
                                                  _currentLanguage == 'zh' ? "确认并生效" : "Finalize Contract", 
                                                  style: const TextStyle(fontWeight: FontWeight.bold)
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            // 模式 B: 签字板
                            Column(
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E2D33).withOpacity(0.9),
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
                                            const Icon(Icons.edit, color: Colors.white, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              _currentLanguage == 'zh' ? "房东签字区域" : "Landlord Signature Area", 
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                            ),
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
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.visibility, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            _currentLanguage == 'zh' ? "预览带签名合同" : "Preview with Signature", 
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                          ),
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
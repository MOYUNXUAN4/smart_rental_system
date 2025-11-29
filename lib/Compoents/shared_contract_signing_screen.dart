import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_pdfview/flutter_pdfview.dart';

// ⚠️ 确保路径拼写与你项目一致
import '../Compoents/contract_generator.dart'; 

class SharedContractSigningScreen extends StatefulWidget {
  final String docId;
  final bool isLandlord; // ✅ 核心参数：区分租客还是房东

  const SharedContractSigningScreen({
    super.key,
    required this.docId,
    required this.isLandlord,
  });

  @override
  State<SharedContractSigningScreen> createState() => _SharedContractSigningScreenState();
}

class _SharedContractSigningScreenState extends State<SharedContractSigningScreen> {
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3.0,
    penColor: const Color(0xFF0D47A1),
    exportBackgroundColor: Colors.transparent,
  );

  // 状态变量
  String? _currentDisplayPdfPath; 
  File? _generatedPdfFile; // 系统生成的带签名 PDF
  Uint8List? _mySignatureBytes; // 当前用户的签名
  Uint8List? _tenantSignatureBytes; // (房东模式用) 租客的旧签名
  
  bool _isLoading = true;
  bool _isPreviewMode = false;
  bool _isUploading = false;
  String? _errorMessage;

  // 语言控制
  String _currentLanguage = 'zh'; 
  
  // 数据缓存
  Map<String, dynamic>? _cachedData;
  bool _isCustomContract = false; // ✅ 标记是否为房东手动上传的合同

  @override
  void initState() {
    super.initState();
    _initialFetch();
  }

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. 初始化数据 (区分角色和合同类型)
  // ==========================================
  Future<void> _initialFetch() async {
    setState(() => _isLoading = true);
    try {
      // 1. 获取 Booking 数据
      final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).get();
      if (!bookingDoc.exists) throw Exception("Booking not found");
      final bookingData = bookingDoc.data() as Map<String, dynamic>;

      // 2. 获取 Property 数据 (判断是否为自定义合同)
      final String propertyId = bookingData['propertyId'];
      final propertyDoc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      final propertyData = propertyDoc.data() ?? {};

      // ✅ 检查是否使用系统合同 (默认为 true，除非明确标记为 false 或手动上传了且没标记)
      // 在 AddPropertyScreen 我们存了 useSystemContract 字段
      _isCustomContract = propertyData['useSystemContract'] == false;

      // 3. 如果是房东，需要下载租客的签名
      if (widget.isLandlord) {
        try {
          final pngRef = FirebaseStorage.instance.ref().child('signatures/${widget.docId}_tenant.png');
          _tenantSignatureBytes = await pngRef.getData(5 * 1024 * 1024);
        } catch (e) {
          print("Tenant signature not found: $e");
        }
      }

      // 4. 准备生成所需的文字数据 (如果是系统合同)
      if (!_isCustomContract) {
        await _prepareSystemContractData(bookingData, propertyData);
      } else {
        // 如果是自定义合同，直接下载原 PDF
        await _downloadOriginalPdf(bookingData['contractUrl']);
      }

    } catch (e) {
      print("Error: $e");
      if(mounted) setState(() {
        _isLoading = false;
        _errorMessage = "Init Failed: $e";
      });
    }
  }

  // 辅助：下载原始 PDF (自定义合同模式)
  Future<void> _downloadOriginalPdf(String? url) async {
    if (url == null) throw Exception("Contract URL is missing");
    final response = await http.get(Uri.parse(url));
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/original_${widget.docId}.pdf');
    await file.writeAsBytes(response.bodyBytes);
    
    if (mounted) {
      setState(() {
        _currentDisplayPdfPath = file.path;
        _isLoading = false;
      });
    }
  }

  // 辅助：准备系统合同数据
  Future<void> _prepareSystemContractData(Map<String, dynamic> bookingData, Map<String, dynamic> propertyData) async {
    final String tenantUid = bookingData['tenantUid'];
    final String? landlordUid = bookingData['landlordUid'];

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

    // 渲染初始 PDF
    await _renderSystemPdf();
  }

  // ==========================================
  // 2. 渲染系统 PDF (调用 Generator)
  // ==========================================
  Future<void> _renderSystemPdf() async {
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

    // 决定传入哪些签名
    // 租客模式：传 _mySignatureBytes (如果是预览)
    // 房东模式：传 _tenantSignatureBytes + _mySignatureBytes (如果是预览)
    Uint8List? tSig;
    Uint8List? lSig;

    if (widget.isLandlord) {
      tSig = _tenantSignatureBytes; // 房东总是能看到租客签名
      lSig = _mySignatureBytes;     // 房东自己的签名
    } else {
      tSig = _mySignatureBytes;     // 租客自己的签名
      lSig = null;                  // 租客看不到房东签名
    }

    final File pdfFile = await ContractGenerator.generateAndSaveContract(
      landlordName: _cachedData!['landlordName'],
      tenantName: _cachedData!['tenantName'],
      propertyAddress: _cachedData!['address'],
      rentAmount: _cachedData!['rent'],
      startDate: startStr,
      endDate: endStr,
      paymentDay: paymentDay,
      language: _currentLanguage, // ✅ 动态语言
      tenantSignature: tSig,
      landlordSignature: lSig,
    );

    if (mounted) {
      setState(() {
        _currentDisplayPdfPath = pdfFile.path;
        if (_isPreviewMode) _generatedPdfFile = pdfFile; // 预览模式下保存生成的文件用于上传
        _isLoading = false;
        _errorMessage = null;
      });
    }
  }

  // ==========================================
  // 3. 用户交互逻辑
  // ==========================================
  
  void _onLanguageChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        _currentLanguage = newValue;
        _isLoading = true;
      });
      // 只有系统合同才需要重新渲染
      if (!_isCustomContract) _renderSystemPdf();
    }
  }

  Future<void> _generatePreview() async {
    if (_sigController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please sign first."), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);
    final signature = await _sigController.toPngBytes();
    
    if (signature != null) {
      _mySignatureBytes = signature;
      
      if (_isCustomContract) {
        // ✅ 自定义合同逻辑：
        // 我们不生成新 PDF，只是进入预览模式。
        // 这里为了简单，预览时还是显示原 PDF，但在上传时我们会上传签名图。
        // 如果想要把签名“贴”上去，比较复杂。目前的逻辑是：显示原件 -> 确认 -> 上传签名图。
        if (mounted) setState(() {
          _isPreviewMode = true;
          _isLoading = false;
        });
      } else {
        // ✅ 系统合同逻辑：重新渲染带签名的 PDF
        await _renderSystemPdf();
        if (mounted) setState(() => _isPreviewMode = true);
      }
    }
  }

  void _resetToSigning() {
    setState(() {
      _sigController.clear();
      _mySignatureBytes = null;
      _isPreviewMode = false;
      _generatedPdfFile = null;
      _isLoading = !_isCustomContract; // 如果是系统合同，需要重新渲染无签名版
    });
    if (!_isCustomContract) _renderSystemPdf();
  }

  // ==========================================
  // 4. 最终上传逻辑
  // ==========================================
  Future<void> _uploadAndFinish() async {
    setState(() => _isUploading = true);
    try {
      final storage = FirebaseStorage.instance;
      
      // 1. 始终上传当前用户的签名图片 (供另一方或存档使用)
      String sigFileName = widget.isLandlord ? '${widget.docId}_landlord.png' : '${widget.docId}_tenant.png';
      if (_mySignatureBytes != null) {
        await storage.ref().child('signatures/$sigFileName').putData(_mySignatureBytes!);
      }

      String mainContractUrl = "";

      // 2. 处理合同文件上传
      if (_isCustomContract) {
        // ✅ 自定义合同：不生成新 PDF，沿用原来的 URL，只更新状态
        // 实际上，我们应该把签名的状态写进去。
        // 既然是自定义 PDF，我们无法在客户端轻易修改它。
        // 所以我们保留原链接，但更新状态。
        final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).get();
        mainContractUrl = bookingDoc.data()?['contractUrl'] ?? "";
      } else {
        // ✅ 系统合同：生成并上传 (双语)
        // 只有在房东复签时，或者租客签字时，我们才上传生成的 PDF
        if (_generatedPdfFile != null) {
           // 这里简单起见，上传当前生成的文件。
           // 如果需要严格的双语后台存档，可以在这里调用 _generateFileForUpload('zh') 和 'en'
           // 既然是通用组件，我们上传当前用户看到的版本作为主版本
           String suffix = widget.isLandlord ? 'final' : 'signed';
           await storage.ref().child('contracts/${widget.docId}_${suffix}_$_currentLanguage.pdf').putFile(_generatedPdfFile!);
           mainContractUrl = await storage.ref().child('contracts/${widget.docId}_${suffix}_$_currentLanguage.pdf').getDownloadURL();
        }
      }

      // 3. 更新 Firestore 状态
      Map<String, dynamic> updateData = {};
      if (widget.isLandlord) {
        // 房东签完 -> 等待付款
        updateData = {
          'status': 'awaiting_payment',
          'contractUrl': mainContractUrl,
          'landlordSignedAt': Timestamp.now(),
          'isReadByTenant': false,
        };
      } else {
        // 租客签完 -> 房东复签
        updateData = {
          'status': 'tenant_signed',
          'contractUrl': mainContractUrl,
          'tenantSignedAt': Timestamp.now(),
          'isReadByLandlord': false,
        };
      }

      await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update(updateData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isLandlord ? "Contract Finalized!" : "Signed Successfully!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if(mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: $e")));
      }
    }
  }

  // ==========================================
  // 5. UI 构建
  // ==========================================
  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1D5DC7);
    const Color glassBorder = Colors.white24;

    String title = widget.isLandlord 
        ? (_isPreviewMode ? "Final Review" : "Landlord Signature")
        : (_isPreviewMode ? "Review Contract" : "Sign Contract");

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // ✅ 只有系统生成的合同才显示语言切换，且只有在未上传时
          if (!_isCustomContract && !_isUploading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Theme(
                data: Theme.of(context).copyWith(canvasColor: const Color(0xFF295a68)), // 下拉菜单背景色
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _currentLanguage,
                    icon: const Icon(Icons.language, color: Colors.white),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    onChanged: _onLanguageChanged,
                    items: const [
                      DropdownMenuItem(value: 'zh', child: Text("中文")),
                      DropdownMenuItem(value: 'en', child: Text("English")),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
                stops: [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _errorMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent))))
                  : Column(
                      children: [
                        // --- PDF 区域 ---
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
                              child: _currentDisplayPdfPath != null 
                                ? PDFView(
                                    key: Key(_currentDisplayPdfPath! + _currentLanguage + _isPreviewMode.toString()), 
                                    filePath: _currentDisplayPdfPath,
                                    enableSwipe: true,
                                    swipeHorizontal: false,
                                    autoSpacing: true,
                                    pageFling: true,
                                    backgroundColor: Colors.grey[200],
                                    onError: (e) => print("PDF Error: $e"),
                                  )
                                : const Center(child: Text("No PDF loaded", style: TextStyle(color: Colors.white))),
                            ),
                          ),
                        ),

                        // --- 交互区域 ---
                        if (_isPreviewMode)
                          // 预览确认模式
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  _isCustomContract 
                                    ? "Confirm your signature."
                                    : (_currentLanguage == 'zh' ? "请确认合同内容。" : "Please review the document."),
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(height: 55, child: OutlinedButton(
                                        onPressed: _isUploading ? null : _resetToSigning,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(color: Colors.white70),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        child: Text(_currentLanguage == 'zh' ? "重签" : "Re-sign"),
                                      )),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: SizedBox(height: 55, child: ElevatedButton(
                                        onPressed: _isUploading ? null : _uploadAndFinish,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        child: _isUploading
                                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Text(widget.isLandlord ? "Finalize" : (_currentLanguage == 'zh' ? "确认提交" : "Confirm"), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      )),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          // 签字模式
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
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.draw, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            widget.isLandlord ? "Landlord Signature" : (_currentLanguage == 'zh' ? "请在此处签名" : "Your Signature"), 
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
                                          height: 160, color: Colors.white,
                                          child: Stack(
                                            children: [
                                              const Center(child: Text("Sign Here", style: TextStyle(color: Color(0xFFEEEEEE), fontSize: 40, fontWeight: FontWeight.bold))),
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
                                  width: double.infinity, height: 55,
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
                                        Text(_currentLanguage == 'zh' ? "预览带签名" : "Preview with Signature", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
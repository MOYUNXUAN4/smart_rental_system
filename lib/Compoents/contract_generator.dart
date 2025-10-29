import 'dart:io';
import 'package.flutter/services.dart';
import 'package:flutter/services.dart'; // <-- Add this line
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
// 确保您已将 open_file 添加到 pubspec.yaml
import 'package:open_file/open_file.dart';

class ContractGenerator {
  static Future<void> generateAndOpenContract({
    required String landlordName,
    required String tenantName,
    required String propertyAddress,
    required String rentAmount,
    required String startDate,
    required String endDate,
    required String language, // 'zh' 或 'en'
  }) async {
    final pdf = pw.Document();
    late pw.Font ttf; // 将 ttf 声明提到 try 块外部

    // --- 调试字体加载 ---
    try {
      print("[DEBUG] Attempting to load font: 'assets/images/fonts/NotoSansSC-Regular.ttf'"); // <-- 调试点 1
      final fontData = await rootBundle.load('assets/images/fonts/NotoSansSC-Regular.ttf');
      print("[DEBUG] Font data loaded, size: ${fontData.lengthInBytes} bytes"); // <-- 调试点 2

      // 添加一个简单的检查，字体文件通常大于 10KB (10000 bytes)
      if (fontData.lengthInBytes < 10000) { 
        print("[WARNING] Font data size seems too small! Check if the file is corrupted or path is correct in pubspec.yaml");
      }

      ttf = pw.Font.ttf(fontData);
      print("[DEBUG] Font object created successfully from loaded data."); // <-- 调试点 3

    } catch (e) {
      print("[ERROR] Failed to load or process font: $e"); // <-- 调试点 4 (错误捕获)
      print("[INFO] Falling back to default font (Helvetica). Chinese characters will likely be garbled.");
      // 如果字体加载失败，使用默认字体 (会导致中文乱码，但至少能生成 PDF)
      ttf = pw.Font.helvetica(); 
    }
    // --- 调试结束 ---


    String contractContent = language == 'zh'
        ? '''
租赁合同

出租方（甲方）：$landlordName
承租方（乙方）：$tenantName

房产地址：$propertyAddress
租金：$rentAmount 元/月
起始日期：$startDate
结束日期：$endDate

双方签字：
甲方：________
乙方：________
'''
        : '''
Rental Contract

Landlord: $landlordName
Tenant: $tenantName

Property Address: $propertyAddress
Rent: $rentAmount per month
Start Date: $startDate
End Date: $endDate

Signatures:
Landlord: ________
Tenant: ________
''';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        // 使用 theme 来确保字体应用到所有 Text Widget
        theme: pw.ThemeData.withFont(base: ttf), // 使用加载的 ttf 字体
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Text(
              contractContent,
              // 注意：这里可以省略 style，因为它会继承 theme
              // 如果需要特定样式，可以这样写: style: pw.TextStyle(fontSize: 14), 
            ),
          );
        },
      ),
    );

    // 保存并打开文件的逻辑保持不变
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/contract_${DateTime.now().millisecondsSinceEpoch}.pdf'; // 添加时间戳避免覆盖
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      print("[INFO] PDF saved successfully to: $filePath"); // <-- 打印保存路径

      // 使用 open_file 打开
      final result = await OpenFile.open(file.path);
      print("[INFO] OpenFile result: type=${result.type}, message=${result.message}"); // <-- 打印打开结果

    } catch(e) {
       print("[ERROR] Failed to save or open PDF: $e"); // <-- 捕获保存/打开错误
       // (可选) 在这里显示一个错误提示给用户
    }
  }
}
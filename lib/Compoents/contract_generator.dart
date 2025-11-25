// lib/Compoents/contract_generator.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class ContractGenerator {
  static Future<File> generateAndSaveContract({
    required String landlordName,
    String? tenantName,
    required String propertyAddress,
    required String rentAmount,
    String? startDate,
    String? endDate,
    required String language, // 'zh' 或 'en'
  }) async {
    final pdf = pw.Document();
    late pw.Font ttf; 

    try {
      // (您的调试逻辑保持不变)
      print("[DEBUG] Attempting to load font: 'assets/images/fonts/NotoSansSC-Regular.ttf'");
      final fontData = await rootBundle.load('assets/images/fonts/NotoSansSC-Regular.ttf');
      print("[DEBUG] Font data loaded, size: ${fontData.lengthInBytes} bytes");
      if (fontData.lengthInBytes < 10000) { 
        print("[WARNING] Font data size seems too small!");
      }
      ttf = pw.Font.ttf(fontData);
      print("[DEBUG] Font object created successfully from loaded data.");
    } catch (e) {
      print("[ERROR] Failed to load or process font: $e");
      print("[INFO] Falling back to default font (Helvetica).");
      ttf = pw.Font.helvetica(); 
    }

    String contractContent = language == 'zh'
        ? '''
租赁合同

出租方（甲方）：$landlordName
承租方（乙方）：${tenantName ?? '________________'}

房产地址：$propertyAddress
租金：$rentAmount 元/月
起始日期：${startDate ?? '____/____/____'}
结束日期：${endDate ?? '____/____/____'}

双方签字：
甲方：________
乙方：________
'''
        : '''
Rental Contract

Landlord: $landlordName
Tenant: ${tenantName ?? '________________'}

Property Address: $propertyAddress
Rent: $rentAmount per month
Start Date: ${startDate ?? '____/____/____'}
End Date: ${endDate ?? '____/____/____'}

Signatures:
Landlord: ________
Tenant: ________
''';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf), 
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Text(contractContent),
          );
        },
      ),
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/contract_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      print("[INFO] PDF saved successfully to: $filePath");


      return file;

    } catch(e) {
      print("[ERROR] Failed to save PDF: $e");
      throw Exception('Failed to save PDF: $e'); 
    }
  }
}
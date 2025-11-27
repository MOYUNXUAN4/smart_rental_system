import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class ContractGenerator {
  static Future<File> generateAndSaveContract({
    required String landlordName,
    required String tenantName,
    required String propertyAddress,
    required String rentAmount,
    required String startDate,
    required String endDate,
    required String paymentDay,
    required String language, // 'zh' or 'en'
  }) async {
    final pdf = pw.Document();
    late pw.Font ttf; 

    // 1. 加载字体 (中文必须加载 NotoSansSC，否则乱码)
    try {
      // 请确保 pubspec.yaml 声明了该字体，且文件存在
      final fontData = await rootBundle.load('assets/images/fonts/NotoSansSC-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
    } catch (e) {
      print("Error loading font: $e");
      // 如果加载失败，回退到标准字体 (中文会不显示)
      ttf = pw.Font.helvetica(); 
    }

    // 2. 判断语言
    final bool isZh = language == 'zh';

    // 3. 构建页面
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf), // 应用字体
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- 标题 ---
              pw.Center(
                child: pw.Text(
                  isZh ? "房屋租赁合同" : "RESIDENTIAL RENTAL AGREEMENT", 
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)
                )
              ),
              pw.SizedBox(height: 20),
              
              pw.Text(
                isZh ? "本协议由以下双方于今日签订：" : "This Agreement is made on this day between:", 
                style: const pw.TextStyle(fontSize: 12)
              ),
              pw.SizedBox(height: 10),
              
              // --- 双方信息 ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(
                      isZh ? "出租方 (甲方):" : "LANDLORD (Party A):", 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
                    ),
                    pw.Text(landlordName, style: const pw.TextStyle(fontSize: 14)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(
                      isZh ? "承租方 (乙方):" : "TENANT (Party B):", 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
                    ),
                    pw.Text(tenantName, style: const pw.TextStyle(fontSize: 14)),
                  ]),
                ]
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // --- 1. 房产详情 ---
              pw.Text(
                isZh ? "1. 房产详情" : "1. PROPERTY DETAILS", 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
              ),
              pw.Text(
                isZh ? "地址: $propertyAddress" : "Address: $propertyAddress"
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                isZh ? "月租金: RM $rentAmount" : "Monthly Rent: RM $rentAmount"
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                isZh ? "付款日: 每月 $paymentDay 日" : "Payment Due Date: Day $paymentDay of every month"
              ),
              
              pw.SizedBox(height: 20),

              // --- 2. 租赁期限 ---
              pw.Text(
                isZh ? "2. 租赁期限" : "2. LEASE TERM", 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
              ),
              pw.Row(
                children: [
                  pw.Text(isZh ? "起: $startDate" : "From: $startDate"),
                  pw.SizedBox(width: 30),
                  pw.Text(isZh ? "止: $endDate" : "To: $endDate"),
                ]
              ),
              
              pw.SizedBox(height: 20),
              
              // --- 3. 条款 (简略示例) ---
              pw.Text(
                isZh ? "3. 其他条款" : "3. TERMS & CONDITIONS", 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
              ),
              pw.Bullet(
                text: isZh 
                  ? "乙方应按时支付租金。" 
                  : "The Tenant agrees to pay the rent on time."
              ),
              pw.Bullet(
                text: isZh 
                  ? "未经甲方同意，乙方不得转租。" 
                  : "The Tenant shall not sublet without Landlord's consent."
              ),
              
              pw.SizedBox(height: 40),

              // --- 签字区 ---
              pw.Text(
                isZh ? "签字确认" : "SIGNATURES", 
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
              ),
              pw.SizedBox(height: 50),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 5),
                    pw.Text(isZh ? "出租方签字" : "Landlord Signature"),
                  ]),
                  pw.Column(children: [
                    pw.Container(width: 120, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 5),
                    pw.Text(isZh ? "承租方签字" : "Tenant Signature"),
                  ]),
                ]
              ),
              
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  "Generated by Smart Rental System", 
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)
                )
              ),
            ],
          );
        },
      ),
    );

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/contract_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch(e) {
      throw Exception('Failed to save PDF: $e'); 
    }
  }
}
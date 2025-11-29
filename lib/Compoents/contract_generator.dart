import 'dart:io';
import 'dart:typed_data';
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
    Uint8List? tenantSignature,
    Uint8List? landlordSignature,
  }) async {
    
    // -----------------------------
    // 1. 加载中文字体（Regular + Bold）
    // -----------------------------
    final fontRegular = pw.Font.ttf(
      await rootBundle.load("assets/images/fonts/NotoSansSC-Regular.ttf"),
    );

    final fontBold = pw.Font.ttf(
      await rootBundle.load("assets/images/fonts/NotoSansSC-Bold.ttf"),
    );

    final pdf = pw.Document();

    // 设置 PDF 字体主题
    final theme = pw.ThemeData.withFont(
      base: fontRegular,  // 正文字体
      bold: fontBold,     // 粗体
    );

    final bool isZh = language == "zh";

    // -----------------------------
    // 2. 构建 PDF 页面
    // -----------------------------
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              
              pw.Center(
                child: pw.Text(
                  isZh ? "房屋租赁合同" : "RESIDENTIAL RENTAL AGREEMENT",
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                isZh ? "本协议由以下双方于今日签订：" : "This Agreement is made on this day between:",
                style: pw.TextStyle(fontSize: 12),
              ),

              pw.SizedBox(height: 10),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isZh ? "出租方 (甲方):" : "LANDLORD (Party A):",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(landlordName),
                    ],
                  ),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        isZh ? "承租方 (乙方):" : "TENANT (Party B):",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(tenantName),
                    ],
                  ),
                ],
              ),

              pw.Divider(),
              pw.SizedBox(height: 10),

              pw.Text(
                isZh ? "1. 房产详情" : "1. PROPERTY DETAILS",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(isZh ? "地址: $propertyAddress" : "Address: $propertyAddress"),
              pw.Text(isZh ? "月租金: RM $rentAmount" : "Monthly Rent: RM $rentAmount"),
              pw.Text(isZh ? "付款日: 每月 $paymentDay 日" : "Payment Day: $paymentDay"),

              pw.SizedBox(height: 20),

              pw.Text(
                isZh ? "2. 租赁期限" : "2. LEASE TERM",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(isZh ? "起: $startDate    止: $endDate" : "From: $startDate    To: $endDate"),

              pw.SizedBox(height: 20),

              pw.Text(
                isZh ? "3. 其他条款" : "3. TERMS & CONDITIONS",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Bullet(
                text: isZh ? "乙方应按时支付租金。" : "Tenant must pay rent on time.",
              ),
              pw.Bullet(
                text: isZh ? "未经甲方同意，乙方不得转租。" : "Subletting is not allowed.",
              ),

              pw.SizedBox(height: 40),

              pw.Text(
                isZh ? "签字确认" : "SIGNATURES",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),

              pw.SizedBox(height: 40),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // 房东
                  pw.Column(
                    children: [
                      landlordSignature != null
                          ? pw.Container(
                              width: 120,
                              height: 50,
                              child: pw.Image(pw.MemoryImage(landlordSignature)),
                            )
                          : pw.SizedBox(height: 50),
                      pw.Container(width: 120, height: 1, color: PdfColors.black),
                      pw.Text(isZh ? "出租方签字" : "Landlord Signature"),
                    ],
                  ),

                  // 租客
                  pw.Column(
                    children: [
                      tenantSignature != null
                          ? pw.Container(
                              width: 120,
                              height: 50,
                              child: pw.Image(pw.MemoryImage(tenantSignature)),
                            )
                          : pw.SizedBox(height: 50),
                      pw.Container(width: 120, height: 1, color: PdfColors.black),
                      pw.Text(isZh ? "承租方签字" : "Tenant Signature"),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // -----------------------------
    // 3. 保存 PDF
    // -----------------------------
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/contract_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}

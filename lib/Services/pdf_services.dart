import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

class PdfService {
  /// language: "en" 或 "zh"
  static Future<Uint8List> generateContract({
    required String landlordName,
    required String tenantName,
    required String propertyName,
    required String furnishingStatus,
    required String rentalPeriod,
    required double price,
    required double size,
    required Map<String, int> features, // e.g. {"Air Conditioner": 3}
    required String language,
    Uint8List? landlordSignature,
    Uint8List? tenantSignature,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final isChinese = language == "zh";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  isChinese ? '房屋租赁合同' : 'Property Rental Agreement',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('${isChinese ? "合同日期" : "Contract Date"}: $date'),
              pw.SizedBox(height: 24),
              pw.Text(
                isChinese ? "房产信息 / Property Information" : "Property Information",
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(),
              pw.Text("${isChinese ? "房产名称" : "Property Name"}: $propertyName"),
              pw.Text("${isChinese ? "面积" : "Size"}: ${size.toStringAsFixed(1)} ㎡"),
              pw.Text("${isChinese ? "装修状态" : "Furnishing"}: $furnishingStatus"),
              pw.Text("${isChinese ? "月租金" : "Monthly Rent"}: RM${price.toStringAsFixed(2)}"),
              pw.Text("${isChinese ? "租期" : "Rental Period"}: $rentalPeriod"),
              pw.SizedBox(height: 20),

              pw.Text(
                isChinese ? "房屋特征 / Features" : "Property Features",
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: features.entries
                    .map((e) => pw.Text("${e.key}: ${e.value}"))
                    .toList(),
              ),
              pw.SizedBox(height: 40),

              pw.Text(
                isChinese ? "签名 / Signatures" : "Signatures",
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildSignatureBox(isChinese ? "房东签名" : "Landlord Signature", landlordName, landlordSignature),
                  _buildSignatureBox(isChinese ? "租户签名" : "Tenant Signature", tenantName, tenantSignature),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSignatureBox(String title, String name, Uint8List? image) {
    return pw.Container(
      width: 200,
      height: 120,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1, color: PdfColors.grey),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 8),
          if (image != null)
            pw.Image(pw.MemoryImage(image), width: 120, height: 60)
          else
            pw.Container(
              width: 120,
              height: 60,
              alignment: pw.Alignment.center,
              child: pw.Text('No Signature'),
            ),
          pw.SizedBox(height: 4),
          pw.Text(name, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;

  const ReceiptScreen({super.key, required this.bookingData, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    // 解析数据
    final double amount = double.tryParse(bookingData['price']?.toString() ?? '0') ?? 0.0;
    final Timestamp? payTime = bookingData['paymentDate'];
    final String dateStr = payTime != null 
        ? DateFormat('yyyy-MM-dd HH:mm').format(payTime.toDate()) 
        : 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFF0E1C22), // 极光深色背景
      appBar: AppBar(
        title: const Text("Payment Receipt"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 收据卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 60),
                    const SizedBox(height: 16),
                    const Text("Payment Successful", style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("RM ${amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildRow("Date", dateStr),
                    _buildRow("Transaction ID", bookingId.substring(0, 8).toUpperCase()),
                    _buildRow("Item", "Rental Deposit & First Month"),
                    _buildRow("Status", "Paid"),
                    const SizedBox(height: 24),
                    // 虚线效果 (用 Divider 代替)
                    const Divider(color: Colors.grey, thickness: 1, indent: 10, endIndent: 10),
                    const SizedBox(height: 16),
                    const Text("Thank you for your payment!", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // 返回按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B09B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Close", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
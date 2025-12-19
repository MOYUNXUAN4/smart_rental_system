import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceiptScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final String bookingId;

  const ReceiptScreen({super.key, required this.bookingData, required this.bookingId});

  @override
  Widget build(BuildContext context) {
    // 1. 解析基础数据
    final double amount = double.tryParse(bookingData['rentAmount']?.toString() ?? bookingData['price']?.toString() ?? '0') ?? 0.0;
    final Timestamp? payTime = bookingData['paymentDate'] ?? bookingData['lastPaymentDate'];
    final String propertyId = bookingData['propertyId'] ?? '';

    // 2. 处理日期字符串
    final String dateStr = payTime != null 
        ? DateFormat('yyyy-MM-dd HH:mm').format(payTime.toDate()) 
        : 'Unknown';

    // 3. 🔥🔥🔥 计算是哪个月的房租 (Billing Period) 🔥🔥🔥
    // 逻辑：通常支付时间所在的月份就是房租月份 (或者你可以根据 leaseStartDate 计算)
    final String billingPeriod = payTime != null 
        ? DateFormat('MMMM yyyy').format(payTime.toDate()) // 例如: December 2025
        : 'Unknown Period';

    return Scaffold(
      backgroundColor: const Color(0xFF0E1C22), // 极光深色背景
      appBar: AppBar(
        title: const Text("Payment Receipt", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
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
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                  ],
                ),
                child: Column(
                  children: [
                    // 顶部图标
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    ),
                    const SizedBox(height: 16),
                    const Text("Payment Successful", style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    // 金额显示
                    Text("RM ${amount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.black, fontSize: 36, fontWeight: FontWeight.w900)),
                    
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // 🔥 房源名称 (异步获取)
                    _buildAsyncPropertyRow(propertyId),

                    // 🔥 账单周期 (Rent for Month)
                    _buildRow("Billing Period", "Rent for $billingPeriod", isHighlight: true),

                    _buildRow("Payment Date", dateStr),
                    _buildRow("Transaction ID", bookingId.substring(0, 8).toUpperCase()),
                    _buildRow("Payment Method", "Online Transfer"), // 或者是 FPX / Card
                    
                    const SizedBox(height: 10),
                    _buildStatusRow("Status", "PAID"),

                    const SizedBox(height: 24),
                    // 锯齿状或虚线分割线视觉效果
                    Row(
                      children: List.generate(150 ~/ 5, (index) => Expanded(
                        child: Container(
                          color: index % 2 == 0 ? Colors.transparent : Colors.grey[300],
                          height: 2,
                        ),
                      )),
                    ),
                    const SizedBox(height: 16),
                    const Text("Thank you for using Smart Rental!", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              // 关闭按钮
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B09B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 5,
                  ),
                  child: const Text("Done", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 普通行构建器
  Widget _buildRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value, 
            style: TextStyle(
              color: isHighlight ? const Color(0xFF00B09B) : Colors.black87, 
              fontSize: 14, 
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600
            )
          ),
        ],
      ),
    );
  }

  // 状态行构建器
  Widget _buildStatusRow(String label, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green, width: 0.5)
            ),
            child: Text(status, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🔥 异步获取房产名称的行
  Widget _buildAsyncPropertyRow(String propertyId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Property", style: TextStyle(color: Colors.grey, fontSize: 13)),
          // 使用 FutureBuilder 动态获取名字
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('properties').doc(propertyId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1));
              }
              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return const Text("Unknown Property", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600));
              }
              
              final data = snapshot.data!.data() as Map<String, dynamic>;
              // 优先显示小区名，没有则显示标题
              final String name = data['communityName'] ?? data['title'] ?? 'Rental Unit';

              return Flexible( // 防止名字太长溢出
                child: Text(
                  name, 
                  style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
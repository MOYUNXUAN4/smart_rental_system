// 在 lib/screens/ 目录下
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ignore: unused_import
import 'package:intl/intl.dart';

// ▼▼▼ 【修改】: 导入新的 BookingNotificationCard ▼▼▼
import '../Compoents/booking_notification_card.dart'; 
// ▲▲▲ 【修改】 ▲▲▲

class LandlordBookingsScreen extends StatefulWidget {
  const LandlordBookingsScreen({super.key});

  @override
  State<LandlordBookingsScreen> createState() => _LandlordBookingsScreenState();
}

class _LandlordBookingsScreenState extends State<LandlordBookingsScreen> {
  final String currentLandlordUid = FirebaseAuth.instance.currentUser!.uid;

  // 批准预约 (逻辑不变, 包含 'isReadByTenant': false)
  Future<void> _approveBooking(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status': 'approved',
            'isReadByTenant': false, 
          });
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking Approved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 拒绝预约 (逻辑不变, 包含 'isReadByTenant': false)
  Future<void> _rejectBooking(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status': 'rejected',
            'isReadByTenant': false, 
          });
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking Rejected'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF153a44),
              Color(0xFF295a68),
              Color(0xFF5d8fa0),
              Color(0xFF94bac4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Pending Bookings',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('landlordUid', isEqualTo: currentLandlordUid)
                      .where('status', isEqualTo: 'pending') 
                      .orderBy('requestedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      // 显示索引错误给用户，以便他们可以复制链接
                      if (snapshot.error.toString().contains("cloud_firestore/failed-precondition")) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Error: Firestore index required. Please check your debug console for the link to create it.",
                            style: const TextStyle(color: Colors.yellowAccent, fontSize: 16),
                          ),
                        );
                      }
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'You have no pending booking requests.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final bookingDoc = snapshot.data!.docs[index];
                        final bookingData = bookingDoc.data() as Map<String, dynamic>;
                        
                        // ▼▼▼ 【修改】: 使用新卡片并传入 showActions: true ▼▼▼
                        return BookingNotificationCard(
                          bookingData: bookingData,
                          onApprove: () => _approveBooking(bookingDoc.id),
                          onReject: () => _rejectBooking(bookingDoc.id),
                          showActions: true, // 👈 告诉卡片显示按钮
                        );
                        // ▲▲▲ 【修改】 ▲▲▲
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ▼▼▼ 【修改】: 整个 BookingNotificationCard 类已被删除 (因为它现在在自己的文件里) ▼▼▼
// (这个文件现在干净多了!)
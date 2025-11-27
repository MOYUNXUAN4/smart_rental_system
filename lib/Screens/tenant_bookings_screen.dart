import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ✅ 1. 导入新的智能组件
import '../Compoents/tenant_booking_card.dart'; 
import '../Compoents/glass_card.dart'; 

class TenantBookingsScreen extends StatefulWidget {
  const TenantBookingsScreen({super.key});

  @override
  State<TenantBookingsScreen> createState() => _TenantBookingsScreenState();
}

class _TenantBookingsScreenState extends State<TenantBookingsScreen> {
  final String currentTenantUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _markBookingsAsRead();
  }

  Future<void> _markBookingsAsRead() async {
    final query = FirebaseFirestore.instance
        .collection('bookings')
        .where('tenantUid', isEqualTo: currentTenantUid)
        .where('isReadByTenant', isEqualTo: false)
        .where('status', whereIn: ['approved', 'rejected']);

    final snapshot = await query.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isReadByTenant': true});
    }
    try {
      await batch.commit();
    } catch (e) {
      print("Error marking bookings as read: $e");
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.redAccent;
      case 'pending': return Colors.orangeAccent;
      case 'completed': return Colors.blueAccent;
      case 'application_pending': return Colors.purpleAccent;
      default: return Colors.white70;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.cancel;
      case 'pending': return Icons.hourglass_top;
      case 'completed': return Icons.task_alt;
      case 'application_pending': return Icons.assignment_ind;
      default: return Icons.info;
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
            colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4)],
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
                      'My Booking Status',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('tenantUid', isEqualTo: currentTenantUid)
                      .orderBy('requestedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No booking requests found.', style: TextStyle(color: Colors.white70)));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final bookingDoc = snapshot.data!.docs[index];
                        final bookingData = bookingDoc.data() as Map<String, dynamic>;
                        final docId = bookingDoc.id; // ✅ 获取 ID

                        // ✅ 2. 现在这里使用的是导入的智能组件，而不是文件底部定义的类
                        return TenantBookingCard(
                          bookingData: bookingData,
                          docId: docId, // 传入 ID
                          statusColor: _getStatusColor(bookingData['status'] ?? ''),
                          statusIcon: _getStatusIcon(bookingData['status'] ?? ''),
                        );
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
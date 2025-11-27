import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ✅ 引入刚刚新建的组件 (请确认拼写: Compoents 还是 Components)
import '../Compoents/landlord_booking_card.dart'; 

class LandlordBookingsScreen extends StatefulWidget {
  const LandlordBookingsScreen({super.key});

  @override
  State<LandlordBookingsScreen> createState() => _LandlordBookingsScreenState();
}

class _LandlordBookingsScreenState extends State<LandlordBookingsScreen> {
  final String currentLandlordUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bookings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 背景
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('landlordUid', isEqualTo: currentLandlordUid)
                  .orderBy('requestedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No bookings found.', style: TextStyle(color: Colors.white70)));
                }

                // 过滤：只显示需要处理的 (排除已拒绝和已完成)
                final docs = snapshot.data!.docs.where((doc) {
                  final status = doc['status'];
                  return status != 'rejected' && status != 'completed'; 
                }).toList();

                if (docs.isEmpty) {
                   return const Center(child: Text('No active tasks.', style: TextStyle(color: Colors.white70)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // ✅ 直接使用组件，无需传回调，组件自己处理
                    return LandlordBookingCard(
                      bookingData: data,
                      docId: doc.id,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
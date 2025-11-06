// 在 lib/screens/ 目录下
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ▼▼▼ 【修改】: 导入新的卡片 ▼▼▼
import '../Compoents/inbox_message_card.dart'; // 👈
import '../Compoents/meeting_card.dart';
// ▲▲▲ 【修改】 ▲▲▲

class LandlordInboxScreen extends StatefulWidget {
  const LandlordInboxScreen({super.key});

  @override
  State<LandlordInboxScreen> createState() => _LandlordInboxScreenState();
}

class _LandlordInboxScreenState extends State<LandlordInboxScreen> {
  final String currentLandlordUid = FirebaseAuth.instance.currentUser!.uid;

  late Stream<QuerySnapshot> _nextMeetingStream;
  late Stream<QuerySnapshot> _allBookingsStream;

  @override
  void initState() {
    super.initState();
    
    // Stream 1: 用于悬浮卡片 (保持不变)
    _nextMeetingStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('landlordUid', isEqualTo: currentLandlordUid)
        .where('status', isEqualTo: 'approved')
        .where('meetingTime', isGreaterThan: Timestamp.now())
        .orderBy('meetingTime', descending: false)
        .limit(1)
        .snapshots();
        
    // Stream 2: 用于历史列表 (保持不变)
    _allBookingsStream = FirebaseFirestore.instance
        .collection('bookings')
        .where('landlordUid', isEqualTo: currentLandlordUid)
        .orderBy('requestedAt', descending: true)
        .snapshots();
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
              // 1. AppBar (保持不变)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'Inbox',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // 2. 悬浮卡片 StreamBuilder (保持不变)
              StreamBuilder<QuerySnapshot>(
                stream: _nextMeetingStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty || snapshot.hasError) {
                    return const SizedBox.shrink(); 
                  }
                  final nextBookingDoc = snapshot.data!.docs.first;
                  return NextMeetingCard(bookingDoc: nextBookingDoc);
                },
              ),

              // 3. "All Messages" 标题 (保持不变)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "All Messages",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              
              // 4. 历史列表 StreamBuilder
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _allBookingsStream, 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    if (snapshot.hasError) {
                      // 提醒用户创建索引
                      if (snapshot.error.toString().contains("cloud_firestore/failed-precondition")) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Error: Firestore index required. Please check your debug console for the link to create it, or create it manually.",
                            style: const TextStyle(color: Colors.yellowAccent, fontSize: 16),
                          ),
                        );
                      }
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'You have no messages or notifications.',
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
                        
                        // ▼▼▼ 【修改】: 使用新的动画卡片 ▼▼▼
                        return InboxMessageCard(
                          bookingData: bookingData,
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
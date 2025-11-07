// 在 lib/screens/ 目录下
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// 导入所有组件
import 'package:smart_rental_system/Compoents/animated_bottom_nav.dart';
import 'package:smart_rental_system/Compoents/user_info_card.dart'; 
import 'package:smart_rental_system/Compoents/property_card.dart';

// 导入所有屏幕
import 'package:smart_rental_system/Screens/login_screen.dart'; 
import 'package:smart_rental_system/Screens/home_screen.dart'; 
import 'package:smart_rental_system/screens/add_property_screen.dart'; 
import 'package:smart_rental_system/screens/landlord_bookings_screen.dart';
import 'package:smart_rental_system/screens/landlord_inbox_screen.dart'; 


class LandlordScreen extends StatefulWidget {
  const LandlordScreen({super.key});

  @override
  State<LandlordScreen> createState() => _LandlordScreenState();
}

class _LandlordScreenState extends State<LandlordScreen> {
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late Stream<DocumentSnapshot> _userStream;
  late Stream<QuerySnapshot> _propertiesStream;
  late Stream<QuerySnapshot> _bookingsStream; 

  int _currentNavIndex = 3; 

  @override
  void initState() {
    super.initState();
    if (_uid != null) {
      _userStream =
          FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
      _propertiesStream = FirebaseFirestore.instance
          .collection('properties')
          .where('landlordUid', isEqualTo: _uid)
          .snapshots(); 
      _bookingsStream = FirebaseFirestore.instance
          .collection('bookings')
          .where('landlordUid', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    } else {
      _userStream = Stream.error("User not logged in");
      _propertiesStream = Stream.error("User not logged in");
      _bookingsStream = Stream.error("User not logged in");
    }
  }

  // ▼▼▼ 【BUG 修复】: 导航到 HomeScreen 时，传递 initialIndex ▼▼▼
  void _onNavTap(int index) {
    if (index == 0) { // Home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Landlord', initialIndex: 0)), // 👈
      );
    } else if (index == 1) { // List
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen(userRole: 'Landlord', initialIndex: 1)), // 👈
      );
    } else if (index == 2) { // Inbox
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LandlordInboxScreen()),
      );
    } else if (index == 3) { // My Account
      // 你已经在这个页面了，什么都不用做
    }
    
    // 更新状态以高亮图标
    setState(() {
      _currentNavIndex = index;
    });
  }
  // ▲▲▲ 【BUG 修复】 ▲▲▲

  // 退出函数 (保持不变)
  Future<void> _signOut(BuildContext context) async {
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (didConfirm == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }

  // 导航到待处理预约 (保持不变)
  void _navigateToBookings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LandlordBookingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
         backgroundColor: Colors.transparent, 
        elevation: 0, 
        title: const Text('Landlord Dashboard', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white), 
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            onPressed: () => _signOut(context), 
          )
        ],
      ),
      
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [ Color(0xFF153a44), Color(0xFF295a68), Color(0xFF5d8fa0), Color(0xFF94bac4) ],
              ),
            ),
          ),
          SafeArea(
            bottom: false, 
            child: Column( 
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                
                // 1. UserInfoCard (保持不变)
                StreamBuilder<DocumentSnapshot>(
                  stream: _userStream,
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return const UserInfoCard( name: 'Loading...', phone: '...', avatarUrl: null, pendingBookingCount: 0);
                    }
                    if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return const UserInfoCard( name: 'Error', phone: 'Could not load data', avatarUrl: null, pendingBookingCount: 0);
                    }
                    
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    final String name = userData['name'] ?? 'Unknown Name';
                    final String phone = userData['phone'] ?? 'No Phone';
                    final String? avatarUrl = userData['avatarUrl'];

                    return StreamBuilder<QuerySnapshot>(
                      stream: _bookingsStream, 
                      builder: (context, bookingSnapshot) {
                        final int pendingCount = (bookingSnapshot.hasData)
                            ? bookingSnapshot.data!.docs.length
                            : 0;

                        return UserInfoCard(
                          name: name,
                          phone: phone,
                          avatarUrl: avatarUrl,
                          pendingBookingCount: pendingCount, 
                          onNotificationTap: _navigateToBookings,
                        );
                      },
                    );
                  },
                ),
                
                // 3. "My Properties" 标题 (保持不变)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    "My Properties",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),

                // 4. 房源列表 (保持不变)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _propertiesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text("Error loading properties", style: TextStyle(color: Colors.white70)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'You have no properties yet.\nTap the + button to add one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.white70),
                          ),
                        );
                      }
                      
                      final properties = snapshot.data!.docs;
                      
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0), 
                        itemCount: properties.length,
                        itemBuilder: (context, index) {
                          final doc = properties[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          return PropertyCard(
                            propertyData: data,
                            propertyId: doc.id,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddPropertyScreen(
                                    propertyId: doc.id, 
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // 底边栏 (保持不变)
      bottomNavigationBar: AnimatedBottomNav(
        currentIndex: _currentNavIndex, 
        onTap: _onNavTap, 
        items: const [
          BottomNavItem(icon: Icons.home, label: "Home Page"),
          BottomNavItem(icon: Icons.list, label: "List"),
          BottomNavItem(icon: Icons.inbox, label: "Inbox"), 
          BottomNavItem(icon: Icons.person, label: "My Account"),
        ],
      ),

      // FAB (保持不变)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPropertyScreen()),
          );
        },
        tooltip: 'Add Property',
        child: const Icon(Icons.add_home_work),
      ),
    );
  }
}
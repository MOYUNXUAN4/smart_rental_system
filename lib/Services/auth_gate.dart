import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../Screens/login_screen.dart';
import '../Screens/landlord_screen.dart';
import '../Screens/tenant_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LoginScreen();
        }
        return UserTypeDispatcher(user: snapshot.data!);
      },
    );
  }
}

class UserTypeDispatcher extends StatelessWidget {
  final User user;

  const UserTypeDispatcher({super.key, required this.user});

  Future<String> _getUserType() async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        final userType = doc.data()!['userType'] ?? 'unknown';
        print("UserType from DB: '$userType'");
        return userType;
      } else {
        // 用户文档不存在，自动创建默认类型（这里默认 Tenant，可根据实际调整）
        await docRef.set({
          'userType': 'Tenant',
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("User document created for UID: ${user.uid}, default type: Tenant");
        return 'Tenant';
      }
    } catch (e) {
      print('Get UserType failed: $e');
      return 'error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getUserType(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == 'error') {
          return Scaffold(
            body: Center(child: Text('Failed to load user information...')),
          );
        }

        final userType = snapshot.data;
        print("Checking userType: '$userType'");

        if (userType == 'Landlord') {
          return const LandlordScreen();
        } else if (userType == 'Tenant') {
          return const TenantScreen();
        } else {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Unknown user type: $userType'),
                  ElevatedButton(
                    child: const Text('Sign Out'),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}

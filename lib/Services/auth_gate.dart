import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../LogIn&Register/login_screen.dart';
import '../landlord_screen.dart';
import '../LogIn&Register/tenant_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return LoginScreen(); 
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
      final doc = await FirebaseFirestore.instance
          .collection('users') 
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final userType = doc.data()!['userType'] ?? 'unknown';
        
        // ---【诊断日志 1】---
        print("UserType from DB: '$userType'"); 
        
        return userType;
      } else {
        print("User document not found (UID: ${user.uid})");
        return 'unknown';
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
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == 'error') {
          return Scaffold(
            body: Center(child: Text('Failed to load user information...')),
          );
        }

        final userType = snapshot.data;

        // ---【诊断日志 2】---
        print("Checking userType: '$userType'");
        print("Comparing with 'Landlord': ${userType == 'Landlord'}");
        print("Comparing with 'Tenant': ${userType == 'Tenant'}");

        if (userType == 'Landlord') {
          return LandlordScreen();
        } else if (userType == 'Tenant') {
          return TenantScreen();
        } else {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Unknown user type: $userType'),
                  ElevatedButton(
                    child: Text('Sign Out'),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  )
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'glass_card.dart'; 
import 'contract_generator.dart'; 

// ✅ Correct Import: Point to the specialized Landlord Sign Screen
import '../screens/landlord_sign_contract_screen.dart'; 

class LandlordBookingCard extends StatelessWidget {
  final Map<String, dynamic> bookingData;
  final String docId; 

  const LandlordBookingCard({
    super.key,
    required this.bookingData,
    required this.docId,
  });

  Future<String> _getTenantName(String tenantUid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(tenantUid).get();
      return doc.exists ? (doc.data()!['name'] ?? 'Unknown Tenant') : 'Unknown Tenant';
    } catch (e) { return '...'; }
  }

  Future<String> _getPropertyName(String propertyId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      return doc.exists ? (doc.data()!['communityName'] ?? 'Unknown Property') : 'Unknown Property';
    } catch (e) { return '...'; }
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
        'status': newStatus, 'isReadByTenant': false, 
    });
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Status updated to $newStatus")));
  }

  // Generate Initial Contract (When Landlord clicks Approve & Contract)
  Future<void> _handleReleaseContract(BuildContext context) async {
    final String propertyId = bookingData['propertyId'];
    final String tenantUid = bookingData['tenantUid'];
    final String? landlordUid = bookingData['landlordUid']; 
    
    final Timestamp? startDateTs = bookingData['leaseStartDate'];
    final Timestamp? endDateTs = bookingData['leaseEndDate'];

    if (startDateTs == null || endDateTs == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Lease dates missing!")));
      return;
    }

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Colors.white))
    );

    try {
      final propertyDoc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      final propertyData = propertyDoc.data() as Map<String, dynamic>;
      
      String landlordName = "Landlord"; 
      if (landlordUid != null) {
          final uDoc = await FirebaseFirestore.instance.collection('users').doc(landlordUid).get();
          if (uDoc.exists) landlordName = uDoc.data()?['name'] ?? "Landlord";
      }

      final tenantDoc = await FirebaseFirestore.instance.collection('users').doc(tenantUid).get();
      final String tenantName = tenantDoc.data()?['name'] ?? "Tenant";

      final start = startDateTs.toDate();
      final end = endDateTs.toDate();
      final String startStr = DateFormat('yyyy-MM-dd').format(start);
      final String endStr = DateFormat('yyyy-MM-dd').format(end);
      final String paymentDay = "${start.day}"; 

      // Generate Initial PDF (Draft for Tenant to see)
      final File generatedPdf = await ContractGenerator.generateAndSaveContract(
        landlordName: landlordName, 
        tenantName: tenantName, 
        propertyAddress: "${propertyData['unitNumber'] ?? ''}, ${propertyData['communityName'] ?? ''}", 
        rentAmount: (propertyData['price'] ?? 0).toString(),
        startDate: startStr, 
        endDate: endStr, 
        paymentDay: paymentDay, 
        language: 'zh', // Default language
      );

      final String fileName = 'contracts/initial_${docId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(generatedPdf);
      final String newContractUrl = await ref.getDownloadURL(); 

      await FirebaseFirestore.instance.collection('bookings').doc(docId).update({
        'status': 'ready_to_sign', 
        'contractUrl': newContractUrl, 
        'contractReleasedAt': Timestamp.now(),
        'monthlyPaymentDay': paymentDay, 
        'isReadByTenant': false, 
      });

      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contract Sent to Tenant!"), backgroundColor: Color(0xFF1D5DC7)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = bookingData['status'] ?? 'pending';
    final Timestamp meetingTimestamp = bookingData['meetingTime'];
    final String meetingPoint = bookingData['meetingPoint'] ?? '';
    final String formattedTime = DateFormat('dd MMM, hh:mm a').format(meetingTimestamp.toDate());
    final String tenantUid = bookingData['tenantUid'];
    final String propertyId = bookingData['propertyId'];

    final Timestamp? leaseStartTs = bookingData['leaseStartDate'];
    final Timestamp? leaseEndTs = bookingData['leaseEndDate'];
    String? leaseTermStr;
    if (leaseStartTs != null && leaseEndTs != null) {
      final String startStr = DateFormat('yyyy-MM-dd').format(leaseStartTs.toDate());
      final String endStr = DateFormat('yyyy-MM-dd').format(leaseEndTs.toDate());
      leaseTermStr = "$startStr  to  $endStr"; 
    }

    Color statusColor = Colors.white70;
    String statusText = status.toUpperCase().replaceAll('_', ' ');
    
    if (status == 'pending') { statusColor = Colors.orangeAccent; }
    else if (status == 'approved') { statusColor = const Color(0xFF69F0AE); } 
    else if (status == 'application_pending') { statusColor = Colors.amber; statusText = "APP PENDING"; }
    else if (status == 'ready_to_sign') { statusColor = Colors.cyanAccent; }
    else if (status == 'rejected') { statusColor = Colors.redAccent; }
    else if (status == 'awaiting_payment') { statusColor = Colors.purpleAccent; } 

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0), 
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _getPropertyName(propertyId),
                      builder: (context, snapshot) => Text(
                        snapshot.data ?? '...',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor.withOpacity(0.6), width: 0.5),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(color: Colors.white12, height: 1, thickness: 0.5),
              const SizedBox(height: 4),

              Row(children: [
                const Icon(Icons.person, color: Colors.white70, size: 13),
                const SizedBox(width: 6),
                FutureBuilder<String>(
                  future: _getTenantName(tenantUid),
                  builder: (context, snapshot) => Text(
                    "Tenant: ${snapshot.data ?? '...'}", 
                    style: const TextStyle(color: Colors.white, fontSize: 13)
                  ),
                ),
              ]),
              const SizedBox(height: 3), 

              Row(children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 13),
                const SizedBox(width: 6),
                Text(formattedTime, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ]),
              const SizedBox(height: 3), 

              Row(children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    meetingPoint, 
                    style: const TextStyle(color: Colors.white, fontSize: 13), 
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  )
                ),
              ]),

              if (leaseTermStr != null && (status == 'application_pending' || status == 'ready_to_sign')) ...[
                 const SizedBox(height: 8),
                 Container(
                   width: double.infinity,
                   padding: const EdgeInsets.all(6),
                   decoration: BoxDecoration(
                     color: Colors.blue.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(6),
                     border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                   ),
                   child: Row(
                     children: [
                       const Icon(Icons.date_range, color: Colors.blueAccent, size: 12),
                       const SizedBox(width: 6),
                       Expanded(
                         child: Text(
                           "Lease: $leaseTermStr", 
                           style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                     ],
                   ),
                 ),
              ],

              if (status == 'application_pending' && bookingData['applicationNote'] != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withOpacity(0.2)),
                  ),
                  child: Text(
                    "Note: ${bookingData['applicationNote']}", 
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Button Logic
              if (status == 'pending') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildOutlineBtn("Reject", Colors.redAccent, () => _updateStatus(context, 'rejected'))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSolidBtn("Approve", Colors.green, () => _updateStatus(context, 'approved'))),
                  ],
                ),
              ],

              if (status == 'application_pending') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildOutlineBtn("Reject", Colors.redAccent, () => _updateStatus(context, 'rejected')),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildSolidBtn("Approve & Contract", const Color(0xFF1D5DC7), () => _handleReleaseContract(context)),
                    ),
                  ],
                ),
              ],

              if (status == 'ready_to_sign') ...[
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("Waiting for tenant signature...", style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic)),
                  ],
                ),
              ],

              // ✅✅✅ LANDLORD COUNTER SIGN BUTTON ✅✅✅
              if (status == 'tenant_signed') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: _buildSolidBtn("Counter Sign (Review)", Colors.teal, () {
                    // Navigate to the Landlord-specific signing screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LandlordSignContractScreen(
                          docId: docId, // Pass the Document ID
                        ),
                      ),
                    );
                  }),
                ),
              ],
              
              if (status == 'awaiting_payment') ...[
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("Waiting for payment...", style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontStyle: FontStyle.italic)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolidBtn(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 32, 
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildOutlineBtn(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 32, 
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1),
          foregroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
import 'dart:ui'; // ✅ Required for ImageFilter

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ✅ Import relevant screens and services
// 确保这些引用的路径与你的项目结构一致
import '../Screens/final_contract_viewer_screen.dart';
import '../Screens/receipt_screen.dart';
import '../Services/stripe_service.dart';
import 'glass_card.dart';
import 'shared_contract_signing_screen.dart';

class TenantBookingCard extends StatefulWidget {
  final Map<String, dynamic> bookingData;
  final String? docId;
  final Color statusColor;
  final IconData statusIcon;

  const TenantBookingCard({
    super.key,
    required this.bookingData,
    this.docId,
    required this.statusColor,
    required this.statusIcon,
  });

  @override
  State<TenantBookingCard> createState() => _TenantBookingCardState();
}

class _TenantBookingCardState extends State<TenantBookingCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false; 
  bool _isPaying = false;   

  // Fetch Property Name
  Future<String> _getPropertyName(String propertyId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      return doc.exists ? (doc.data()!['communityName'] ?? 'Unknown') : 'Unknown';
    } catch (e) { return '...'; }
  }

  // Fetch Landlord Name
  Future<String> _getLandlordName(String? uid) async {
    if (uid == null) return "Unknown";
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.exists ? (doc.data()!['name'] ?? 'Landlord') : 'Landlord';
    } catch (e) { return '...'; }
  }

  // 🔥 Calculate Next Rent Due Date (Same logic as Landlord)
  String _getNextPaymentDate(int paymentDay) {
    DateTime now = DateTime.now();
    DateTime targetDate = DateTime(now.year, now.month, paymentDay);
    
    if (now.day > paymentDay) {
      targetDate = DateTime(now.year, now.month + 1, paymentDay);
    }
    
    return DateFormat('dd MMM yyyy').format(targetDate);
  }

  // 🔥🔥🔥 Core: Stripe Payment Logic (Updated with Batch Write) 🔥🔥🔥
  Future<void> _handlePayment(BuildContext context) async {
    setState(() {
      _isPaying = true;
    });

    try {
      debugPrint("Full booking data: ${widget.bookingData}");

      // 1. Try to find price in current booking data
      dynamic rawPrice = widget.bookingData['price'] ?? 
                         widget.bookingData['rent'] ?? 
                         widget.bookingData['amount'] ??
                         widget.bookingData['monthlyRent'];

      // 2. Backup: If price is missing, fetch from 'properties' collection
      if (rawPrice == null) {
        String? propertyId = widget.bookingData['propertyId'];
        if (propertyId != null) {
          debugPrint("Price missing in booking. Fetching from Property: $propertyId");
          
          final propertyDoc = await FirebaseFirestore.instance
              .collection('properties')
              .doc(propertyId)
              .get();

          if (propertyDoc.exists) {
            final pData = propertyDoc.data();
            rawPrice = pData?['price'] ?? pData?['monthlyRent'] ?? pData?['rent'];
            debugPrint("Found price in Property document: $rawPrice");
          }
        }
      }

      // 3. If still null, throw error
      if (rawPrice == null) {
        throw Exception("System cannot find price in Booking OR Property database.");
      }

      // 4. Data Cleaning
      String priceStr = rawPrice.toString();
      priceStr = priceStr.replaceAll(RegExp(r'[^0-9.]'), '');
      
      double rentPrice = double.tryParse(priceStr) ?? 0.0;
      debugPrint("Final parsed price: $rentPrice");

      if (rentPrice <= 0.5) { 
        throw Exception("Invalid price amount: $rentPrice");
      }

      // 5. Start Payment via Stripe Service
      bool success = await StripeService.instance.makePayment(rentPrice);

      if (success) {
        // ✅ Payment Success Logic
        if (widget.docId != null) {
          
          // 🔥🔥🔥 核心修改开始：使用 Batch 同时更新订单和房源状态 🔥🔥🔥
          WriteBatch batch = FirebaseFirestore.instance.batch();

          // A. 更新 Booking 表状态 -> Completed
          DocumentReference bookingRef = FirebaseFirestore.instance.collection('bookings').doc(widget.docId);
          batch.update(bookingRef, {
            'status': 'completed',       
            'paymentStatus': 'paid',     
            'isActiveTenant': true,      
            'paymentDate': FieldValue.serverTimestamp(),
            'isReadByLandlord': false,
            // Write the fetched price back to booking for future reference
            'price': rentPrice, 
          });

          // B. 更新 Property 表状态 -> Rented (这一步让房源从列表消失)
          String? propertyId = widget.bookingData['propertyId'];
          if (propertyId != null) {
            DocumentReference propertyRef = FirebaseFirestore.instance.collection('properties').doc(propertyId);
            batch.update(propertyRef, {
              'status': 'rented', // 🚨 状态改为已出租
              'tenantUid': widget.bookingData['tenantUid'], // 可选：记录当前租客ID
            });
          }

          // C. 提交所有更改
          await batch.commit();
          // 🔥🔥🔥 核心修改结束 🔥🔥🔥
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment Successful! Welcome home. 🎉"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment Cancelled."),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error paying: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
        });
      }
    }
  }

  // Confirm Dialog (Glassmorphism)
  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white70, size: 40),
                  const SizedBox(height: 16),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFEF5350)]),
                            boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))],
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(confirmText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Tenant Request Deletion
  Future<void> _requestDeletion() async {
    if (widget.docId == null) return;

    final bool? confirm = await _showConfirmDialog(
      title: "Cancel Request?",
      content: "Are you sure you want to cancel this booking? The landlord will be notified.",
      confirmText: "Yes, Cancel",
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
        'deletionRequest': 'pending',
        'deletionRequestedBy': 'tenant',
        'status': 'cancellation_pending', 
        'isReadByLandlord': false, 
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cancellation request sent.")));
    }
  }

  // Glass Banner
  Widget _buildGlassBanner({
    required BuildContext context,
    required String text,
    required IconData icon,
    required Color color, 
    required VoidCallback onKeep,
    required VoidCallback onConfirm,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 1), 
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08), 
              border: Border(bottom: BorderSide(color: color.withOpacity(0.2), width: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 12, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: color.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: onKeep, 
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text("Keep", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.8), color],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                          ]
                        ),
                        child: const Text("Confirm", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Application Dialog
  void _showApplicationDialog(BuildContext context) {
    final TextEditingController noteController = TextEditingController();
    DateTime selectedStartDate = DateTime.now();
    int selectedDurationMonths = 12;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final DateTime endDate = DateTime(
            selectedStartDate.year, 
            selectedStartDate.month + selectedDurationMonths, 
            selectedStartDate.day
          ).subtract(const Duration(days: 1)); 
          const Color primaryBlue = Color(0xFF1D5DC7);

          return Dialog(
            backgroundColor: const Color(0xFF2C3E50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📝 Rental Application", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  
                  const Text("Start Date", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedStartDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => selectedStartDate = picked); 
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(DateFormat('yyyy-MM-dd').format(selectedStartDate), style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Duration", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedDurationMonths,
                        dropdownColor: const Color(0xFF34495E),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        items: [6, 12, 24, 36].map((months) {
                          return DropdownMenuItem(value: months, child: Text("$months Months"));
                        }).toList(),
                        onChanged: (val) { if (val != null) setState(() => selectedDurationMonths = val); },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text("Ends: ${DateFormat('yyyy-MM-dd').format(endDate)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                  ),
                  const SizedBox(height: 12),
                  const Text("Note to Landlord", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Optional...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  // ...
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Cancel", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx); 
                            if (widget.docId == null) return;
                            try {
                              await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
                                  'status': 'application_pending',
                                  'applicationNote': noteController.text.trim(),
                                  'appliedAt': Timestamp.now(),
                                  'leaseStartDate': Timestamp.fromDate(selectedStartDate),
                                  'leaseEndDate': Timestamp.fromDate(endDate),
                                  'isReadByLandlord': false,
                              });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application Sent!"), backgroundColor: Colors.green));
                            } catch (e) { print(e); }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Submit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String propertyId = widget.bookingData['propertyId'];
    final String? landlordUid = widget.bookingData['landlordUid'];
    final Timestamp meetingTimestamp = widget.bookingData['meetingTime'];
    final String meetingPoint = widget.bookingData['meetingPoint'] ?? '';
    final String status = widget.bookingData['status'] ?? 'Unknown';
    final String formattedTime = DateFormat('MM/dd HH:mm').format(meetingTimestamp.toDate());

    final String? deletionRequest = widget.bookingData['deletionRequest'];
    final String? requestedBy = widget.bookingData['deletionRequestedBy'];

    bool showIncomingRequest = (deletionRequest == 'pending' && requestedBy == 'landlord');
    bool showWaitingMessage = (deletionRequest == 'pending' && requestedBy == 'tenant');

    Color currentStatusColor = widget.statusColor;
    IconData currentStatusIcon = widget.statusIcon;
    String displayStatus = status.toUpperCase().replaceAll('_', ' ');

    // ✅ UI Status Logic
    if (status == 'application_pending') {
      currentStatusColor = Colors.orangeAccent; currentStatusIcon = Icons.hourglass_top; displayStatus = "PENDING";
    } else if (status == 'tenant_signed') {
      currentStatusColor = Colors.tealAccent; currentStatusIcon = Icons.edit_note; displayStatus = "WAITING LANDLORD";
    } else if (status == 'awaiting_payment') {
      currentStatusColor = const Color(0xFF00BFA5); currentStatusIcon = Icons.verified_user; displayStatus = "FINALIZED";
    } else if (status == 'cancellation_pending') {
      currentStatusColor = Colors.redAccent; currentStatusIcon = Icons.delete_forever; displayStatus = "CANCELLING...";
    } else if (status == 'completed') {
      // ✅ Completed State
      currentStatusColor = Colors.greenAccent; currentStatusIcon = Icons.check_circle; displayStatus = "RENTED";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0), 
      child: GlassCard(
        child: Column(
          children: [
            
            // ✅ Scenario A: Landlord requested deletion
            if (showIncomingRequest)
              _buildGlassBanner(
                context: context,
                text: "Landlord requested cancel",
                icon: Icons.delete_forever,
                color: const Color(0xFFFF7043), 
                onKeep: () async {
                   if (widget.docId == null) return;
                   await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).update({
                      'deletionRequest': FieldValue.delete(),
                      'deletionRequestedBy': FieldValue.delete(),
                      'isReadByLandlord': false,
                   });
                },
                onConfirm: () async {
                   if (widget.docId == null) return;
                   final bool? confirm = await _showConfirmDialog(
                     title: "Approve Deletion?",
                     content: "This action will permanently delete this booking for both parties.",
                     confirmText: "Delete",
                   );
                   if (confirm == true) {
                     await FirebaseFirestore.instance.collection('bookings').doc(widget.docId).delete();
                   }
                }
              ),

            // ✅ Scenario B: Waiting for landlord
            if (showWaitingMessage)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.03),
                   borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                   border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white30)),
                    const SizedBox(width: 8),
                    const Text(
                      "Waiting for landlord confirmation...",
                      style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),

            // Main Card Body
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: FutureBuilder<String>(
                            future: _getPropertyName(propertyId),
                            builder: (context, snapshot) => Text(
                              snapshot.data ?? '...',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: currentStatusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: currentStatusColor.withOpacity(0.5), width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Icon(currentStatusIcon, color: currentStatusColor, size: 9),
                              const SizedBox(width: 3),
                              Text(displayStatus, style: TextStyle(color: currentStatusColor, fontWeight: FontWeight.bold, fontSize: 8)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isExpanded = !_isExpanded),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                            child: Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
                          ),
                        ),
                      ],
                    ),

                    // ✅ 2. Rented Info (Show if completed and expanded)
                    if (status == 'completed' && _isExpanded) 
                      _buildRentedInfo(widget.bookingData),

                    // Action Bar
                    // ✅ Show actions for specific statuses, including 'completed'
                    if (['pending', 'approved', 'ready_to_sign', 'awaiting_payment', 'completed'].contains(status)) ...[
                      const SizedBox(height: 5),
                      _buildActionBar(context, status),
                    ],

                    // Details
                    if (_isExpanded) ...[
                      const SizedBox(height: 5),
                      _buildSectionContainer(
                        icon: Icons.calendar_today,
                        title: "Appointment",
                        content: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(formattedTime, style: const TextStyle(color: Colors.white, fontSize: 11)),
                            Expanded(child: Text(meetingPoint, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildSectionContainer(
                        icon: Icons.person_outline,
                        title: "Landlord Info",
                        content: FutureBuilder<String>(
                          future: _getLandlordName(landlordUid),
                          builder: (context, snapshot) => Text(
                            snapshot.data ?? '...',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                      ),
                      if (widget.bookingData['applicationNote'] != null) ...[
                        const SizedBox(height: 4),
                        _buildSectionContainer(
                          icon: Icons.sticky_note_2_outlined,
                          title: "My Note",
                          content: Text(
                            widget.bookingData['applicationNote'],
                            style: const TextStyle(color: Colors.white60, fontSize: 10, fontStyle: FontStyle.italic),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ New Helper: Rented Info (Safe Int Parsing)
  Widget _buildRentedInfo(Map<String, dynamic> data) {
    // Parse Lease Dates
    final Timestamp? start = data['leaseStartDate'];
    final Timestamp? end = data['leaseEndDate'];
    
    // 🛠️ Safe Parsing: Ensure conversion to String then to Int
    final int payDay = int.tryParse(data['monthlyPaymentDay']?.toString() ?? '1') ?? 1;

    String leasePeriod = "Unknown";
    if (start != null && end != null) {
      leasePeriod = "${DateFormat('MMM yyyy').format(start.toDate())} - ${DateFormat('MMM yyyy').format(end.toDate())}";
    }

    String nextPayDate = _getNextPaymentDate(payDay);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withOpacity(0.1), // Green Background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Lease Period", style: TextStyle(color: Colors.white54, fontSize: 9)),
              const SizedBox(height: 2),
              Text(leasePeriod, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(width: 1, height: 20, color: Colors.white24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("Next Rent Due", style: TextStyle(color: Colors.greenAccent, fontSize: 9)),
              const SizedBox(height: 2),
              Text(nextPayDate, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({required IconData icon, required String title, required Widget content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: Colors.white38),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 2),
          content,
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, String status) {
    // 1. Pending
    if (status == 'pending') {
      return SizedBox(
        width: double.infinity,
        height: 28,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: Colors.white38,
          ),
          icon: const Icon(Icons.cancel_outlined, size: 12),
          label: const Text("Cancel Request", style: TextStyle(fontSize: 10)),
          onPressed: _requestDeletion, 
        ),
      );
    }
    
    // 2. Approved
    else if (status == 'approved') {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 28, 
              child: OutlinedButton(
                onPressed: _requestDeletion, 
                style: OutlinedButton.styleFrom(
                   side: BorderSide(color: Colors.white.withOpacity(0.3)),
                   foregroundColor: Colors.white70,
                   padding: EdgeInsets.zero,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text("Cancel", style: TextStyle(fontSize: 10)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 28, 
              child: _buildGradientButton("Apply Now", const [Color(0xFF1D5DC7), Color(0xFF1E88E5)], () => _showApplicationDialog(context)),
            ),
          ),
        ],
      );
    } 

    // 3. Ready to Sign
    else if (status == 'ready_to_sign') {
      return SizedBox(
        height: 28,
        child: _buildGradientButton("Sign Contract", const [Color(0xFF295a68), Color(0xFF457f8f)], () {
          if (widget.docId != null) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => SharedContractSigningScreen(docId: widget.docId!, isLandlord: false),
            ));
          }
        }),
      );
    } 

    // 4. Awaiting Payment
    else if (status == 'awaiting_payment') {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 28,
              child: _buildGlassyButton("View Contract", () {
                 final String urlZh = widget.bookingData['contractUrlZh'] ?? widget.bookingData['contractUrl'] ?? '';
                 final String urlEn = widget.bookingData['contractUrlEn'] ?? widget.bookingData['contractUrl'] ?? '';
                 Navigator.push(context, MaterialPageRoute(
                   builder: (_) => FinalContractViewerScreen(contractUrlZh: urlZh, contractUrlEn: urlEn),
                 ));
              }),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 28,
              // Check _isPaying status
              child: _isPaying
                  ? Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : _buildGradientButton("Pay Now", const [Color(0xFF00B09B), Color(0xFF96C93D)], () => _handlePayment(context)),
            ),
          ),
        ],
      );
    }

    // 5. ✅ Completed: Show Contract & Receipt
    else if (status == 'completed') {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 28,
              child: _buildGlassyButton("View Contract", () {
                 final String urlZh = widget.bookingData['contractUrlZh'] ?? widget.bookingData['contractUrl'] ?? '';
                 final String urlEn = widget.bookingData['contractUrlEn'] ?? widget.bookingData['contractUrl'] ?? '';
                 Navigator.push(context, MaterialPageRoute(
                   builder: (_) => FinalContractViewerScreen(contractUrlZh: urlZh, contractUrlEn: urlEn),
                 ));
              }),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 28,
              // View Receipt Button
              child: _buildGradientButton("View Receipt", const [Color(0xFF11998e), Color(0xFF38ef7d)], () {
                if (widget.docId != null) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ReceiptScreen(bookingData: widget.bookingData, bookingId: widget.docId!),
                  ));
                }
              }),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildGlassyButton(String text, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Center(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientButton(String text, List<Color> colors, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(colors: colors),
        boxShadow: [BoxShadow(color: colors.last.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Center(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
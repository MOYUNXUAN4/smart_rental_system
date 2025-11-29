import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'glass_card.dart';

// ✅ 使用你新的通用签字界面
import 'shared_contract_signing_screen.dart';

class TenantBookingCard extends StatelessWidget {
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

  Future<String> _getPropertyName(String propertyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .get();

      return doc.exists
          ? (doc.data()!['communityName'] ?? 'Unknown Property')
          : 'Unknown Property';
    } catch (e) {
      return 'Loading...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String propertyId = bookingData['propertyId'];
    final Timestamp meetingTimestamp = bookingData['meetingTime'];
    final String meetingPoint = bookingData['meetingPoint'];
    final String status = bookingData['status'] ?? 'Unknown';
    final String formattedTime =
        DateFormat('dd MMM, hh:mm a').format(meetingTimestamp.toDate());

    final isPending = status == 'application_pending';
    final Color currentStatusColor =
        isPending ? Colors.orangeAccent : statusColor;
    final IconData currentStatusIcon =
        isPending ? Icons.hourglass_top : statusIcon;
    final String displayStatus =
        isPending ? "PENDING APPROVAL" : status.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------- HEADER ----------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _getPropertyName(propertyId),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Loading...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: currentStatusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: currentStatusColor.withOpacity(0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(currentStatusIcon,
                            color: currentStatusColor, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          displayStatus,
                          style: TextStyle(
                            color: currentStatusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(color: Colors.white24, height: 16),

              // ---------------------- DATE ----------------------
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    formattedTime,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // ---------------------- LOCATION ----------------------
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Colors.white70, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      meetingPoint,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // -------------------------------------------------------------
              // 🔵 READY TO SIGN — 进入签字界面
              // -------------------------------------------------------------
              if (status == 'ready_to_sign') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (docId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SharedContractSigningScreen(
                              docId: docId!,
                              isLandlord: false, // 租户模式
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Error: Doc ID missing"),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.edit_document, size: 16),
                    label: const Text(
                      'Sign Contract',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF295a68),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

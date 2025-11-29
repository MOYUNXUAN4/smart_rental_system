import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Screens/final_contract_viewer_screen.dart';
import 'glass_card.dart';
// 引入相关页面
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
  bool _isExpanded = false; // 控制折叠状态

  // 获取房产名称
  Future<String> _getPropertyName(String propertyId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      return doc.exists ? (doc.data()!['communityName'] ?? 'Unknown') : 'Unknown';
    } catch (e) { return '...'; }
  }

  // 获取房东名称
  Future<String> _getLandlordName(String? uid) async {
    if (uid == null) return "Unknown";
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.exists ? (doc.data()!['name'] ?? 'Landlord') : 'Landlord';
    } catch (e) { return '...'; }
  }

  // 支付逻辑 (预留)
  void _handlePayment(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Gateway Coming Soon"), backgroundColor: Color(0xFF00B09B)),
    );
  }

  // ✅ 完整的申请弹窗逻辑 (恢复了日期选择和租期功能)
  void _showApplicationDialog(BuildContext context) {
    final TextEditingController noteController = TextEditingController();
    DateTime selectedStartDate = DateTime.now();
    int selectedDurationMonths = 12; // 默认租期

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8), // 深色背景突出弹窗
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          
          // 自动计算结束日期
          final DateTime endDate = DateTime(
            selectedStartDate.year, 
            selectedStartDate.month + selectedDurationMonths, 
            selectedStartDate.day
          ).subtract(const Duration(days: 1)); 

          const Color primaryBlue = Color(0xFF1D5DC7);

          return Dialog(
            backgroundColor: const Color(0xFF2C3E50), // 深色背景
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
                  
                  // 1. Start Date
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

                  // 2. Lease Duration
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
                  
                  // 3. Note
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

                  const SizedBox(height: 24),

                  // 4. Buttons
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
    final String meetingPoint = widget.bookingData['meetingPoint'];
    final String status = widget.bookingData['status'] ?? 'Unknown';
    final String formattedTime = DateFormat('MM/dd HH:mm').format(meetingTimestamp.toDate());

    // 状态样式逻辑
    Color currentStatusColor = widget.statusColor;
    IconData currentStatusIcon = widget.statusIcon;
    String displayStatus = status.toUpperCase().replaceAll('_', ' ');

    if (status == 'application_pending') {
      currentStatusColor = Colors.orangeAccent; currentStatusIcon = Icons.hourglass_top; displayStatus = "PENDING";
    } else if (status == 'tenant_signed') {
      currentStatusColor = Colors.tealAccent; currentStatusIcon = Icons.edit_note; displayStatus = "WAITING LANDLORD";
    } else if (status == 'awaiting_payment') {
      currentStatusColor = const Color(0xFF00BFA5); currentStatusIcon = Icons.verified_user; displayStatus = "FINALIZED";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0), 
      child: GlassCard(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          alignment: Alignment.topCenter,
          child: Container(
            // ✅ 保持你要求的 UI：极度紧凑内部 Padding (5.0)
            padding: const EdgeInsets.all(5.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. 核心栏 (Header)
                // ==========================================
                Row(
                  children: [
                    // 房源名称
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
                    
                    // 状态胶囊
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
                    
                    // 折叠箭头
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

                // ==========================================
                // 2. 关键操作栏 (Action Bar) - 始终显示
                // ==========================================
                if (status == 'approved' || status == 'ready_to_sign' || status == 'awaiting_payment') ...[
                  const SizedBox(height: 5),
                  _buildActionBar(context, status),
                ],

                // ==========================================
                // 3. 折叠详情区 (Details)
                // ==========================================
                if (_isExpanded) ...[
                  const SizedBox(height: 5),
                  // 会面信息
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
                  
                  // 房东信息
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

                  // 备注
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
      ),
    );
  }

  // --- UI 组件构建方法 ---

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
    if (status == 'approved') {
      return SizedBox(
        height: 28, 
        child: _buildGradientButton("Apply Now", const [Color(0xFF1D5DC7), Color(0xFF1E88E5)], () => _showApplicationDialog(context)),
      );
    } 
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
              child: _buildGradientButton("Pay Now", const [Color(0xFF00B09B), Color(0xFF96C93D)], () => _handlePayment(context)),
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
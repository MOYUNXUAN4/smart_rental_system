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
  bool _isExpanded = false; // 控制折叠

  Future<String> _getPropertyName(String propertyId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      return doc.exists ? (doc.data()!['communityName'] ?? 'Unknown') : 'Unknown';
    } catch (e) { return '...'; }
  }

  Future<String> _getLandlordName(String? uid) async {
    if (uid == null) return "Unknown";
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.exists ? (doc.data()!['name'] ?? 'Landlord') : 'Landlord';
    } catch (e) { return '...'; }
  }

  void _handlePayment(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Gateway Coming Soon"), backgroundColor: Color(0xFF00B09B)),
    );
  }

  void _showApplicationDialog(BuildContext context) {
    // (保留之前的逻辑，这里仅示意)
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application Dialog")));
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
      // 外部间距也调小
      padding: const EdgeInsets.only(bottom: 6.0), 
      child: GlassCard(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          alignment: Alignment.topCenter,
          child: Container(
            // ✅✅✅ 极度紧凑的内部 Padding (5.0) ✅✅✅
            padding: const EdgeInsets.all(5.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. 核心栏 (始终显示): 房源名 | 状态 | 展开按钮
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
                    
                    // 折叠箭头 (点击区域放大)
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
                // 2. 关键操作栏 (始终显示，不折叠)
                // ==========================================
                // 只有当有重要操作时才显示这一栏，节省空间
                if (status == 'approved' || status == 'ready_to_sign' || status == 'awaiting_payment') ...[
                  const SizedBox(height: 5),
                  _buildActionBar(context, status),
                ],

                // ==========================================
                // 3. 折叠详情区 (分类显示)
                // ==========================================
                if (_isExpanded) ...[
                  const SizedBox(height: 5),
                  // 分类 A: 会面信息
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
                  
                  // 分类 B: 人员信息
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

                  // 分类 C: 备注 (如果有)
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

  // --- 辅助构建方法 ---

  // 构建分类容器 (毛玻璃背景)
  Widget _buildSectionContainer({required IconData icon, required String title, required Widget content}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03), // 极淡的背景
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

  // 构建操作栏 (根据状态返回不同的按钮组合)
  Widget _buildActionBar(BuildContext context, String status) {
    if (status == 'approved') {
      return SizedBox(
        height: 28, // 极低高度
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

  // 磨砂按钮 (View Contract)
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

  // 渐变按钮 (Pay / Sign)
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
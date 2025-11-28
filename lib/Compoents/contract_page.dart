import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'glass_card.dart';

// ✅ 必须导入签字页面
import '../Screens/sign_contract_screen.dart'; 

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
      final doc = await FirebaseFirestore.instance.collection('properties').doc(propertyId).get();
      return doc.exists ? (doc.data()!['communityName'] ?? 'Unknown Property') : 'Unknown Property';
    } catch (e) {
      return 'Loading...';
    }
  }

  // ✅ 核心功能：申请弹窗 (带亮白毛玻璃日历)
  void _showApplicationDialog(BuildContext context) {
    final TextEditingController noteController = TextEditingController();
    DateTime selectedStartDate = DateTime.now();
    int selectedDurationMonths = 12; 

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7), 
      builder: (ctx) => StatefulBuilder( 
        builder: (context, setState) {
          
          final DateTime endDate = DateTime(
            selectedStartDate.year, 
            selectedStartDate.month + selectedDurationMonths, 
            selectedStartDate.day
          ).subtract(const Duration(days: 1)); 

          // 统一定义深蓝色
          const Color primaryBlue = Color(0xFF1D5DC7);

          // 输入框样式定义
          InputDecoration getBoxDecoration(String label, IconData icon) {
            return InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.white70, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.12),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20), 
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.6)),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent, 
            insetPadding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    // 弹窗本身的背景：深色渐变
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.15),
                        Colors.white.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Rental Application", 
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)
                      ),
                      const SizedBox(height: 20),
                      
                      // --- 1. 开始日期选择 ---
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedStartDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            // ✅✅✅ 日历弹窗主题：亮白毛玻璃 + 深蓝选中 ✅✅✅
                            builder: (context, child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  // 颜色方案：确保文字是深色，选中是你的蓝色
                                  colorScheme: const ColorScheme.light(
                                    primary: primaryBlue, // 选中圆圈颜色 (深蓝)
                                    onPrimary: Colors.white, // 选中文字颜色
                                    surface: Colors.transparent, // 背景透明，交给下面的 Decor 处理
                                    onSurface: Color(0xFF153a44), // 默认文字颜色 (深色)
                                  ),
                                  // 确保 Dialog 背景透明
                                  dialogBackgroundColor: Colors.transparent,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 自定义日历容器
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
                                      decoration: BoxDecoration(
                                        // ✅ 亮白毛玻璃背景
                                        color: Colors.white.withOpacity(0.92), 
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 25, spreadRadius: 2)
                                        ],
                                        border: Border.all(color: Colors.white, width: 1),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: child ?? const SizedBox(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          );
                          if (picked != null) {
                            setState(() => selectedStartDate = picked); 
                          }
                        },
                        // 触发器外观：保持你喜欢的 PropertyTextFormField 风格
                        child: InputDecorator(
                          decoration: getBoxDecoration('Start Date', Icons.calendar_today),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(selectedStartDate),
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // --- 2. 租期选择 ---
                      InputDecorator(
                        decoration: getBoxDecoration('Duration', Icons.timer),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedDurationMonths,
                            dropdownColor: const Color(0xFF295a68), // 深色菜单背景
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            isExpanded: true,
                            isDense: true,
                            items: [6, 12, 24, 36].map((months) {
                              return DropdownMenuItem(
                                value: months,
                                child: Text("$months Months (${(months/12).toStringAsFixed(1)} Years)"),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => selectedDurationMonths = val);
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Row(
                          children: [
                            Icon(Icons.event_available, size: 14, color: Colors.blue[200]),
                            const SizedBox(width: 6),
                            // ✅ 字体颜色：深蓝色
                            Text(
                              "Contract Ends: ${DateFormat('dd/MM/yyyy').format(endDate)}",
                              style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      
                      // --- 3. 留言框 (样式已修复) ---
                      TextField(
                        controller: noteController,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        // ✅ 使用统一的样式
                        decoration: getBoxDecoration('Note to Landlord (Optional)', Icons.edit_note).copyWith(
                          alignLabelWithHint: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // --- 4. 按钮 ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx), 
                            child: const Text("Cancel", style: TextStyle(color: Colors.white70))
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              shadowColor: primaryBlue.withOpacity(0.5),
                              elevation: 5,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx); 
                              if (docId == null) return;
                              try {
                                await FirebaseFirestore.instance
                                    .collection('bookings')
                                    .doc(docId)
                                    .update({
                                      'status': 'application_pending',
                                      'applicationNote': noteController.text.trim(),
                                      'appliedAt': Timestamp.now(),
                                      'leaseStartDate': Timestamp.fromDate(selectedStartDate),
                                      'leaseEndDate': Timestamp.fromDate(endDate),
                                    });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Application Sent!"), backgroundColor: Colors.green),
                                );
                              } catch (e) {
                                print(e);
                              }
                            },
                            child: const Text("Submit Application", style: TextStyle(fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String propertyId = bookingData['propertyId'];
    final Timestamp meetingTimestamp = bookingData['meetingTime'];
    final String meetingPoint = bookingData['meetingPoint'];
    final String status = bookingData['status'] ?? 'Unknown';
    final String formattedTime = DateFormat('dd MMM, hh:mm a').format(meetingTimestamp.toDate());

    // 状态颜色逻辑
    final bool isPending = status == 'application_pending';
    final Color currentStatusColor = isPending ? Colors.orangeAccent : statusColor;
    final IconData currentStatusIcon = isPending ? Icons.hourglass_top : statusIcon;
    final String displayStatus = isPending ? "PENDING APPROVAL" : status.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0), 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _getPropertyName(propertyId),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? 'Loading...',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: currentStatusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: currentStatusColor.withOpacity(0.6), width: 0.8),
                    ),
                    child: Row(
                      children: [
                        Icon(currentStatusIcon, color: currentStatusColor, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          displayStatus,
                          style: TextStyle(color: currentStatusColor, fontWeight: FontWeight.w600, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 16), 
              
              Row(children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(formattedTime, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ]),
              const SizedBox(height: 4), 
              Row(children: [
                const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(meetingPoint, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
              ]),

              // 按钮区域
              if (status == 'approved') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40, 
                  child: ElevatedButton.icon(
                    onPressed: () => _showApplicationDialog(context), 
                    icon: const Icon(Icons.assignment_turned_in, size: 16),
                    label: const Text('Apply for Rent', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D5DC7),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],

              if (status == 'application_pending') ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
                      SizedBox(width: 8),
                      Text("Pending Landlord Approval...", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],

              if (status == 'ready_to_sign') ...[
                 const SizedBox(height: 12),
                 SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (docId != null && bookingData['contractUrl'] != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SignContractScreen(
                              docId: docId!,
                              contractUrl: bookingData['contractUrl'], 
                            ),
                          ),
                        );
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Contract URL missing or Doc ID missing")));
                      }
                    },
                    icon: const Icon(Icons.edit_document, size: 16),
                    label: const Text('Sign Contract', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF295a68), 
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
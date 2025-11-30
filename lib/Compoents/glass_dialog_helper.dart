import 'dart:ui';

import 'package:flutter/material.dart';

// ✅ 通用的毛玻璃确认弹窗
Future<bool?> showGlassConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  required String confirmBtnText,
  required IconData icon,
  bool isDestructive = true, // 是否是破坏性操作（红色）
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
                Icon(icon, color: Colors.white70, size: 40),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(content, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Cancel 按钮
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
                    // Confirm 按钮
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          // 根据是否破坏性操作，改变渐变色 (红色 或 青蓝色)
                          gradient: LinearGradient(
                            colors: isDestructive 
                                ? [const Color(0xFFE53935), const Color(0xFFEF5350)] // 红色渐变
                                : [const Color(0xFF1D5DC7), const Color(0xFF42A5F5)], // 蓝色渐变
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isDestructive ? Colors.redAccent : Colors.blueAccent).withOpacity(0.4), 
                              blurRadius: 8, 
                              offset: const Offset(0, 3)
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(confirmBtnText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
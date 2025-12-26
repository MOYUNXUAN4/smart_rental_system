import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:smart_rental_system/Compoents/glass_dialog_helper.dart';
import 'package:smart_rental_system/main.dart'; // 引用你的 navigatorKey

class ConnectivityHelper {
  /// 核心方法：检查网络。如果断网，弹出毛玻璃对话框并返回 false。
  static Future<bool> hasConnection() async {
    var results = await Connectivity().checkConnectivity();
    
    // 如果没有网络连接
    if (results.contains(ConnectivityResult.none)) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        // 强制弹出弹窗
        await showGlassConfirmDialog(
          context: context,
          title: "Action Required",
          content: "This action requires an active internet connection. Please check your settings.",
          confirmBtnText: "Retry",
          icon: Icons.signal_wifi_connected_no_internet_4_rounded,
          isDestructive: true,
        );
      }
      return false; // 代表断网
    }
    return true; // 代表网络正常
  }
}
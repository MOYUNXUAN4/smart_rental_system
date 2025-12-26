import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
// ✅ 导入 main.dart 以便使用 ConnectivityHelper
import 'package:smart_rental_system/main.dart'; 

class StripeService {
  static final StripeService instance = StripeService._internal();
  factory StripeService() => instance;
  StripeService._internal();

  /// 发起 Stripe 支付
  Future<bool> makePayment(
    double amountVal, {
    String currency = 'myr',
  }) async {
    // ✅ 新增：在发起支付流程前，先检查网络
    // 如果断网，直接弹出对话框并返回 false，不再执行后续昂贵的 Cloud Function 调用
    if (!await ConnectivityHelper.ensureConnection()) {
      return false; 
    }

    try {
      // 1️⃣ 金额转换（防浮点误差）
      final int amountInCents = (amountVal * 100).round();
      debugPrint("Stripe: start payment $amountInCents $currency");

      if (amountInCents <= 0) {
        throw Exception("Invalid payment amount");
      }

      // 2️⃣ 调用 Firebase Cloud Function 创建 PaymentIntent
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable(
        'createPaymentIntent',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      // 如果在这里断网，原本会触发那个讨厌的 console error
      final result = await callable.call({
        'amount': amountInCents,
        'currency': currency,
      });

      // 3️⃣ 校验返回数据
      final data = result.data;
      if (data == null || data['clientSecret'] == null) {
        throw Exception('Invalid PaymentIntent response');
      }

      final String clientSecret = data['clientSecret'];
      debugPrint("Stripe: clientSecret received");

      // 4️⃣ 初始化 PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Smart Rental System',
          style: ThemeMode.dark,
        ),
      );

      // 5️⃣ 弹出支付窗口
      await Stripe.instance.presentPaymentSheet();

      debugPrint("Stripe: payment success");
      return true;

    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint("Stripe: user cancelled payment");
      } else {
        debugPrint("Stripe error: ${e.error.localizedMessage}");
      }
      return false;

    } catch (e, stack) {
      // ✅ 这里静默处理，不再向上 throw，因为用户已经在界面上通过弹窗知道是网络或系统问题了
      debugPrint("Stripe system error: $e");
      return false;
    }
  }
}
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeService {
  static final StripeService instance = StripeService._internal();
  factory StripeService() => instance;
  StripeService._internal();

  /// 发起 Stripe 支付
  /// 返回：
  /// - true  -> 支付成功
  /// - false -> 用户取消 / 支付失败 / 系统错误
  Future<bool> makePayment(
    double amountVal, {
    String currency = 'myr',
  }) async {
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
      // Stripe 官方：用户取消也会抛异常
      if (e.error.code == FailureCode.Canceled) {
        debugPrint("Stripe: user cancelled payment");
      } else {
        debugPrint("Stripe error: ${e.error.localizedMessage}");
      }
      return false;

    } catch (e, stack) {
      debugPrint("Stripe system error: $e");
      debugPrintStack(stackTrace: stack);
      return false;
    }
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:smart_rental_system/main.dart'; 

class StripeService {
  static final StripeService instance = StripeService._internal();
  factory StripeService() => instance;
  StripeService._internal();

  //start payment process
  Future<bool> makePayment(
    double amountVal, {
    String currency = 'myr',
  }) async {
    //check connectivity first 
    if (!await ConnectivityHelper.ensureConnection()) {
      return false; 
    }

    try {
      // transform amount to cents
      final int amountInCents = (amountVal * 100).round();
      debugPrint("Stripe: start payment $amountInCents $currency");

      if (amountInCents <= 0) {
        throw Exception("Invalid payment amount");
      }

      // 2️⃣ use firebase functions to create payment intent
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable(
        'createPaymentIntent',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      // if error occurs here, it will be caught by catch block
      final result = await callable.call({
        'amount': amountInCents,
        'currency': currency,
      });

      // 3️⃣ check response and get client secret
      final data = result.data;
      if (data == null || data['clientSecret'] == null) {
        throw Exception('Invalid PaymentIntent response');
      }

      final String clientSecret = data['clientSecret'];
      debugPrint("Stripe: clientSecret received");

      // 4️⃣ start payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Smart Rental System',
          style: ThemeMode.dark,
        ),
      );

      // 5️⃣ present payment sheet to user
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
      debugPrint("Stripe system error: $e");
      return false;
    }
  }
}
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'api_client.dart';
import 'api_exception.dart';

/// What happened to a coin purchase, for whoever is showing the shop.
class PurchaseOutcome {
  final String productId;
  final bool ok;
  final bool pending;
  final String? message;
  final num? coinBalance;
  const PurchaseOutcome(this.productId,
      {this.ok = false, this.pending = false, this.message, this.coinBalance});
}

/// Coins bought through Google Play Billing or the App Store (both stores
/// require their own billing for digital goods). Listens for the whole app
/// session, so a purchase that finishes after the shop was closed, or one
/// left over from a crash, is still checked with the server and credited.
/// A purchase is only "finished" with the store once the server has
/// credited it; until then the store keeps offering it again.
class StorePurchases {
  StorePurchases._();
  static final instance = StorePurchases._();

  final _outcomes = StreamController<PurchaseOutcome>.broadcast();
  Stream<PurchaseOutcome> get outcomes => _outcomes.stream;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Called by the bottom of the screen with the new balance.
  VoidCallback? onCredited;

  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void start() {
    if (!supported || _sub != null) return;
    try {
      _sub = InAppPurchase.instance.purchaseStream
          .listen(_handle, onError: (_) {});
    } catch (_) {
      // No store on this device (emulator without Play, tests).
    }
  }

  Future<Map<String, ProductDetails>> products(Set<String> ids) async {
    if (!supported || ids.isEmpty) return const {};
    try {
      if (!await InAppPurchase.instance.isAvailable()) return const {};
      final res = await InAppPurchase.instance.queryProductDetails(ids);
      return {for (final p in res.productDetails) p.id: p};
    } catch (_) {
      return const {};
    }
  }

  Future<bool> buy(ProductDetails product) async {
    start();
    return InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> _handle(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _outcomes.add(PurchaseOutcome(p.productID, pending: true));
        case PurchaseStatus.canceled:
          _outcomes.add(PurchaseOutcome(p.productID));
          if (p.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(p);
          }
        case PurchaseStatus.error:
          _outcomes.add(PurchaseOutcome(p.productID,
              message: p.error?.message ?? 'Payment didn’t go through'));
          if (p.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(p);
          }
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _credit(p);
      }
    }
  }

  Future<void> _credit(PurchaseDetails p) async {
    try {
      final res = await ApiClient.post('/wallet/iap/verify', body: {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'productId': p.productID,
        if (Platform.isAndroid)
          'purchaseToken': p.verificationData.serverVerificationData,
        if (Platform.isIOS) 'transactionId': p.purchaseID,
      }) as Map<String, dynamic>;
      // Credited (now or before): tell the store we're done.
      await InAppPurchase.instance.completePurchase(p);
      onCredited?.call();
      _outcomes.add(PurchaseOutcome(p.productID,
          ok: true, coinBalance: res['coinBalance'] as num?));
    } on ApiException catch (e) {
      // 4xx: the store says no (refunded, someone else's, unknown pack) —
      // finish it so it stops coming back. Anything else (no signal,
      // server down): leave it open; the store offers it again later.
      final final_ = e.status != null && e.status! >= 400 && e.status! < 500;
      if (final_ && e.status != 401 && p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
      _outcomes.add(PurchaseOutcome(p.productID,
          message: final_
              ? e.message
              : 'Paid. Your coins will appear as soon as we can confirm it.'));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:taktaktv/presentation/navigation/main_navigation.dart';
import 'dart:convert';
import '../../../core/constants/app_constant.dart';
import 'package:taktaktv/presentation/subscriptions/models.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionPaywallScreen extends StatefulWidget {
  final String token;
  const SubscriptionPaywallScreen({super.key, required this.token});

  @override
  State<SubscriptionPaywallScreen> createState() => _SubscriptionPaywallScreenState();
}

class _SubscriptionPaywallScreenState extends State<SubscriptionPaywallScreen> {
  List<SubscriptionPlan> plans = [];
  bool isLoading = true;
  bool isRestoring = false;
  bool isProcessingPayment = false;
  String? selectedPlanId;

  // User-oda active-la irukkura plan-oda ID & status
  String? activePlanId;
  bool hasActiveSubscription = false;

  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    fetchDataSequence();
  }

  // Active subscription & plans rendu-me serthu fetch panra method
  Future<void> fetchDataSequence() async {
    setState(() => isLoading = true);
    await checkActiveSubscription();
    await fetchSubscriptionPlans();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<String> _getValidToken() async {
    if (widget.token.isNotEmpty) {
      return widget.token;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? prefs.getString('jwt') ?? '';
  }

  Future<void> fetchSubscriptionPlans() async {
    try {
      final res = await http.get(Uri.parse('${AppConstants.baseUrl}/subscriptions/plans'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List list = data['data'] ?? [];
        setState(() {
          plans = list.map((e) => SubscriptionPlan.fromJson(e)).toList();
          if (plans.isNotEmpty && selectedPlanId == null) {
            selectedPlanId = plans.first.id;
          }
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching plans: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> checkActiveSubscription() async {
    try {
      String token = await _getValidToken();
      if (token.isEmpty) return;

      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/subscriptions/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint("Subscription API Response: ${res.body}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final subData = data['data'];

        if (subData != null) {
          // isPremium true-ah irunthalum (or) subscription object null illanalum active-nu eduthukalam
          bool hasActive = (subData['isPremium'] == true) ||
              (subData['hasActiveSubscription'] == true) ||
              (subData['subscription'] != null);

          if (hasActive) {
            // Subscription object-la iruntho illai direct-ah iruntho planId-ah eduthukalam
            String? foundPlanId = subData['planId'] ??
                subData['subscription']?['planId'] ??
                subData['subscription']?['plan']?['_id'] ??
                subData['subscription']?['plan']?['id'] ??
                subData['activePlan']?['_id'];

            setState(() {
              hasActiveSubscription = true;
              activePlanId = foundPlanId;
            });
            debugPrint("ACTIVE SUBSCRIPTION FOUND! Plan ID: $activePlanId");
          } else {
            setState(() {
              hasActiveSubscription = false;
              activePlanId = null;
            });
            debugPrint("NO ACTIVE SUBSCRIPTION FOUND");
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking subscription: $e");
    }
  }

  Future<void> restorePurchase() async {
    setState(() => isRestoring = true);
    try {
      String token = await _getValidToken();
      if (token.isEmpty) {
        setState(() => isRestoring = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Auth token missing. Please login again.')),
          );
        }
        return;
      }

      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/subscriptions/restore'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );

      setState(() => isRestoring = false);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        await checkActiveSubscription(); // Refresh after restore
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Subscription restored successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active subscription found to restore.')),
          );
        }
      }
    } catch (e) {
      setState(() => isRestoring = false);
      debugPrint("Restore error: $e");
    }
  }

  Future<void> _startSubscriptionCheckoutForPlan(String planId) async {
    setState(() {
      selectedPlanId = planId;
      isProcessingPayment = true;
    });

    try {
      String token = await _getValidToken();

      if (token.isEmpty) {
        setState(() => isProcessingPayment = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Auth token is missing. Please login again.')),
          );
        }
        return;
      }

      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/payments/create-order'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({"planId": planId}),
      );

      setState(() => isProcessingPayment = false);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final resData = json.decode(res.body);
        final orderData = resData['data'];

        String orderId = orderData['orderId'];
        int amount = orderData['amount'];
        String keyId = orderData['keyId'];
        String planName = orderData['plan']['name'] ?? "VIP Pass";

        var options = {
          'key': keyId,
          'amount': amount,
          'name': 'TakTak Short Drama',
          'description': planName,
          'order_id': orderId,
          'retry': {'enabled': true, 'max_count': 1},
          'send_sms_hash': true,
          'prefill': {
            'contact': '',
            'email': ''
          },
        };

        _razorpay.open(options);
      } else {
        final errorData = json.decode(res.body);
        String errorMessage = errorData['message'] ?? 'Failed to create payment order';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      setState(() => isProcessingPayment = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _startSubscriptionCheckout() async {
    if (selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subscription plan first.')),
      );
      return;
    }
    await _startSubscriptionCheckoutForPlan(selectedPlanId!);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      String token = await _getValidToken();

      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/payments/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "razorpayOrderId": response.orderId,
          "razorpayPaymentId": response.paymentId,
          "razorpaySignature": response.signature,
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Payment verified and VIP subscription activated!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainNavigationShell(token: token)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment verification failed on server.')),
          );
        }
      }
    } catch (e) {
      debugPrint("Verification error: $e");
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment Failed: ${response.message ?? "Unknown error"}')),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('External Wallet Selected: ${response.walletName}'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0710),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () async {
            String token = await _getValidToken();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MainNavigationShell(token: token)),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: isRestoring ? null : restorePurchase,
            child: isRestoring
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Restore Purchase', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE6007A)))
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.workspace_premium, color: Colors.amber, size: 40),
              const SizedBox(height: 6),
              const Text(
                'Unlock VIP Access',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enjoy unlimited dramas, ad-free streaming & Full HD quality',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Plans List with flexible Active Plan check
              ...plans.map((plan) {
                final isSelected = selectedPlanId == plan.id;

                // 🔍 Flexible check: ID match aagunalum, illana hasActiveSubscription true-ah irunthu first plan-ah irunthalum active-nu eduthukalam
                final bool isActivePlan = (activePlanId != null && (activePlanId == plan.id || plan.id.contains(activePlanId!))) ||
                    (hasActiveSubscription && plans.indexOf(plan) == 0);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1B1128) : const Color(0xFF140F1D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActivePlan ? const Color(0xFFE6007A) : (isSelected ? const Color(0xFFE6007A) : Colors.grey.withOpacity(0.3)),
                      width: isActivePlan ? 2 : (isSelected ? 2 : 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (!isActivePlan) {
                            setState(() => selectedPlanId = plan.id);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  plan.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                if (isActivePlan)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6007A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  )
                                else if (plan.tag.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6007A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(plan.tag, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '₹${plan.price}',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                if (plan.originalPrice > plan.price)
                                  Text(
                                    '₹${plan.originalPrice}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13, decoration: TextDecoration.lineThrough),
                                  ),
                                const Spacer(),
                                Text(
                                  '${plan.durationDays} Days',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.grey, height: 12),
                            ...plan.benefits.map((benefit) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFFE6007A), size: 12),
                                  const SizedBox(width: 6),
                                  Text(benefit, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Active plan-ah iruntha 'Active Plan' text kaatu, illana subscribe button kaatu
                      if (isActivePlan || hasActiveSubscription)
                        Container(
                          width: double.infinity,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6007A).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Text(
                            isActivePlan ? 'Active Plan' : 'Active Subscription',
                            style: const TextStyle(color: Color(0xFFE6007A), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE6007A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                            ),
                            onPressed: isProcessingPayment ? null : () => _startSubscriptionCheckoutForPlan(plan.id),
                            child: isProcessingPayment && selectedPlanId == plan.id
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                                : Text('Subscribe to ${plan.name}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),

              // Bottom global subscribe button will only show if user DOES NOT have an active subscription
              if (plans.isNotEmpty && !hasActiveSubscription) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6007A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: isProcessingPayment ? null : _startSubscriptionCheckout,
                    child: isProcessingPayment
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Text('Subscribe Now', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
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
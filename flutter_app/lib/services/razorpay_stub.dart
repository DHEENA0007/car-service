void openRazorpayWeb({
  required Map<String, dynamic> options,
  required void Function(String paymentId, String orderId, String signature) onSuccess,
  required void Function(String error) onError,
}) {
  throw UnsupportedError('openRazorpayWeb is only supported on web');
}

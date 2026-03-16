import 'dart:js_interop';
import 'dart:convert';

@JS('openRazorpay')
external void _jsOpenRazorpay(
  String optionsJson,
  JSFunction onSuccess,
  JSFunction onError,
);

void openRazorpayWeb({
  required Map<String, dynamic> options,
  required void Function(String paymentId, String orderId, String signature) onSuccess,
  required void Function(String error) onError,
}) {
  _jsOpenRazorpay(
    jsonEncode(options),
    ((JSAny? p, JSAny? o, JSAny? s) => onSuccess(
          p?.toString() ?? '',
          o?.toString() ?? '',
          s?.toString() ?? '',
        )).toJS,
    ((JSAny? e) => onError(e?.toString() ?? 'Payment failed.')).toJS,
  );
}

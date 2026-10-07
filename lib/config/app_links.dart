/// Outside links the app opens.
class AppLinks {
  AppLinks._();

  /// A WhatsApp chat link: `https://wa.me/<digits>[?text=...]`.
  ///
  /// [phone] may contain '+', spaces or dashes; only the digits are used,
  /// as each of today's three builders does. [text] is URL-encoded.
  static Uri whatsApp(String phone, {String? text}) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final query = (text == null || text.isEmpty) ? '' : '?text=${Uri.encodeComponent(text)}';
    return Uri.parse('https://wa.me/$digits$query');
  }
}

/// VetBiz support. Kept as a constant for now; making it editable by the
/// platform admin is optional step 2H.
class AppContact {
  AppContact._();

  static const String supportPhone = '+255719199916';
}

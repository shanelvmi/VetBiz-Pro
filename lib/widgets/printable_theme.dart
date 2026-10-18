import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_theme.dart';

/// Keeps what is printed, shared as an image or shown as a printable page
/// (the sale and service receipt previews, the A4 PdfPreview, the client card
/// PNG) Pasture light in every app mode and every colour theme (D11; the T0
/// decision: receipts stay Pasture), so the picture a customer gets never
/// depends on the phone's settings. The buttons and panels around it follow
/// the app theme.
///
/// [builder] gets a context under the light theme: read `context.colors`
/// from THAT context. The text default is set again from the light theme
/// too, because a `Theme` alone keeps the dark Material's text colour above
/// it, and the receipts draw some text with no colour of their own.
class PrintableTheme extends StatelessWidget {
  final WidgetBuilder builder;

  const PrintableTheme({super.key, required this.builder});

  static final ThemeData data = AppTheme.build(AppColorTheme.pasture, Brightness.light);

  @override
  Widget build(BuildContext context) => Theme(
        data: data,
        child: Builder(
          builder: (context) => DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyMedium!,
            child: Builder(builder: builder),
          ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

/// Custom inline markdown syntax for per-selection color, since
/// standard markdown has no color syntax at all - {color:#RRGGBB}text{/color}
/// wraps just the colored portion, the same way **bold** wraps just
/// its portion. Shared between the editor's live preview and the
/// actual display, so both parse identically.
class ColorSyntax extends md.InlineSyntax {
  ColorSyntax() : super(r'\{color:(#[0-9A-Fa-f]{6})\}(.*?)\{/color\}');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final colorHex = match.group(1)!;
    final text = match.group(2)!;
    final el = md.Element.text('coloredspan', text);
    el.attributes['data-color'] = colorHex;
    parser.addNode(el);
    return true;
  }
}

/// Renders whatever ColorSyntax matched as colored text - registered
/// alongside it wherever announcement text is parsed.
class ColorBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final colorHex = element.attributes['data-color'];
    final color = colorHex != null
        ? Color(int.parse(colorHex.replaceFirst('#', '0xFF')))
        : null;
    return Text(element.textContent, style: preferredStyle?.copyWith(color: color));
  }
}

/// Renders an announcement's message consistently everywhere it's shown
/// (login screen, the urgent-announcements banner, the Platform Admin's
/// own list) - markdown formatting (**bold**, _italic_, [links](url),
/// and the custom {color:#hex}...{/color} for per-selection color) via
/// flutter_markdown, with tappable links opening externally.
class AnnouncementMessage extends StatelessWidget {
  final Map<String, dynamic> data;
  final double fontSize;

  const AnnouncementMessage({super.key, required this.data, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final message = (data['message'] ?? '').toString();

    return MarkdownBody(
      data: message,
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, ColorSyntax()],
      ),
      builders: {'coloredspan': ColorBuilder()},
      onTapLink: (text, href, title) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: fontSize),
        a: TextStyle(fontSize: fontSize, color: Colors.blue, decoration: TextDecoration.underline),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool shadow; // new parameter
  final String? subtitle; // optional small caption, e.g. a period label
  // or "as of now" - lets a card clarify what the figure means without
  // needing a second widget.
  final bool isLoading; // shows a small spinner in place of the value

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.shadow = false, // default false
    this.subtitle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: shadow ? 6 : 2, // uses shadow parameter
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Scale down based on the card's OWN rendered width - this way
          // it stays readable whether it's in a 2-column grid on a small
          // phone or a 4-column grid on a desktop, without the parent
          // screen needing to know anything about it.
          final isCompact = constraints.maxWidth < 160;
          final avatarRadius = isCompact ? 16.0 : 20.0;
          final titleSize = isCompact ? 11.0 : 12.0;
          final valueSize = isCompact ? 12.0 : 14.0;

          return Padding(
            padding: EdgeInsets.all(isCompact ? 8 : 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Icon(icon, color: color, size: avatarRadius),
                ),
                SizedBox(height: isCompact ? 6 : 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: titleSize,
                  ),
                ),
                const SizedBox(height: 4),
                if (isLoading)
                  SizedBox(
                    height: valueSize + 4,
                    width: valueSize + 4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  // FittedBox instead of ellipsis for the value: a
                  // truncated money figure ("Tsh 12,345,6...") could be
                  // dangerously misleading - shrinking it to fit is safer
                  // than cutting characters off.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: valueSize,
                      ),
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 9 : 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

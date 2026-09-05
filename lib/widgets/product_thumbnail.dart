import 'package:flutter/material.dart';

/// A product thumbnail - shows the uploaded photo when one exists,
/// falling back to a generic inventory icon (not initials - products
/// aren't people) when it doesn't. Also covers a broken or expired
/// photo URL, since the same fallback renders if the image fails to
/// load, not just when there's no URL at all.
///
/// Fully flexible on width/height/corner-rounding, since it now covers
/// two quite different shapes: a small square list-row thumbnail
/// (use .square()) and a large, non-square, top-only-rounded card
/// header image.
class ProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color iconColor;

  const ProductThumbnail({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.backgroundColor,
    required this.iconColor,
  });

  /// The common case: a small, fully-rounded square thumbnail for a
  /// list row or table cell - matches the original widget's own
  /// default shape (rounded square, not a circle - inventory items,
  /// not people).
  factory ProductThumbnail.square({
    Key? key,
    required String? imageUrl,
    required double size,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return ProductThumbnail(
      key: key,
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size * 0.22),
      backgroundColor: backgroundColor,
      iconColor: iconColor,
    );
  }

  Widget _fallback() {
    final iconSize = (width < height ? width : height) * 0.4;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: backgroundColor,
      child: Icon(Icons.inventory_2_outlined, color: iconColor, size: iconSize),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageUrl != null && imageUrl!.isNotEmpty;
    return ClipRRect(
      borderRadius: borderRadius,
      child: hasPhoto
          ? Image.network(
              imageUrl!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _fallback(),
            )
          : _fallback(),
    );
  }
}

import 'package:flutter/material.dart';

class CatalogImage extends StatelessWidget {
  final String? imageUrl;
  final Widget placeholder;
  final BoxFit fit;

  const CatalogImage({
    super.key,
    required this.imageUrl,
    required this.placeholder,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return placeholder;

    return Image.network(
      url,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return placeholder;
      },
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

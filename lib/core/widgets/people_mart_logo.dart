import 'package:flutter/material.dart';

/// The shared People Mart wordmark used in application branding surfaces.
class PeopleMartLogo extends StatelessWidget {
  final double width;
  final double height;
  final bool onDarkBackground;

  const PeopleMartLogo({
    super.key,
    required this.width,
    required this.height,
    this.onDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/branding/people_mart_logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'People Mart',
    );
    if (!onDarkBackground) return logo;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: logo,
    );
  }
}

/// Compact emblem derived from the supplied wordmark for app bars and navigation.
class PeopleMartLogoMark extends StatelessWidget {
  final double size;

  const PeopleMartLogoMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/people_mart_app_icon.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticLabel: 'People Mart logo',
  );
}

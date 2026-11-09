import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class BrandedPromotionalFooter extends StatelessWidget {
  final VoidCallback? onSeeAllTap;
  final String fssaiLicense;

  const BrandedPromotionalFooter({
    super.key,
    this.onSeeAllTap,
    this.fssaiLicense = '10018064001234',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isCompact = screenWidth < 360;

        return CustomPaint(
          painter: _FooterCurvePainter(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 24, 10, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main Row: Leaves + Badge + Divider + FSSAI + Scooter
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Floating Leaves on left edge
                    Positioned(
                      left: 2,
                      top: 14,
                      child: Image.asset(
                        'assets/images/home/footer_leaves.png',
                        width: 24,
                        height: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left Section: Delivery Promise Badge
                          Image.asset(
                            'assets/images/home/footer_badge.png',
                            width: isCompact ? 80 : 96,
                            height: isCompact ? 80 : 96,
                            fit: BoxFit.contain,
                          ),

                          // Vertical divider line
                          Container(
                            height: 54,
                            width: 1.2,
                            margin: EdgeInsets.symmetric(
                              horizontal: isCompact ? 6 : 10,
                            ),
                            color: const Color(0xFF6B21A8).withValues(alpha: 0.35),
                          ),

                          // Middle Section: FSSAI Logo & License Number
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/home/footer_fssai.png',
                                height: isCompact ? 28 : 34,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lic. No. $fssaiLicense',
                                style: TextStyle(
                                  fontSize: isCompact ? 8.5 : 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 4),

                          // Right Section: Delivery Scooter Rider
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Image.asset(
                                'assets/images/home/footer_scooter.png',
                                height: isCompact ? 95 : 110,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Footer Tagline: "People Mart brings fresh joy to your doorstep"
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: isCompact ? 12.5 : 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -0.2,
                        ),
                        children: const [
                          TextSpan(text: 'People Mart brings '),
                          TextSpan(
                            text: 'fresh joy',
                            style: TextStyle(
                              color: AppColors.accentPink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(text: ' to your doorstep'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    // Pink brush stroke underline
                    Image.asset(
                      'assets/images/home/footer_brush.png',
                      width: isCompact ? 54 : 64,
                      height: 6,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        width: 50,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: AppColors.accentPink,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Backward compatibility alias for any existing imports
typedef ZeptoFooter = BrandedPromotionalFooter;

class _FooterCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top boundary flowing gentle curve
    final path = Path()
      ..moveTo(0, 18)
      ..cubicTo(
        size.width * 0.25,
        34,
        size.width * 0.70,
        0,
        size.width,
        14,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFFFF7FC),
        const Color(0xFFFDF0F8),
        const Color(0xFFFBE4F2),
      ],
      stops: const [0.0, 0.4, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    // Decorative soft pink curved accent in the top right
    final accentPath = Path()
      ..moveTo(size.width * 0.65, 8)
      ..cubicTo(
        size.width * 0.82,
        0,
        size.width * 0.94,
        18,
        size.width,
        14,
      )
      ..lineTo(size.width, 60)
      ..cubicTo(
        size.width * 0.85,
        45,
        size.width * 0.72,
        30,
        size.width * 0.65,
        8,
      )
      ..close();

    final accentPaint = Paint()
      ..color = const Color(0xFFF7CFE2).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    canvas.drawPath(accentPath, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

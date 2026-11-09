import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class GiftBanner extends StatelessWidget {
  final VoidCallback? onEnterCodeTap;

  const GiftBanner({
    super.key,
    this.onEnterCodeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF6EEFC), Color(0xFFEFE5F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4D3F5)),
        ),
        child: Row(
          children: [
            // Left text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(text: 'Your '),
                        TextSpan(
                          text: 'FREE Gift',
                          style: TextStyle(
                            color: Color(0xFF6B21A8),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: ' is waiting!'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Enter a referral code to claim it now',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right Pill Button
            ElevatedButton(
              onPressed: onEnterCodeTap ??
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referral code feature coming soon!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter Code',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

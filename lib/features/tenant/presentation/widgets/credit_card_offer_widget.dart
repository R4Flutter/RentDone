import 'package:flutter/material.dart';

class CreditCardOfferWidget extends StatelessWidget {
  const CreditCardOfferWidget({
    super.key,
    required this.onApplyNow,
    this.title = 'Get Credit Card and Save Rs 50',
    this.subtitle = 'Pay rent with credit card and earn cashback rewards',
    this.ctaLabel = 'Apply Now',
  });

  final VoidCallback onApplyNow;
  final String title;
  final String subtitle;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF1F6CFF).withValues(alpha: 0.16),
            const Color(0xFF6A63FF).withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF6A63FF).withValues(alpha: 0.22),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF1F6CFF).withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: onApplyNow,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF245DFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: Text(ctaLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

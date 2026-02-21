import 'package:rentdone/features/owner/owner_support/domain/entities/support_faq.dart';

class SupportFaqDto {
  final String question;

  const SupportFaqDto({required this.question});

  SupportFaq toEntity() {
    return SupportFaq(question: question);
  }
}

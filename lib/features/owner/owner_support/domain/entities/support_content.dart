import 'package:rentdone/features/owner/owner_support/domain/entities/support_contact.dart';
import 'package:rentdone/features/owner/owner_support/domain/entities/support_faq.dart';

class SupportContent {
  final List<SupportFaq> faqs;
  final List<SupportContact> contacts;

  const SupportContent({required this.faqs, required this.contacts});
}

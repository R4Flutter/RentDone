import 'package:rentdone/features/owner/owner_support/data/models/support_contact_dto.dart';
import 'package:rentdone/features/owner/owner_support/data/models/support_content_dto.dart';
import 'package:rentdone/features/owner/owner_support/data/models/support_faq_dto.dart';

class SupportLocalService {
  SupportContentDto getSupportContent() {
    return const SupportContentDto(
      faqs: [
        SupportFaqDto(question: 'How do I add a tenant?'),
        SupportFaqDto(question: 'How do I mark a payment as paid?'),
        SupportFaqDto(question: 'How do I generate reports?'),
      ],
      contacts: [
        SupportContactDto(
          type: 'email',
          title: 'Email',
          subtitle: 'support@rentdone.app',
        ),
        SupportContactDto(
          type: 'phone',
          title: 'Phone',
          subtitle: '+91 90000 00000',
        ),
      ],
    );
  }
}

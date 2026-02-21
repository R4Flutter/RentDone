import 'package:rentdone/features/owner/owner_support/data/models/support_contact_dto.dart';
import 'package:rentdone/features/owner/owner_support/data/models/support_faq_dto.dart';
import 'package:rentdone/features/owner/owner_support/domain/entities/support_content.dart';

class SupportContentDto {
  final List<SupportFaqDto> faqs;
  final List<SupportContactDto> contacts;

  const SupportContentDto({required this.faqs, required this.contacts});

  SupportContent toEntity() {
    return SupportContent(
      faqs: faqs.map((entry) => entry.toEntity()).toList(),
      contacts: contacts.map((entry) => entry.toEntity()).toList(),
    );
  }
}

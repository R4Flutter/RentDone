import 'package:rentdone/features/owner/owner_support/domain/entities/support_contact.dart';

class SupportContactDto {
  final String type;
  final String title;
  final String subtitle;

  const SupportContactDto({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  SupportContact toEntity() {
    return SupportContact(type: type, title: title, subtitle: subtitle);
  }
}

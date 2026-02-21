import 'package:rentdone/features/owner/owners_properties/domain/entities/property.dart';
import 'package:rentdone/features/owner/owners_properties/domain/entities/tenant.dart';

abstract class OwnerTenantsRepository {
  Stream<List<Tenant>> watchAllTenants();
  Stream<List<Property>> watchAllProperties();
}

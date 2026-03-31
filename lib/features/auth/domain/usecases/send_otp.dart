import 'package:rentdone/features/auth/domain/repositories/auth_repository.dart';

class SendOtp {
  final AuthRepository _repository;

  const SendOtp(this._repository);

  Future<void> call({required String phone}) {
    return _repository.sendOtp(phone: phone);
  }
}

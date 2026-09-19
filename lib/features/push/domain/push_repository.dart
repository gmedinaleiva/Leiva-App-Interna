abstract interface class PushRepository {
  Future<void> registerDevice({
    required String registrationToken,
    required String platform,
  });

  Future<void> replaceToken({
    required String previousToken,
    required String registrationToken,
  });

  Future<void> unregisterDevice();
}

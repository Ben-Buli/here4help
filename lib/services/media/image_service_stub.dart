/// Stub implementation for unsupported platforms
/// This file should never be imported directly
class PlatformImageService {
  static void throwUnsupportedError() {
    throw UnsupportedError('This platform is not supported');
  }
}

/// Chooses between the live API and the bundled mock data sources.
///
/// The app was built mock-first, so every feature has a `Mock*RemoteDataSource`
/// beside its real one. This is the single switch that decides which gets
/// registered, rather than a scattering of commented-out lines in each
/// feature's injection file.
///
/// Live is the default. Run against mocks with:
///
/// ```
/// flutter run --dart-define=USE_MOCK_DATA=true
/// ```
///
/// Mocks stay useful for demos, for offline UI work, and for widget tests that
/// should not depend on a reachable gateway — but a build that silently
/// defaults to them is a build that looks like it works and ships nothing.
abstract final class DataSourceMode {
  static const bool useMocks =
      bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);

  static bool get useLiveApi => !useMocks;
}

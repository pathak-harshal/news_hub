/// The build environment the app is running in.
///
/// Only [dev] exists today. `staging` and `prod` are added when
/// environments are revisited (project-structure.md §6, D7).
enum Flavor {
  dev;

  /// Parses the `FLAVOR` value from `env/<flavor>.json`.
  ///
  /// Throws a [FormatException] naming [name] if it is not a known flavor.
  static Flavor fromName(String name) {
    final Flavor? flavor = Flavor.values.asNameMap()[name];
    if (flavor == null) {
      final String allowed = Flavor.values.map((Flavor f) => f.name).join(', ');
      throw FormatException(
        'Unknown FLAVOR "$name". Expected one of: $allowed.',
      );
    }
    return flavor;
  }
}

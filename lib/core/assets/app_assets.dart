/// Every file the app loads from its bundle, in one place, named for what it
/// shows rather than how its file happens to be called. Widgets reference
/// these, never a raw `'assets/…'` string, so renaming or replacing artwork
/// is an edit here. `test/core/assets/app_assets_test.dart` checks that each
/// path exists and is declared in `pubspec.yaml`.
library;

/// The SteelForce and ISI Steel marks.
abstract final class AppLogos {
  /// The SteelForce lockup in dark ink — navy "Steel", blue "Force" — for
  /// light surfaces (`BrandLogo`).
  static const steelForceLockup = 'assets/logos/steelforce-logo.svg';

  /// The white version: white tile, white "Steel", light-blue "Force",
  /// "A member of ISI STEEL" — for dark surfaces and photography.
  static const steelForceLockupWhite = 'assets/logos/steelforce-logo-light.svg';

  /// The app-icon tile in Apex Blue, as the launcher shows it (About).
  static const steelForceAppIcon = 'assets/logos/steelforce-app-icon.png';

  /// The app-icon tile in white, for navy surfaces: the splash backdrop and
  /// the guest landing panel.
  static const steelForceAppIconWhite =
      'assets/logos/steelforce-app-icon-light.png';

  /// "SteelForce" alone in white and light blue, for navy surfaces.
  static const steelForceWordmarkWhite =
      'assets/logos/steelforce-wordmark-white.svg';

  /// The ISI Steel mark in navy (PDF header, captured-depot watermark).
  static const isiSteel = 'assets/logos/isi-steel-dark.svg';

  /// The ISI Steel mark in pale steel, for navy surfaces (guest landing).
  static const isiSteelLight = 'assets/logos/isi-steel-light.svg';
}

/// Photography and illustrations.
abstract final class AppImages {
  /// The Home hero: the ISI building and steel bars behind the greeting.
  static const homeHeroPhoto = 'assets/images/isi_main_app_bar_bg.png';

  /// The guest landing photo — the ISI tube mill, a bundle of box sections
  /// lifted over the line — also the cover of the app tour lesson.
  static const guestFactoryHero = 'assets/images/guest_factory_hero.jpg';

  /// The ISI chevron in Apex Blue, before Home headings (light theme).
  static const brandChevronBlue = 'assets/images/brand_chevron_blue.png';

  /// The ISI chevron in pale steel, before Home headings (dark theme).
  static const brandChevronSteel = 'assets/images/brand_chevron.png';

  /// App Coach lesson covers.
  static const lessonDepotsCover = 'assets/images/icons/manage_depots.png';
  static const lessonQuotationCover =
      'assets/images/icons/quoationlearning.png';
  static const lessonVisitCover =
      'assets/images/icons/stylized-travel-route-with-road-and-location-pins-symbols-for-navigation-and-journey-planning-png.webp';

  /// Inventory Visibility: the example photo for each of the three shots.
  static const inventoryGuideOverview =
      'assets/images/inventory_guide/images.jpeg';
  static const inventoryGuideStorage =
      'assets/images/inventory_guide/images (1).jpeg';
  static const inventoryGuideProduct =
      'assets/images/inventory_guide/structural-steel.jpg';

  /// The folder of product-category icons (`category_icons.dart`).
  static const productCategoryIconsFolder =
      'assets/images/icons/categories-icon/svg';
}

/// The coach mascot's Lottie animations.
abstract final class AppLotties {
  /// The default sticker: the mascot waving "Let's go!".
  static const coachLetsGo = 'assets/lotties/coach-letsgo.json';

  /// "Photo submitted": a photo flies into the bubble and a check lands.
  static const inventorySuccess = 'assets/lotties/inventory-success.json';

  /// Password reset, step 1: a phone number types in.
  static const phoneEntry = 'assets/lotties/input_phone_number.json';

  /// Password reset, step 2: six code boxes fill and turn green.
  static const verifyCode = 'assets/lotties/verify_token_code.json';

  /// Password reset, step 3: a password types in and the padlock shuts.
  static const newPassword = 'assets/lotties/input_new_password.json';

  /// The "coming soon" panel's sticker.
  static const comingSoon = 'assets/lotties/comming_soon.json';
}

/// Font files loaded by hand — the PDF builder embeds them; the app's own
/// text uses the families `pubspec.yaml` declares.
abstract final class AppFontFiles {
  static const sourceSansRegular =
      'assets/fonts/english/Source_Sans_3/static/SourceSans3-Regular.ttf';
  static const sourceSansBold =
      'assets/fonts/english/Source_Sans_3/static/SourceSans3-Bold.ttf';
  static const miSansKhmerRegular =
      'assets/fonts/khmer/MiSansKhmer-Regular.ttf';
  static const miSansKhmerBold = 'assets/fonts/khmer/MiSansKhmer-Bold.ttf';
}

/// Bundled data: translations, the geography seed, and the debug/QA mocks.
abstract final class AppDataAssets {
  /// The EN or KM translation bundle for [languageCode].
  static String languageBundle(String languageCode) =>
      'assets/lang/$languageCode.json';

  /// Cambodia's provinces, districts, communes and villages, seeded on
  /// first launch.
  static const cambodiaGeoSeed = 'assets/geo/kh_geo_seed_v1.json';

  /// Products for the mock data source (debug only).
  static const mockProducts = 'assets/mock/products.json';

  /// The mock camera's photos (debug/QA only), and three of them by name.
  static const mockCameraFolder = 'assets/mock/camera';
  static const mockStorefrontPhoto = 'assets/mock/camera/storefront.png';
  static const mockInsideStorePhoto = 'assets/mock/camera/inside_store.png';
  static const mockIdCardPhoto = 'assets/mock/camera/id_card.png';
}

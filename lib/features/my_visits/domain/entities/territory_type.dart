enum TerritoryType {
  urban,
  suburban,
  industrial,
  rural;

  /// Default geofence radius in meters for this territory class, per the
  /// business rule table — overridable per depot.
  double get defaultGeofenceRadiusMeters => switch (this) {
        TerritoryType.urban => 50,
        TerritoryType.suburban => 100,
        TerritoryType.industrial => 150,
        TerritoryType.rural => 250,
      };

  String get label => switch (this) {
        TerritoryType.urban => 'Urban',
        TerritoryType.suburban => 'Suburban',
        TerritoryType.industrial => 'Industrial',
        TerritoryType.rural => 'Rural',
      };
}

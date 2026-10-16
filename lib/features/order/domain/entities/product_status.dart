enum ProductStatus {
  active,
  inactive,
  discontinued;

  String get label => switch (this) {
        ProductStatus.active => 'Active',
        ProductStatus.inactive => 'Inactive',
        ProductStatus.discontinued => 'Discontinued',
      };
}

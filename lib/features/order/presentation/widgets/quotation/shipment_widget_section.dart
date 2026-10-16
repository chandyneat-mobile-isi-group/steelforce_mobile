import 'package:flutter/material.dart';

enum ShipmentMethod { pickup, delivery }

enum PickupLocation { factory, branch }

enum DeliveryAddressOption { defaultAddress, newAddress }

class ShipmentSelectionWidget extends StatelessWidget {
  const ShipmentSelectionWidget({
    super.key,
    required this.method,
    required this.pickupLocation,
    required this.deliveryOption,
    required this.isCod,
    this.isTaxApplicable = true,
    required this.onMethodChanged,
    required this.onPickupLocationChanged,
    required this.onDeliveryOptionChanged,
    required this.onCodChanged,
    this.onTaxApplicableChanged,
    this.selectedFactory,
    this.selectedBranch,
    this.onFactoryChanged,
    this.onBranchChanged,
    this.defaultAddress,
    this.newAddressController,
    this.newPhoneController,
    this.onAddressFieldsChanged,
  });

  final ShipmentMethod method;
  final PickupLocation? pickupLocation;
  final DeliveryAddressOption? deliveryOption;
  final bool isCod;
  final bool isTaxApplicable;

  final ValueChanged<ShipmentMethod> onMethodChanged;
  final ValueChanged<PickupLocation> onPickupLocationChanged;
  final ValueChanged<DeliveryAddressOption> onDeliveryOptionChanged;
  final ValueChanged<bool> onCodChanged;
  final ValueChanged<bool>? onTaxApplicableChanged;

  final String? selectedFactory;
  final String? selectedBranch;
  final ValueChanged<String?>? onFactoryChanged;
  final ValueChanged<String?>? onBranchChanged;

  final String? defaultAddress;
  final TextEditingController? newAddressController;
  final TextEditingController? newPhoneController;
  final VoidCallback? onAddressFieldsChanged;

  static const List<String> _mockFactories = [
    'Main Factory - Veng Sreng',
    'Factory 2 - Kilometer 6',
    'Factory 3 - Kandal',
    'Factory 4 - Kampong Speu',
    'Factory 5 - Sihanoukville SEZ',
  ];

  static const List<String> _mockBranches = [
    'Phnom Penh Branch - Toul Kork',
    'Siem Reap Branch',
    'Battambang Branch',
    'Kampong Cham Branch',
    'Takeo Branch',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    final headerTextStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize:
          isTablet ? (theme.textTheme.titleMedium?.fontSize ?? 16) * 1.3 : null,
      color: colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Step 1: Delivery vs Pick up
        Text('Method of shipment', style: headerTextStyle),
        SizedBox(height: isTablet ? 16 : 12),

        Row(
          children: [
            Expanded(
              child: _SelectCard(
                title: 'Delivery',
                icon: Icons.local_shipping_outlined,
                isSelected: method == ShipmentMethod.delivery,
                onTap: () => onMethodChanged(ShipmentMethod.delivery),
              ),
            ),
            SizedBox(width: isTablet ? 16 : 12),
            Expanded(
              child: _SelectCard(
                title: 'Pick up',
                icon: Icons.storefront_outlined,
                isSelected: method == ShipmentMethod.pickup,
                onTap: () => onMethodChanged(ShipmentMethod.pickup),
              ),
            ),
          ],
        ),

        SizedBox(height: isTablet ? 26 : 20),

        // 2. Step 2 (Conditional): Options based on selected shipment method
        if (method == ShipmentMethod.pickup) ...[
          Text('Pickup Location', style: headerTextStyle),
          SizedBox(height: isTablet ? 16 : 12),
          Row(
            children: [
              Expanded(
                child: _SelectCard(
                  title: 'Factory',
                  icon: Icons.factory_outlined,
                  isSelected: pickupLocation == PickupLocation.factory,
                  onTap: () => onPickupLocationChanged(PickupLocation.factory),
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: _SelectCard(
                  title: 'Branch',
                  icon: Icons.store_outlined,
                  isSelected: pickupLocation == PickupLocation.branch,
                  onTap: () => onPickupLocationChanged(PickupLocation.branch),
                ),
              ),
            ],
          ),
          if (pickupLocation == PickupLocation.factory) ...[
            SizedBox(height: isTablet ? 18 : 14),
            DropdownButtonFormField<String>(
              // Without this the button sizes itself to its widest *item*, and
              // "Main Factory - Veng Sreng" is wider than the field on every
              // phone — the row overflowed by 113pt at 360 and still by 43pt on
              // a 430pt Pro Max. Expanding lets the label ellipsize into the
              // space that exists instead of demanding space that does not.
              isExpanded: true,
              initialValue: _mockFactories.contains(selectedFactory)
                  ? selectedFactory
                  : _mockFactories.first,
              decoration: InputDecoration(
                labelText: 'Select Factory Location',
                prefixIcon:
                    Icon(Icons.factory_rounded, size: isTablet ? 28 : 24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 16 : 12,
                ),
              ),
              items: _mockFactories
                  .map((factory) => DropdownMenuItem(
                        value: factory,
                        child: Text(
                          factory,
                          style: TextStyle(fontSize: isTablet ? 17 : 13),
                        ),
                      ))
                  .toList(),
              onChanged: onFactoryChanged,
            ),
          ],
          if (pickupLocation == PickupLocation.branch) ...[
            SizedBox(height: isTablet ? 18 : 14),
            DropdownButtonFormField<String>(
              // Same reason as the factory dropdown above.
              isExpanded: true,
              initialValue: _mockBranches.contains(selectedBranch)
                  ? selectedBranch
                  : _mockBranches.first,
              decoration: InputDecoration(
                labelText: 'Select Branch Location',
                prefixIcon: Icon(Icons.store_rounded, size: isTablet ? 28 : 24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 16 : 12,
                ),
              ),
              items: _mockBranches
                  .map((branch) => DropdownMenuItem(
                        value: branch,
                        child: Text(
                          branch,
                          style: TextStyle(fontSize: isTablet ? 17 : 13),
                        ),
                      ))
                  .toList(),
              onChanged: onBranchChanged,
            ),
          ],
        ] else if (method == ShipmentMethod.delivery) ...[
          Text('Delivery Address', style: headerTextStyle),
          SizedBox(height: isTablet ? 16 : 12),
          _DeliveryOptionTile(
            title: 'Default address (follow SAP)',
            subtitle: defaultAddress,
            isSelected: deliveryOption == DeliveryAddressOption.defaultAddress,
            onTap: () =>
                onDeliveryOptionChanged(DeliveryAddressOption.defaultAddress),
          ),
          SizedBox(height: isTablet ? 14 : 10),
          _DeliveryOptionTile(
            title: 'Input new address & phone number',
            subtitle: null,
            isSelected: deliveryOption == DeliveryAddressOption.newAddress,
            onTap: () =>
                onDeliveryOptionChanged(DeliveryAddressOption.newAddress),
          ),
          if (deliveryOption == DeliveryAddressOption.newAddress) ...[
            SizedBox(height: isTablet ? 18 : 14),
            TextField(
              controller: newAddressController,
              maxLines: 2,
              style: TextStyle(fontSize: isTablet ? 17 : 14),
              onChanged: (_) => onAddressFieldsChanged?.call(),
              decoration: InputDecoration(
                labelText: 'New Address',
                hintText: 'Enter new delivery address',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: isTablet ? 16 : 12),
            TextField(
              controller: newPhoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: isTablet ? 17 : 14),
              onChanged: (_) => onAddressFieldsChanged?.call(),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter contact phone number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],

        SizedBox(height: isTablet ? 26 : 20),

        // 3. Cash on Delivery (COD) Section
        Text('Cash on Delivery (COD)', style: headerTextStyle),
        SizedBox(height: isTablet ? 16 : 12),

        Row(
          children: [
            Expanded(
              child: _SelectCard(
                title: 'Yes',
                icon: Icons.payments_outlined,
                isSelected: isCod == true,
                onTap: () => onCodChanged(true),
              ),
            ),
            SizedBox(width: isTablet ? 16 : 12),
            Expanded(
              child: _SelectCard(
                title: 'No',
                icon: Icons.money_off_outlined,
                isSelected: isCod == false,
                onTap: () => onCodChanged(false),
              ),
            ),
          ],
        ),

        // 4. Type of Invoice Section
        SizedBox(height: isTablet ? 26 : 20),
        Text('Type of Invoice', style: headerTextStyle),
        SizedBox(height: isTablet ? 16 : 12),

        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SelectCard(
                  title: 'Tax Invoice',
                  icon: Icons.receipt_long_outlined,
                  isSelected: isTaxApplicable == true,
                  onTap: () => onTaxApplicableChanged?.call(true),
                ),
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: _SelectCard(
                  title: 'Commercial Invoice',
                  icon: Icons.receipt_outlined,
                  isSelected: isTaxApplicable == false,
                  onTap: () => onTaxApplicableChanged?.call(false),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectCard extends StatelessWidget {
  const _SelectCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final activeBgColor = colorScheme.primaryContainer.withValues(alpha: 0.35);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Material(
      color: isSelected ? activeBgColor : colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 18 : 14,
            vertical: isTablet ? 18 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? primaryColor : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: isTablet ? 29 : 22,
                color: isSelected ? primaryColor : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: isTablet ? 14 : 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  size: isTablet ? 26 : 20,
                  color: primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryOptionTile extends StatelessWidget {
  const _DeliveryOptionTile({
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    final activeBgColor = colorScheme.primaryContainer.withValues(alpha: 0.35);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Material(
      color: isSelected ? activeBgColor : colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 18 : 14,
            vertical: isTablet ? 16 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? primaryColor : colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: isTablet ? 26 : 20,
                color: isSelected ? primaryColor : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: isTablet ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isTablet ? 17 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

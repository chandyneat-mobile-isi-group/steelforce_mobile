part of '../add_depot_bottom_sheet.dart';

extension AddressStepExtension on _AddDepotBottomSheetState {
  // ===========================================================================
  // STEP 2 — Address & Location
  // ===========================================================================
  Widget _buildAddressStep(Map<String, String> errors) {
    final draft = _bloc.state.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _twoCol(
          _text(
            _streetCtrl,
            'add_depot.street_hint'.tr,
            label: 'add_depot.street'.tr,
            icon: Icons.add_road_rounded,
            required: true,
            compact: true,
            error: errors['street'],
            onChanged: (v) => _edit((d) => d.street = v),
          ),
          _text(
            _houseNoCtrl,
            '217',
            label: 'add_depot.house_no'.tr,
            icon: Icons.home_outlined,
            compact: true,
            keyboardType: TextInputType.number,
            error: errors['houseNumber'],
            onChanged: (v) => _edit((d) => d.houseNumber = v),
          ),
          flexLeft: 6,
          flexRight: 5,
        ),
        _gap(8),
        _buildAddressLocationCard(draft, errors),
        _gap(8),
        GeoLocationSelector(
          controller: _geoController,
          twoColumn: true,
          lockPostalCode: true,
          initialAddress: draft.geoAddress,
          initialCodes: ResolveGeoAddressParams(
            provinceCode: draft.cityCode,
            districtCode: draft.districtCode,
            communeCode: draft.communeCode,
            villageCode: draft.villageCode,
            postalCode: draft.postalCode,
          ),
          requirement: GeoAddressRequirement.standard,
          spacing: _spacing(8),
          onChanged: (address) => _edit((d) {
            d.geoAddress = address;
            d.cityCode = address.province?.code;
            d.districtCode = address.district?.code;
            d.communeCode = address.commune?.code;
            d.villageCode = address.village?.code;
            d.postalCode = address.postalCode ?? '';
          }),
        ),
        _gap(8),
        _twoCol(
          _infoChip(Icons.flag_outlined, 'KH - Cambodia'),
          _infoChip(Icons.public, 'R01 - Central Area'),
        ),
      ],
    );
  }

  Widget _buildAddressLocationCard(
      BpDepotDraft draft, Map<String, String> errors) {
    final hasFix = draft.geoFix != null;
    final hasError = errors['geo'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            unawaited(_captureGps());
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasError
                    ? Theme.of(context).colorScheme.error
                    : (hasFix
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE2E8F0)),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child:
                        Icon(Icons.location_on, color: Colors.white, size: 15),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Address Location',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: _fontSize(12),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (hasFix)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFF10B981)),
                              ),
                              child: Text(
                                'Verified',
                                style: TextStyle(
                                  color: const Color(0xFF059669),
                                  fontSize: _fontSize(10),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _capturingGps
                            ? 'add_depot.gps_capturing'.tr
                            : (hasFix
                                ? (draft.geoFix?.display ?? 'GPS Captured')
                                : 'Search or select location'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasFix
                              ? Theme.of(context).colorScheme.onSurface
                              : const Color(0xFF94A3B8),
                          fontSize: _fontSize(12),
                          fontWeight:
                              hasFix ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (_capturingGps)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    hasFix ? Icons.check_circle_rounded : Icons.map_outlined,
                    color: hasFix
                        ? const Color(0xFF10B981)
                        : const Color(0xFF3B82F6),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: _errorText('add_depot.${errors['geo']}'.tr),
          ),
      ],
    );
  }

  Future<void> _captureGps() async {
    if (_capturingGps) return;
    setState(() => _capturingGps = true);

    ({double lat, double lng})? fix;
    try {
      fix = await sl<OrderLocationService>().captureOnce();
    } catch (error) {
      _trace.fail('gps', 'capture failed', {'error': error.runtimeType});
    }
    if (!mounted) return;
    setState(() => _capturingGps = false);

    var capturedFix = fix;
    final originalFix = capturedFix;
    final hasCambodiaFix = originalFix == null
        ? false
        : _isCambodiaCoordinate(originalFix.lat, originalFix.lng);
    if (kDebugMode && !hasCambodiaFix) {
      _trace.warn('gps', 'development fallback — fix absent or outside KH');
      capturedFix = (
        lat: _AddDepotBottomSheetState._developmentCambodiaLatitude,
        lng: _AddDepotBottomSheetState._developmentCambodiaLongitude,
      );
    }
    if (capturedFix == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('add_depot.gps_failed'.tr)),
      );
      return;
    }

    // Full precision — SAP stores 11.531871600000001, not 11.53187.
    final latitude = capturedFix.lat;
    final longitude = capturedFix.lng;
    // A shop's position is depot data: whether a fix was captured is
    // traceable, the coordinates themselves are not (FS-SEC-2).
    _trace.ok('gps', 'fix saved to draft', {
      'inKH': DebugTrace.yesNo(_isCambodiaCoordinate(latitude, longitude)),
    });
    _edit((d) => d.geoFix = GeoFix(
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: null,
          capturedAt: DateTime.now(),
        ));
  }

  bool _isCambodiaCoordinate(double latitude, double longitude) =>
      latitude >= 9.9 &&
      latitude <= 14.7 &&
      longitude >= 102.3 &&
      longitude <= 107.7;
}

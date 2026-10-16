part of '../add_depot_bottom_sheet.dart';

extension IdentityStepExtension on _AddDepotBottomSheetState {
  // ===========================================================================
  // STEP 1 — Identity
  // ===========================================================================
  Widget _buildIdentityStep(Map<String, String> errors) {
    final draft = _bloc.state.draft;
    final refs = _bloc.state.references;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _twoCol(
          _dropdown(
            label: 'add_depot.grouping'.tr,
            icon: Icons.category_outlined,
            required: true,
            compact: true,
            value: draft.grouping,
            options: refs.partnerGroup,
            error: errors['grouping'],
            onChanged: (v) => _edit((d) => d.grouping = v!),
          ),
          _dropdown(
            label: 'add_depot.title_field'.tr,
            icon: Icons.person_outline,
            required: true,
            compact: true,
            value: draft.title,
            options: SapMasterData.title,
            error: errors['title'],
            onChanged: (v) => _edit((d) => d.title = v!),
          ),
          flexLeft: 6,
          flexRight: 5,
        ),
        _gap(8),
        _twoCol(
          _text(
            _nameEnCtrl,
            'add_depot.name_en_hint'.tr,
            label: 'add_depot.name_en'.tr,
            icon: Icons.badge_outlined,
            required: true,
            compact: true,
            error: errors['nameEn'],
            maxLength: 40,
            onChanged: (v) => _edit((d) => d.nameEn = v),
          ),
          _text(
            _nameKhCtrl,
            'add_depot.name_kh_hint'.tr,
            label: 'add_depot.name_kh'.tr,
            icon: Icons.translate_rounded,
            required: true,
            compact: true,
            error: errors['nameKh'],
            maxLength: 40,
            onChanged: (v) => _edit((d) => d.nameKh = v),
          ),
        ),
        _gap(8),
        _moreToggle(
          expanded: _showMoreIdentity,
          onTap: () => setState(() => _showMoreIdentity = !_showMoreIdentity),
        ),
        if (_showMoreIdentity) ...[
          _gap(8),
          // No c/o name input: `CoName` is built from the contact person on
          // step 3 (`BpDepotDraft.contactCoName`).
          _text(
            _name2Ctrl,
            'add_depot.name2_hint'.tr,
            label: 'add_depot.name2'.tr,
            icon: Icons.badge_outlined,
            compact: true,
            onChanged: (v) => _edit((d) => d.name2 = v),
          ),
          _gap(8),
          _twoCol(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _text(
                  _searchTermCtrl,
                  'add_depot.search_term1_hint'.tr,
                  label: 'add_depot.search_term1'.tr,
                  icon: Icons.search_rounded,
                  compact: true,
                  maxLength: 20,
                  onChanged: (v) => _edit((d) => d.searchTerm = v),
                ),
                _hint('add_depot.search_term1_note'.tr),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _text(
                  _searchTerm2Ctrl,
                  'add_depot.search_term2_hint'.tr,
                  label: 'add_depot.search_term2'.tr,
                  icon: Icons.storefront_outlined,
                  compact: true,
                  maxLength: 20,
                  onChanged: (v) => _edit((d) => d.searchTerm2 = v),
                ),
                _hint('add_depot.search_term2_note'.tr),
              ],
            ),
          ),
        ],
        _gap(8),
        _infoChip(Icons.qr_code_2_rounded, 'add_depot.code_assigned_by_sap'.tr),
      ],
    );
  }
}

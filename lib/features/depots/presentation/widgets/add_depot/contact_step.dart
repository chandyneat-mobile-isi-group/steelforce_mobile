part of '../add_depot_bottom_sheet.dart';

extension ContactStepExtension on _AddDepotBottomSheetState {
  // ===========================================================================
  // STEP 3 — Contact
  // ===========================================================================
  Widget _buildContactStep(Map<String, String> errors) {
    final draft = _bloc.state.draft;

    final telephoneSwitchCard = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
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
          _buildIconBox(Icons.phone_outlined, size: 28, iconSize: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _cardLabel(
                  'add_depot.telephone'.tr,
                  required: true,
                  fontSize: 11,
                ),
                Text(
                  'add_depot.same_as_mobile'.tr,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch.adaptive(
              value: draft.telephoneSameAsMobile,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              onChanged: (v) => _edit((d) => d.telephoneSameAsMobile = v),
            ),
          ),
        ],
      ),
    );

    // Name, role and mobile describe one person and are grouped as one, because
    // the rep is answering "who do I call, and on what number?" — not filling
    // three unrelated boxes. Before this, the mobile sat between the person and
    // the shop's landline with nothing saying which it belonged to, and
    // `BpDepotDraft.contacts` pairs it with the person, so the form had better
    // say so too.
    final contactPerson = Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildIconBox(Icons.person_rounded, size: 28, iconSize: 15),
              const SizedBox(width: 8),
              Expanded(
                child: _cardLabel(
                  'add_depot.contact_person'.tr,
                  required: true,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          _gap(8),
          _twoCol(
            _text(
              _contactNameCtrl,
              'add_depot.contact_name_hint'.tr,
              label: 'add_depot.contact_name'.tr,
              icon: Icons.badge_outlined,
              required: true,
              compact: true,
              error: errors['contactPersonName'],
              onChanged: (v) => _edit((d) => d.contactPersonName = v),
            ),
            _dropdown(
              label: 'add_depot.role'.tr,
              icon: Icons.work_outline_rounded,
              required: true,
              compact: true,
              value: draft.contactPersonRole,
              options: SapBpConst.contactRoles,
              hint: 'add_depot.pick_one'.tr,
              error: errors['contactPersonRole'],
              showCode: false,
              onChanged: (v) => _edit((d) => d.contactPersonRole = v),
            ),
          ),
          _gap(8),
          _phone(
            _mobileCtrl,
            'add_depot.phone_hint'.tr,
            label: 'add_depot.mobile_phone'.tr,
            icon: Icons.phone_android_rounded,
            required: true,
            compact: true,
            error: errors['mobilePhone'],
            onChanged: (v) => _edit((d) => d.mobilePhone = v),
          ),
          // Names the person once one is entered, so the pairing is visible
          // rather than implied by layout alone — this is the number that will
          // be filed against them, not the shop's.
          _hint(
            draft.contactPersonName.trim().isEmpty
                ? 'add_depot.mobile_is_personal'.tr
                : 'add_depot.mobile_belongs_to'.trParams({
                    'name': draft.contactPersonName.trim(),
                  }),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        contactPerson,
        _gap(10),
        // The shop's own line, kept out of the person's group: it may simply
        // mirror the mobile via the switch, so attaching it to a named person
        // would give a rep a number that rings the counter.
        _twoCol(
          telephoneSwitchCard,
          _dropdown(
            label: 'add_depot.language'.tr,
            icon: Icons.language_rounded,
            compact: true,
            value: draft.language.isEmpty
                ? SapBpConst.defaultLanguage
                : draft.language,
            options: SapMasterData.language,
            showCode: false,
            onChanged: (v) => _edit((d) => d.language = v!),
          ),
        ),
        if (!draft.telephoneSameAsMobile) ...[
          _gap(8),
          _phone(
            _telCtrl,
            'add_depot.phone_hint'.tr,
            label: 'add_depot.telephone'.tr,
            icon: Icons.call_outlined,
            required: true,
            compact: true,
            error: errors['telephone'],
            onChanged: (v) => _edit((d) => d.telephone = v),
          ),
        ],
      ],
    );
  }
}

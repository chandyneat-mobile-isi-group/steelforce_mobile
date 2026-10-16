# New i18n keys

`assets/lang/` was not in the zip, so these three could not be added. Without
them `.tr` falls through to the raw key and the rep sees
`add_depot.search_term1` on screen.

Add to `assets/lang/en.json` and `assets/lang/km.json` under `add_depot`:

| Key | English | Notes |
|---|---|---|
| `search_term1` | Search Term 1 (Place) | SAP `SORT1` |
| `search_term1_hint` | e.g. PHNOM PENH | |
| `search_term1_note` | The city or province. Used to find this shop by area. | |
| `search_term2` | Search Term 2 (Shop) | SAP `SORT2` |
| `search_term2_hint` | e.g. BAYON STEEL SENSOK | |
| `search_term2_note` | Brand and district, as staff would say it out loud. | |
| `language` | Correspondence Language | |
| `success_pending_approval` | Sent to HQ for approval. The depot code arrives once approved. | Must **not** promise a usable depot |
| `success_with_code` | Depot {code} created. | `trParams({'code': ...})` |
| `price_group` | Price Group | Derived from Depot Group, overridable |

`success_pending_approval` is the important one. The endpoint returns
`sapStatus: PENDING_HQ` with no depot code for a record awaiting approval,
and the rep must not be told the shop is ready to trade — they will try to
order against it in front of the depot and be refused.

Confirm `trParams` is the right call for interpolation in this codebase; it is
what `documents_partially_sent` already uses in
`add_depot_bottom_sheet.dart`.

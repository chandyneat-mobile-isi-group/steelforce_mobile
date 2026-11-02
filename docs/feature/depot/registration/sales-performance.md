# Depot type and the Sales & Performance step

Two additions to the mobile depot registration wizard
(`lib/features/depots/presentation/widgets/add_depot_bottom_sheet.dart`).

## Wizard steps

| # | Step | `BpFormStep` |
|---|---|---|
| 1 | Identity — now opens with **Register as: Depot / Non-BP depot** | `identity` |
| 2 | Address & location | `address` |
| 3 | Contact details | `contact` |
| 4 | Sales terms | `salesTerms` |
| 5 | **Sales & performance** (new) | `salesPerformance` |
| 6 | Documents | `documents` |
| 7 | Review | `review` |

On tablet, step 5 is shown under Contact + Sales terms on the second stage.

## Register as (step 1)

One wizard registers both kinds. The choice is `BpDepotDraft.registrationType`
(`DepotRegistrationType.depot` / `nonBp`), saved in the local draft as
`registrationType: "depot" | "non_bp"`. Drafts saved before this field open as
`depot`.

The old static Non-BP demo (hard-coded list, cards, short register form) is
removed. The **Depots / Non-BP Depots** switch on the depot list stays. The
Non-BP tab says there is nothing to list yet, and its **Register Non-BP depot**
button opens this wizard with Non-BP already picked
(`DepotCreateScreen(registrationType:)`).

## Sales & performance (step 5)

The field survey, section 3. Model: `DepotSalesSurvey`
(`lib/features/depots/data/models/depot_sales_survey.dart`).

| Q | Question | Shown when | Required |
|---|---|---|---|
| 1 | Product lines sold: steel, construction materials (multi) | always | at least one |
| 1.1 | Steel types: tube, zinc roofing sheet, steel bar (multi) | steel picked | at least one |
| 2 | Average monthly sales in USD per line, 2026; total computed | a line picked | each picked line |
| 3 | Share of steel sales value: to depots / to end users; must total 100% — typing one fills the other | steel picked | yes |
| 4 | Average monthly steel purchases in USD: ISI, GI, KBS, Chip Mong, Others | steel picked | no |

Q3 is shown only for steel because it asks about steel sales. Un-picking steel
clears every steel-only answer.

## Not sent to the backend — open item

Neither the depot type nor the survey is in the business-partner request
(`data/mappers/bp_draft_to_business_partner.dart`); the API contract has no
field for them. Both are kept in the locally saved draft (`toDraftJson`) and the
registration outbox snapshot only, and the step says so on screen.

**Consequence:** a registration marked *Non-BP depot* is still submitted to SAP
as an ordinary business partner today. Before this goes to reps, the backend
must define (a) how a Non-BP depot is registered and (b) where the survey
answers are stored. The mapper is the one place to add them.

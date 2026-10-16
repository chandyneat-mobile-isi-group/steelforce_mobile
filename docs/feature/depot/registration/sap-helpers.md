# SAP CustHelper Catalogues — Verified Contract

The API document you provided lists the ten routes and their query parameters but
**not their response shapes**. Every shape below was read off the live middleware
(`Live110`), not inferred.

That mattered more than expected — see the payment-term row.

---

## The ten catalogues

| # | Endpoint | Code field | Name field | Rows | Observed time |
|---|---|---|---|---:|---:|
| 1 | `GetSalesOrg` | `SalesOrg` | `SalesOrgName` | 22 | 0.20 s |
| 2 | `GetDisChannel` | `DisChannel` | `DisChannelName` | 9 | 0.25 s |
| 3 | `GetDivision` | `Division` | `DivisionName` | 5 | fast |
| 4 | `GetSalesGroup` | `SalesGroup` | `SalesGroupName` | 6 | 0.62 s |
| 5 | `GetSalesOffice` | `SalesOffice` | `SalesOfficeName` | 20 | fast |
| 6 | `GetPriceGroup` | `PriceGroup` | `PriceGroupName` | 9 | 3.1 s |
| 7 | `GetShipping` | `Shipping` | `ShippingName` | 2 | 0.76 s |
| 8 | `GetPaymentTerm` | **`PayTerm`** ⚠️ | **`PayTermName`** | 28 | 10.4 s |
| 9 | `GetCustGroup` | `CustGroup` | `CustGroupName` | 8 | 2.8 s |
| 10 | `GetSalesEmployee` | `SalesEmployee` | `SalesEmployeeName` | **5,809** | 0.2 s – timeout |

Sample payloads, verbatim:

```jsonc
{"SalesOrg":"0018","SalesOrgName":"Tbong Khmum"}
{"DisChannel":"10","DisChannelName":"End-User"}
{"Division":"10","DivisionName":"ISI Steel"}
{"SalesGroup":"010","SalesGroupName":"Channel Sales"}
{"SalesOffice":"0001","SalesOfficeName":"Phnom Penh"}
{"PriceGroup":"11","PriceGroupName":"End-User"}
{"Shipping":"01","ShippingName":"ISI Services"}
{"PayTerm":"BL30","PayTermName":"LC after BL date 30days","DayLimit":31}
{"CustGroup":"01","CustGroupName":"End-User"}
{"SalesEmployee":"0000100001","SalesEmployeeName":"LENG KANG"}
```

---

## ⚠️ Two things the naming convention would have got wrong

**`GetPaymentTerm` returns `PayTerm`, not `PaymentTerm`** — and carries a third field,
`DayLimit` (an integer, 31 for BL30), that nothing in the route name suggests. Nine of
the ten follow `{Thing}` / `{Thing}Name`; this one does not.

Had these been guessed, the payment-terms dropdown would have been **silently empty**:
the rows deserialise with a null code, the importer skips them, and only a log line
says so. That is a safe failure but a quiet one, which is why every name here was
verified rather than assumed.

`DayLimit` is read but not yet stored — the platform already models credit terms in
days on the depot, so it is the obvious value to map onto `CreditTermDays` when
that is wired up.

---

## ⚠️ The middleware is intermittently slow

While the material master (32 pages) and stock snapshot (13 pages) syncs were running,
three catalogues **timed out at 280 s and then 400 s**: `GetSalesOrg`, `GetCustGroup`
and `GetSalesEmployee`. The same endpoints answered in under a second once those syncs
finished, and a full ten-catalogue sync then completed in **3.8 s**.

So: treat a timeout here as load, not breakage. Two consequences are built in.

- **One failing catalogue never abandons the other nine.** The sync reports it in
  `failedCatalogues` and carries on. A form with nine good dropdowns beats a form that
  will not open.
- **The import is additive.** A code SAP stops listing is kept, because an existing
  depot may already carry it and a dropdown that silently loses the value a record
  uses turns an edit screen into a validation failure nobody can resolve.

A filtered call is fast even when the unfiltered listing is not — `?organId=0018`
returned in 0.07 s during the degraded window. Worth remembering if the listing ever
becomes permanently unusable.

---

## The dependency you asked about

Your message described a chain — Sales Org → Sales Group → Sales Office — and asked
whether the dropdowns depend on one another.

**They do not, as far as the API shows.** Each `CustHelper` endpoint takes only its
*own* id as a filter (`GetSalesGroup` takes `groupId`, not `organId`), so there is no
parameter by which one catalogue could be narrowed by another's selection. The ten are
independent lists.

The platform therefore returns all nine small ones at once and lets the form decide
its own order. If a real dependency exists in SAP customising, it is not expressed in
this API and would need either a new SAP endpoint or a rule maintained here.

# QA engineering

Test assets for the SteelForce mobile app. **Current scope: Authentication
and Profile** (with Session).

| File | What it is |
|---|---|
| [`SteelForce_Test_Cases.xlsx`](SteelForce_Test_Cases.xlsx) | The workbook QA works in. Sheets: Summary, Test_Cases, Test_Scenarios, Test_Data, Automation_Mapping, Execution_Results, Bug_Log, Triage_Matrix, Dropdowns. |
| [`ISSUE_TRIAGE_GUIDE.md`](ISSUE_TRIAGE_GUIDE.md) | How to find whether a failure comes from Mobile, Backend, Database, SAP, Network, Test Data or Environment. |
| [`TEST_CASE_COVERAGE.md`](TEST_CASE_COVERAGE.md) | What is covered, the real automated run, gaps, and suspected issues to verify. |
| [`AUTOMATION_TEST_ROADMAP.md`](AUTOMATION_TEST_ROADMAP.md) | What to automate next, phase by phase. |

## Recording a run

1. In `Execution_Results`, copy the `UAT-R1` rows and give them a new Run ID.
2. Fill in date, tester, environment, app version, device and OS, then the
   result for each case.
3. For every **Fail**, fill in Issue Source, Issue Type, HTTP Status, API
   Endpoint, Correlation ID, evidence, Root Cause, Assigned Team and
   Confidence. Keep going until **Triage Check** says `OK`.
4. Set `Summary!B3` to your Run ID to see the counts.

**Never** put a password, token, OTP code or unmasked phone number in the
workbook.

---
description: Diagnose and fix a bug — reproduce, root-cause, minimal fix, regression check
argument-hint: '<the bug: what happens vs what should happen>'
---

Bug: **$ARGUMENTS**

Follow `.claude/rules/workflow.md` §7. **Do not modify files until you can name
the root cause.** Changing things until the symptom disappears is not debugging.

## 1. Reproduce

State precisely: what happens, what should happen, on which screen, in which
state (online/offline, authenticated/guest, which locale, which platform). If
you cannot reproduce it, say so and ask for what you need.

## 2. Locate

```bash
graphify query "<the behaviour that is broken>"
graphify path <symptom site> <suspected source>
```

Read the actual code path end to end. Check the logs and the error type.

## 3. Root cause

Write one sentence naming the cause and the file:line where it lives. If you
cannot, keep investigating — do not start editing.

## 4. Minimal fix

Fix the cause, not the symptom. Smallest change that is actually correct. Do not
refactor surrounding code while you are in there.

## 5. Verify and check for regression

```bash
flutter analyze
flutter test test/features/<feature>/     # then the broader suite
```

Add a test that fails without your fix and passes with it. Then ask: what else
uses this code path? Run `graphify affected` on the changed file.

## 6. Report

**Root cause** (what was actually wrong, and why it produced this symptom) ·
**Fix** (what changed and why this is the right layer for it) · Files Changed ·
Verification · Regression risk.

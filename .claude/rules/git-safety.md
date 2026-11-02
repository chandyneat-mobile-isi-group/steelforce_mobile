# Git safety

---

## 1. Before any significant change

```bash
git status
git branch --show-current
git diff
```

Know what is already uncommitted before you add to it. This repo routinely
carries substantial work in progress — **never discard the user's existing
work**, and never assume an uncommitted file is yours to revert.

---

## 2. Branching

Branches: `main` / `develop` / `feature/*` / `release/*` / `hotfix/*`
(`docs/blueprint/migration-plan.md` §11). If you are on a default branch and the
change is non-trivial, branch first.

---

## 3. Commit and push policy

- **Commit only when the user asks.** Do not commit as a matter of course at the
  end of a task.
- **Never push** without an explicit request — `git push` is in the settings
  deny list for this reason.
- Commit messages describe the change and why, not the tool that made it.

---

## 4. Destructive commands

Never run without explicit, specific confirmation from the user:

```
git reset --hard      git clean -fd / -fdx      git checkout -- <path>
git rebase            git push --force          branch or tag deletion
```

`rm -rf`, `sudo`, and `chmod 777` are denied outright in
`.claude/settings.json`. If a task seems to require one, stop and explain why
instead of finding a way around the deny list.

---

## 5. What must not enter a commit

Secrets, `.env*`, keystores, certificates, Firebase private credentials, debug
scaffolding, commented-out code, unrelated formatting churn, `.DS_Store`, build
output, and generated files the project deliberately does not commit
(`lib/core/config/env.g.dart`). Read the diff before you stage it —
`workflow.md` §9.

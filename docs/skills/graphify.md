# Graphify — Codebase Knowledge Graph

> How the ISI Steel Sales Mobile codebase is indexed as a queryable graph, how to
> keep it fresh, and how Claude Code is expected to use it.
>
> Companion to `CLAUDE.md` §graphify (the rules) — this file is the operational detail.

---

## 1. What Graphify is (and what it is not)

Graphify parses every `.dart` file in `lib/` locally and emits a graph of
**symbols and the relationships between them**. It replaces "grep and hope" with
"traverse a structure that already knows the answer".

**It is not** a semantic/vector index. There are no embeddings, no similarity
search, and **no API calls** for the code pass — extraction is deterministic and
runs entirely on-device. Every edge is tagged `EXTRACTED`, `INFERRED`, or
`AMBIGUOUS`, so you always know what was parsed versus guessed. Our current graph
is **100% `EXTRACTED`** (0 inferred, 0 ambiguous) — nothing in it is a model's
opinion.

Relevant to this repo specifically: **Dart is extracted by a dedicated regex
extractor**, not a tree-sitter grammar. There is no `tree-sitter-dart` in the
install. This is a real, documented limitation, and §6 covers what it means in
practice.

---

## 2. Installation

**Requires Python 3.10+.** macOS ships 3.9, so this project uses `uv`, which
vendors its own interpreter and keeps the tool isolated.

```bash
brew install uv                 # macOS; or install uv per its own docs
uv tool install graphifyy       # PyPI package is `graphifyy`; the CLI is `graphify`
graphify install                # registers the /graphify skill for Claude Code
```

> The PyPI name is `graphifyy` (double-y) only because the `graphify` name is
> still being reclaimed upstream. The binary and skill are both `graphify`.

Verify:

```bash
graphify --version              # 0.9.37 at time of writing
```

Windows developers: `pipx install graphifyy` handles PATH automatically, or add
`%APPDATA%\Python\Python3xx\Scripts` to PATH.

---

## 3. Configuration in this repo

| File | Committed? | Purpose |
|---|---|---|
| `.graphifyignore` | ✅ yes | What Graphify must never ingest (see below) |
| `.claude/settings.json` | ✅ yes | Permission allow-list for `graphify` commands — **cross-platform, no absolute paths** |
| `.claude/settings.local.json` | ❌ gitignored | The `PreToolUse` hooks, which embed a machine-specific absolute path |
| `graphify-out/` | ❌ gitignored | Generated artifacts; rebuildable in ~6s |
| `CLAUDE.md` (root) | ✅ yes | The rules that tell Claude to query the graph first |

### `.graphifyignore`

Graphify already honours `.gitignore`. `.graphifyignore` adds what `.gitignore`
does *not* cover, in three groups:

1. **Secrets** — `.env`, `env.g.dart`, keystores, `google-services.json`. These
   are gitignored too, but `.graphifyignore` is the rule that still applies if
   anyone runs `graphify extract --no-gitignore`. Belt and braces, per
   `docs/skills/security.md` §3.
2. **Generated code** — `*.g.dart`, `*.freezed.dart`, `*.drift.dart`. These
   mirror hand-written sources and would roughly double the node count while
   teaching you nothing about design intent.
3. **Non-architecture** — `android/`, `ios/`, `web/`, `build/`, `assets/`,
   binaries. Platform scaffolding is not application architecture.

Audited after the first build: **0 nodes** originate from `ios/`, `android/`,
`build/`, `web/`, `assets/`, or any secret-bearing file.

### Why the hooks are not committed

The `PreToolUse` hook command must be an **absolute path** to the executable —
upstream does this deliberately so the hook still fires when `PATH` is not
inherited. That path is different on every machine:

```
macOS    /Users/<you>/.local/bin/graphify
Windows  C:/Users/<you>/AppData/Roaming/uv/tools/graphifyy/Scripts/graphify.exe
```

This repo previously committed the **Windows** path, which meant the hooks fired
and failed on every `Bash`/`Grep`/`Read`/`Glob` call on macOS. Hooks now live in
the gitignored `.claude/settings.local.json`; each developer generates their own:

```bash
graphify claude install     # writes the hooks with the correct local path
```

---

## 4. Generating and updating the graph

```bash
graphify update .           # rebuild from code — no LLM, no network, ~6s
graphify export wiki        # regenerate the 449-article agent-crawlable wiki
```

`graphify update` is incremental: a SHA256 cache in `graphify-out/cache/` means
re-runs only reprocess changed files.

**Keep it in sync.** Pick one:

- **Manual** — run `graphify update .` after any structural change. This is what
  `CLAUDE.md` instructs Claude to do.
- **Git hook (recommended for teams)** — `graphify hook install` adds a
  post-commit hook that rebuilds automatically. Safe alongside existing hooks.
- **Watch mode** — `graphify watch .` rebuilds live as files are saved. Useful
  during heavy refactors.

**Staleness check.** `GRAPH_REPORT.md` records the commit it was built from:

```bash
git rev-parse HEAD                                  # compare against
grep 'Built from commit' graphify-out/GRAPH_REPORT.md
```

> After a refactor that **deletes** a lot of code, use `graphify update . --force`.
> Without it, Graphify refuses to overwrite a graph with one that has fewer nodes.

---

## 5. Viewing the graph

| Output | What it is |
|---|---|
| `graphify-out/graph.html` | Interactive force-directed map. Open in a browser. Our graph exceeds the 5000-node inline limit, so this renders an **aggregated community view** (439 community nodes, 2914 cross-community edges). |
| `graphify-out/GRAPH_REPORT.md` | Human-readable brief: god nodes, community hubs, suggested questions. Read this first. |
| `graphify-out/wiki/index.md` | 449 Wikipedia-style articles, one per community/god node. Best entry point for an agent that prefers reading files to parsing JSON. |
| `graphify-out/graph.json` | The raw graph every query traverses. |

```bash
open graphify-out/graph.html          # macOS
graphify tree                         # collapsible D3 tree -> GRAPH_TREE.html
graphify export callflow-html         # Mermaid call-flow diagram
```

---

## 6. How the architecture actually maps onto the graph

The Clean Architecture layering in `docs/blueprint/system-architecture.md` §2 shows up as these
edge relations (counts from the current build):

| Relation | Count | Where you see it |
|---|---:|---|
| `defines` | 7556 | file → the classes/functions in it |
| `imports` | 4083 | file → `package:` URI |
| `references` | 2625 | **the cross-file workhorse** — repository → data source, bloc → usecase |
| `inherits` | 1011 | `extends StatelessWidget`, `extends Bloc<E,S>` |
| `contains` | 745 | structural nesting |
| `calls` | 216 | resolved call edges |
| `implements` | 110 | `DepotRepositoryImpl → DepotRepository` |
| `mixes_in` | 40 | Dart mixins |
| `navigates` | 22 | screen → route transitions |

Layer coverage is genuinely there: 115 `*Bloc`, 91 `*Cubit`, 127 `*UseCase`,
271 `*Repository*`, 62 `*DataSource*`, 64 `*Dao*`, 128 `*Screen*`, 103 `*Model*`.

### ⚠️ The one gotcha: `package:` imports are dead ends

Dart self-imports resolve to a **`package:` URI node, not the file node**. All
677 such nodes have **zero outgoing edges**. So this fails:

```bash
graphify path "depot_repository_impl.dart" "depot_local_data_source.dart"
# No directed path found
```

Cross-file traversal works through **`references`**, which *does* resolve to the
real symbol. Query **class-to-class**, or file-to-class — not file-to-file:

```bash
graphify path "depot_repository_impl.dart" "DepotLocalDataSource"
#   depot_repository_impl.dart --references [EXTRACTED]--> DepotLocalDataSource

graphify path "DepotRepositoryImpl" "DepotRepository"
#   DepotRepositoryImpl --implements [EXTRACTED]--> DepotRepository
```

**Rule of thumb: name the class, not the file.**

Related: a repository *impl* class node carries only its `implements` edge — the
dependency on its data source hangs off the enclosing **file** node. If a
class-level query comes back thin, retry from the file node.

---

## 7. How Claude Code should use the graph

The rules live in the root `CLAUDE.md`; the reasoning is here.

**Query before grepping.** The `PreToolUse` hooks intercept `Bash`/`Grep`/`Read`/
`Glob` and inject a reminder to run `graphify query` first. A graph traversal
returns a scoped subgraph — dramatically cheaper than grep output or reading
`GRAPH_REPORT.md` wholesale.

```bash
graphify query "how does a visit check-in reach the sync queue?"
graphify explain "AppDatabase"
graphify path "CartCubit" "SalesOrderDao"
graphify affected "AppDatabase" --depth 1      # blast radius before refactoring
graphify god-nodes --top 10                     # architectural hubs
```

**`affected` is the highest-value command for this codebase.** Before touching
shared infrastructure, get the real blast radius:

```
$ graphify affected "AppDatabase" --depth 1
- AppMetadataDao, CartDao, CatalogDao, DepotDao, QuotationDao,
  SalesOrderDao, app_bootstrap_service.dart, app_database_rekey_executor.dart …
```

That is precisely the ADR-004 DAO surface — exactly what you must re-check when
the encrypted-database work in `docs/blueprint/migration-plan.md` T1.3 lands.

**Grep is still correct** for modifying or debugging specific lines, and for
string literals the AST pass does not model. The graph orients you; grep edits.

**Feed results back.** `graphify save-result` records whether an answer helped,
and `graphify reflect` aggregates those into a lessons doc — the graph improves
with use.

---

## 8. Current known limitations

1. **Communities are unlabelled.** Names default to the largest member
   (`my_visits_injection.dart`, `StatelessWidget`). Meaningful names require an
   LLM pass — `graphify label .` with a configured backend. This **costs tokens
   and makes network calls**, so it is deliberately not part of the default
   `graphify update .` flow. Run it only when you want it.
2. **Docs are indexed structurally, not semantically.** 798 `.md` nodes exist,
   but `graphify update` is the code-only pass. Semantic doc/PDF extraction needs
   `graphify extract` with an LLM backend.
3. **Regex, not tree-sitter, for Dart.** Extraction is good on classes, mixins,
   imports, annotations, and `part of` redirection, but it is not a full parser.
   Treat a missing edge as "not extracted", not "does not exist".
4. **Three files produced zero nodes** (`settings.json` ×2, `cspell.json`) — a
   known upstream issue (#1666). Harmless.

---

## 9. Quick reference

```bash
graphify update .                    # rebuild (no LLM, ~6s)
graphify update . --force            # after deleting lots of code
graphify export wiki                 # rebuild the wiki
graphify query "<question>"          # BFS traversal
graphify path "A" "B"                # shortest path (use CLASS names)
graphify explain "X"                 # node + neighbours
graphify affected "X" --depth 1      # reverse blast radius
graphify god-nodes --top 10          # architectural hubs
graphify hook install                # auto-rebuild on commit
graphify benchmark                   # token reduction vs reading raw files
```

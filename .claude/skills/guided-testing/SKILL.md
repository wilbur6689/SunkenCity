---
name: guided-testing
description: Conduct a guided one-test-at-a-time functional testing session on a software project. Use when the user wants to manually functional-test a project feature by feature, recording results into a living test report. Reviews the project, derives features from the navigation/pages, and walks through tests one at a time with expected results, possible errors, and example inputs. Maintains a single Markdown report (FUNCTIONAL_TEST_REPORT.md) that tracks coverage across sessions.
argument-hint: [project-path-or-feature]
allowed-tools: Read, Edit, Write, Glob, Grep
user-invocable: true
effort: high
---

# Guided Functional Testing Session

You are running a **guided, manual functional-testing session** for a software project. You act as a QA lead: you review the project, break it into features, and hand the user **one test at a time** to execute by hand. You record every result into a **living report** so testing can stop and resume at any point.

This skill produces and maintains a single file in the project root: **`FUNCTIONAL_TEST_REPORT.md`**.

---

## Core Principles

### 1. One Test at a Time
- **NEVER** present more than one test in a single message.
- Present one test, wait for the user to run it and report back, then move to the next.
- Tests within a feature should **build on each other** (e.g. "create a record" before "edit that record" before "delete it"). Order them so each test sets up state the next test can use.
- Label every test with a stable ID: **`[FEATURE]-[NN]`** (e.g. `AUTH-01`, `AUTH-02`, `BILLING-01`).

### 2. Features Come From the Project's Navigation
- Derive the list of **features** primarily from the project's **navigation bar / page routes** (each top-level page or nav item = one feature group).
- Use static code analysis to find them — look for routers, route definitions, nav/menu components, page directories. Common signals: `routes`, `Router`, `<Route`, `<NavLink`, `<nav`, `pages/`, `app/`, `views/`, `screens/`, menu config files.
- Supplement nav-derived features with obvious non-page features when they're clearly present (auth, search, notifications, settings) but keep the nav as the backbone.
- Present the derived feature list to the user **once** at the start and let them add, remove, or reorder before testing begins.

### 3. Anatomy of Each Test
Every test you present must include these labeled parts, kept tight:

```
### Test [FEATURE]-NN: [Short title]
**Goal:** One sentence on what this verifies.
**Setup / depends on:** [Prior test ID or state needed, or "none"]
**Steps:** Numbered, concrete actions to perform.
**Example inputs:** Concrete sample data to use (real-looking values, not placeholders).
**Expected result:** What should happen if it works.
**Possible errors:** 2-4 specific things that commonly go wrong here and what they'd look like.
```

Then present the **result options** (see next).

### 4. Result Options (the user picks one)
After each test, offer exactly these four outcomes:

```
1. ✅ Expectation — Worked as expected, nothing else worth mentioning.
2. ➖ Deviation — It worked, but didn't follow what was expected. (Tell me what differed.)
3. ❌ Error — It didn't work / produced an error. (Paste the error or describe it.)
4. 💡 Enhancement — It worked, but I have notes / improvement ideas. (Add your notes.)
```

- Accept short responses: "1", "pass", "option 3 + here's the error", etc.
- For Deviation, Error, and Enhancement, capture the user's free-text detail. If they pick one of those without detail, ask **one** brief follow-up for specifics, then record and move on.
- If the user pastes an error, capture it verbatim in the report.

### 5. Response Length
- Keep messages short. The test block itself plus the four options — no extra preamble.
- Lead with at most one sentence acknowledging the previous result.
- Do not over-explain. Save detail for the report.

### 6. Recording — Update the Report as You Go
- **Append each result to the report immediately** after the user responds (this differs from a pure review skill — here the report is the whole point, and the session must be resumable at any time).
- After recording, present the next test.
- If the user says "stop", "done", "that's enough", or similar, finalize the report summary and end gracefully.

---

## The Report: `FUNCTIONAL_TEST_REPORT.md`

A single Markdown file in the project root. It is the **living document** — created on the first run, updated on every subsequent run.

### First Run — Generate the Report
If `FUNCTIONAL_TEST_REPORT.md` does **not** exist:
1. Review the project and derive the feature list from navigation/routes.
2. Confirm the feature list with the user.
3. Create the report with this structure:

```markdown
# Functional Test Report — [Project Name]

_Living document. Created [date]. Last updated [date]._

## Summary
- **Features identified:** N
- **Tests run:** 0
- **Coverage:** 0% of features touched, 0% of planned tests run
- **Results:** ✅ 0 · ➖ 0 · ❌ 0 · 💡 0

## Coverage by Feature
| Feature | Planned | Run | ✅ | ➖ | ❌ | 💡 | Status |
|---------|--------:|----:|---:|---:|---:|---:|--------|
| Auth    | 4       | 0   | 0  | 0  | 0  | 0  | Not started |
...

## Test Log
<!-- Each result appended here in order -->

## Open Issues
<!-- Auto-built from Deviation / Error / Enhancement results -->
```

4. Begin the session at the first feature, first test.

### Test Log Entry Format
Append one block per executed test:

```markdown
### [FEATURE]-NN — [Short title]
- **Run:** [timestamp]
- **Result:** ❌ Error
- **Details:** [user's verbatim notes / pasted error, or "—"]
- **Setup:** [depends-on test, if any]
```

### Re-Run — Resume & Coverage
If `FUNCTIONAL_TEST_REPORT.md` **already exists**:
1. Read it. Parse which tests have been run and their results.
2. Recompute the **Summary** and **Coverage by Feature** table, and report current coverage % to the user.
3. Offer where to continue:
   - **Continue** — next untested test in the next incomplete feature.
   - **Regression** — re-run previously failed tests (see below).
   - **Specific feature** — jump to a feature the user names.
4. Never silently re-run an already-passed test. Skip completed tests unless the user asks to redo them.
5. Update `Last updated` and re-write the Summary/Coverage tables every time the report changes.

### Coverage Definition
- **Feature coverage:** % of identified features with at least one test run.
- **Test coverage:** % of planned tests (across all features) that have a logged result.
- Show both numbers in the Summary.

---

## Regression Re-Test Mode
- When entering regression mode, gather all tests whose latest result was **Error** or **Deviation**.
- Re-present each (one at a time) noting **"Regression re-test — previously: ❌ Error on [date]"**.
- On a new result, **append a new dated entry** (don't erase history) and update the test's current status.
- Track and report **fixed vs still-broken**: a test that was ❌/➖ and is now ✅ counts as fixed.
- After a regression pass, summarize: "Re-tested N, fixed X, still failing Y."

---

## Open Issues & Dev Export
- Every **Deviation**, **Error**, and **Enhancement** result automatically becomes an entry in the report's **Open Issues** section.
- Issue entry format:

```markdown
- [ ] **[FEATURE]-NN** ❌ Error — [one-line summary]
      _Details:_ [verbatim notes] · _Found:_ [date]
```

- When the user asks to **export issues for devs** (or at session end if they want), generate a separate file **`FUNCTIONAL_TEST_ISSUES.md`** in the project root, formatted as a clean, dev-ready bug list grouped by feature, each item written as a GitHub-issue-style entry:

```markdown
## [Feature]
### [FEATURE]-NN: [Title]
**Type:** Error | Deviation | Enhancement
**Steps to reproduce:** ...
**Example input:** ...
**Expected:** ...
**Actual:** [user's notes]
**Found:** [date]
```

- Mark issues resolved (`[x]`) when a later regression run flips them to ✅.

---

## Session Flow

### Starting
1. Determine the project (use `$ARGUMENTS` or the current folder; ask if ambiguous).
2. Check for `FUNCTIONAL_TEST_REPORT.md`.
   - **Missing** → review project, derive features from nav/routes, confirm list, create report.
   - **Exists** → parse it, report coverage, offer Continue / Regression / Specific feature.
3. Announce the first feature and present the first test.

### During
1. Present one test (full anatomy + 4 result options).
2. Wait for the user's result.
3. If Deviation/Error/Enhancement and no detail given, ask one brief follow-up.
4. Record the result into the report (Test Log + Open Issues + recompute Summary/Coverage).
5. Acknowledge in one sentence, present the next test (labeled with its ID).
6. Repeat. When a feature's planned tests are done, mark it complete and move to the next.

### Ending (any time)
1. On "stop"/"done", finalize: update `Last updated`, Summary, Coverage table.
2. Give a brief recap: tests run this session, results breakdown, current overall coverage %.
3. Offer to export issues to `FUNCTIONAL_TEST_ISSUES.md`.
4. Tell the user how to resume (re-run the skill; it picks up where they left off).

---

## Handling Special Cases

### User Reports an Error Mid-Test
- Capture the error text verbatim. Do not try to fix the code — this is a manual testing session, not a debugging session (unless the user explicitly asks for help).
- Record it, add to Open Issues, continue to the next test.

### A Test Can't Run Because a Prior Test Failed
- If a test depends on state from a failed test, note it as **Blocked** rather than Error, record "blocked by [ID]", and offer to skip ahead or pick a different feature.

### User Wants to Skip a Test or Feature
- Respect it immediately. Mark as **Skipped** in the log (don't count it as passed). Move on.

### User Adds a Feature Not in the Nav
- Add it to the feature list and coverage table, generate tests for it, continue.

### User Asks for Coverage / Progress
- Read the report, present the Summary and Coverage-by-Feature table, resume where you left off.

### User Asks Your Recommendation on What to Test Next
- Recommend the highest-value untested feature (auth, core CRUD, payment paths first), with one line of reasoning. Still let them choose.

---

## What NOT to Do
- Do not present more than one test per message.
- Do not write walls of text — the test block and four options are enough.
- Do not forget to update the report after each result — resumability depends on it.
- Do not re-run already-passed tests unless asked.
- Do not count Skipped or Blocked tests as passed.
- Do not start debugging or editing project code unless the user explicitly asks.
- Do not invent features that aren't supported by the project's nav/routes/code.
- Do not overwrite test history on regression — append dated entries.

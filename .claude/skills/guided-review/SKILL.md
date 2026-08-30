---
name: guided-review
description: Conduct a guided one-question-at-a-time review session on documents or code files. Use when the user wants to collaboratively review, refine, or fill in details on design documents, configuration files, or code. Walks through each section asking focused questions with multiple-choice options.
argument-hint: [file-path-or-topic]
allowed-tools: Read, Edit, Write, Glob, Grep
user-invocable: true
effort: high
---

# Guided Review Session

You are conducting a **guided collaborative review** of a document or file. Your role is to walk the user through each section **one topic at a time**, asking focused questions and incorporating their answers into the document.

## Question Numbering (Countdown)

**Every question is prefixed with a countdown number so the user always knows how many are left.**

- **At session start, count the open questions/topics** in the target document — call it **N**. State
  the count up front (e.g. "I found **13** open topics — we'll count down from Q13 to Q1.").
- **Number DESCENDING:** the first question is **`Q{N}`**, the next `Q{N-1}`, and so on down to **`Q1`**,
  which is the final question. A lower number = closer to done.
- **Prefix every question** with its number in bold, e.g. `**Q13 —**`. Do **not** append a running
  "N to go" / "N remaining" tag to individual questions — the Q-number alone is enough. (A remaining
  count is only given when the user explicitly asks for a progress update.)
- **Sub-questions use `XX.01` notation.** When a clarifying follow-up or a newly-surfaced sub-topic
  branches off the current question `QXX`, number it **`QXX.01`**, then `QXX.02`, etc. Sub-questions
  **do not decrement the main countdown** — the count keeps flowing `Q13 → Q12 → Q11…` while sub-
  questions branch off (so `Q12.01` and `Q12.02` both sit "inside" Q12).
- **If scope grows** (the review uncovers whole new top-level topics), say so and **re-baseline N**
  (e.g. "that opened 2 new topics — bumping the count to Q9, Q8… from here"). Keep the countdown honest.
- On a progress check, report as **`X of N answered, {remaining} to go`** and list the next few numbers.

## Core Principles

### 1. One Question at a Time
- **NEVER** ask multiple questions in a single message
- Present **one aspect** per message, wait for the user's response, then move to the next
- Label each question clearly with **"Next aspect: [topic]"** after the first question

### 2. Response Length
- Keep your messages **short and concise** — typically 2-6 lines of context followed by the question
- Lead with 1-2 sentences of context or acknowledgment of the user's last answer
- Do not over-explain or provide lengthy justifications
- Save detailed writing for the document update at the end

### 3. Multiple Choice Options
- Provide **2-4 clear options** for the user to choose from on each question
- Format options as a **numbered list** with a **bold label** and brief description, so the user can reply with just the number
- Options should cover the reasonable design space without overwhelming
- Always allow for "something else" by keeping options open-ended

#### The recommendation goes FIRST, numbered, and set apart

When you have a recommendation — and you usually should — it is **option 1**, and it is
**visually separated from the alternatives by a horizontal rule**. Both halves of that matter:

- **Numbered**, so the user can still answer with a single digit. Never put the recommendation
  outside the list as prose — that forces them to type a sentence instead of a number.
- **Set apart**, so it does not read as merely the first of several equals. The user should be able
  to see at a glance which one you are actually advising.
- **Give the recommendation more room than the alternatives.** Two or three sentences of *why* —
  the reasoning is the value, and it is what lets the user disagree on substance rather than
  vibes. The alternatives get one line each.
- Do **not** append "(Recommended)" to the label; the position and the rule already say it.

Example format:

```
**1. [Recommended] — Short label for the call**
One to three sentences on why this is the right answer: the trade-off it wins, the failure it
avoids, or the existing decision it stays consistent with.

---

2. **Option B** — one line on what this means and what it costs.
3. **Option C** — one line on what this means and what it costs.
4. **Option D** — one line on what this means and what it costs.
```

When you genuinely have no recommendation, say so in one line above the list and number the
options normally with no rule.

### 4. Follow-Up Questions
- If the user's response is ambiguous or introduces a new concept, ask **one clarifying follow-up** before moving on
- If the user gives a detailed response that covers multiple points, acknowledge all points and move to the next aspect
- Do not re-ask questions the user has already answered

### 5. Accepting User Input
- Accept **short responses** — the user should not need to write paragraphs
- "yes", "option A", "the first one", "all of the above" are all valid responses
- If the user says "defer" or "later" or "skip", respect that and move on immediately
- If the user provides a detailed custom answer beyond the options, incorporate it fully

### 6. Deferring Topics
- If the user wants to defer a topic, immediately note it and move on
- If a **deferred design document** exists (like `13_deferred_design.md`), offer to add the item there
- Use this template for deferred items:
  ```
  ### [Short Title]
  - **Source:** [Document being reviewed]
  - **Problem:** [What needs to be figured out]
  - **Context:** [Relevant decisions already made]
  - **Needs:** [What the solution must deliver]
  ```

### 7. Progress Tracking
- When asked, provide a **brief progress summary** listing what has been decided so far and what sections remain
- Before updating the document, present a **full summary** of all decisions for the user to confirm

### 8. Document Updates
- Do **NOT** update the document after every question — accumulate decisions
- When the section is complete (user confirms or all topics covered), present a summary and ask: **"Should I update the document?"**
- When updating, rewrite the relevant sections with all decisions incorporated
- Preserve any existing content that was not discussed
- Keep the document's overall structure and formatting consistent

## Session Flow

### Starting the Session
1. **Read the target file** specified in `$ARGUMENTS` (or ask the user which file to review)
2. Identify all sections and open questions in the document, then **count them → N** and tell the user
   the total ("**N** open topics; counting down Q{N} → Q1")
3. Start with the **first section or most fundamental decision** that other decisions depend on —
   assign it **`Q{N}`** (highest number first)
4. Ask the first question, prefixed with its countdown number

### During the Session
1. Ask one focused question with 2-4 options, **prefixed with its countdown number** (`Q{n} —`)
2. Wait for user response
3. Acknowledge briefly (1 sentence max)
4. Ask the next question, labeled "**Q{n−1} — Next aspect: [topic]**" (decrement the countdown; use
   `Q{n}.01` for a sub-question that branches off the current one)
5. Repeat until the section is complete

### Ending the Session
1. Present a complete summary of all decisions made
2. Ask "Should I update the document?"
3. If yes, update the document incorporating all decisions
4. Inform the user what sections remain (if any)
5. Ask if they want to continue to the next section or stop

## Handling Special Cases

### User Wants to Change a Previous Answer
- Accept the change without resistance
- Note how it affects subsequent decisions if relevant
- Continue from where you left off

### User Provides Information Beyond the Question
- Incorporate all provided information
- Skip any questions that are now answered
- Acknowledge what was covered and move to the next unanswered topic

### User Asks for Your Recommendation
- Provide a clear recommendation with brief reasoning
- Still present it as an option the user can accept, modify, or reject

### User Wants a Progress Update
- Lead with the countdown status: **`X of N answered, {remaining} to go`**
- List decided items as a brief table or bullet list (with their Q-numbers)
- List remaining open topics with their upcoming countdown numbers
- Resume where you left off

### Cross-Document Updates
- If a decision affects other documents in the project, note it
- Offer to update related documents after the current one is complete
- Track cross-document dependencies

## What NOT to Do
- Do not ask more than one question per message
- Do not write walls of text — keep responses under 10 lines when possible
- Do not update the document mid-session without being asked
- Do not skip the summary before updating
- Do not provide more than 4 options (it becomes overwhelming)
- Do not repeat information the user has already confirmed
- Do not add features, opinions, or content the user did not request

---
name: communicate
description: Write journal entries, respond to issues, and record learnings with a human-readable voice
tools: [bash, write_file, read_file]
---

# Communication

## Journal Entries

Write at the top of .arc/journal.md after each session. Use the exact UTC
date/time shown in the session prompt or from `date -u +%Y-%m-%d` and
`date -u +%H:%M`. Do not infer dates from issue numbers, issue comments,
roadmap week labels, or previous journal entries.

Format:

```markdown
## YYYY-MM-DD HH:MM — [short title of what you did]

[3-5 sentences — see voice rules below]
```

### Who You Are Writing For

Write for a curious teammate reading the public record later: Yuanhao, another
agent, a contributor, or a technical reader who wants to understand what changed
and why it mattered. They should not need the terminal output, issue history, or
source diff open beside them.

This is not a changelog, not a status dump, and not a performance report. It is
the operating journal of a small agent team growing a project in public.

### Voice Rules

1. **Lead with the thought, tension, or decision, not a file path.** Open with
   the problem you were trying to understand, the tradeoff you had to make, or
   the thing that surprised you. Do not open with "Updated X" or "Implemented Y"
   unless the human meaning is already clear.

2. **Translate jargon the first time it appears.** If you mention a file,
   function, workflow, label, or API, add a short plain-language gloss the first
   time. Example: "`build.yml`, the workflow that sends ready issues to build
   agents." File names are seasoning, not the meal.

3. **Be specific in human terms.** "The blocker was not the external service;
   it was that our own setup flow still asked the wrong person for a secret"
   beats "Fixed configuration issue."

4. **Be honest about friction.** If you failed, got blocked, retried, or changed
   direction, say so directly. Do not make a failed session sound successful.

5. **Keep it brief.** Three to five sentences is the default. Longer entries are
   allowed only for research scans or major decisions where compression would
   hide the signal.

6. **End with implication, not a generic TODO.** Prefer "That leaves the next
   run waiting on one human-owned credential" over "Next: continue setup." The
   last sentence should tell the reader what this means.

7. **No corporate filler.** Avoid "utilized", "leveraged", "noted",
   "acknowledged", "enhanced", "various improvements", and "overall progress."
   Use plain words.

Rules:
- The heading date must be today's UTC date for this session.
- Never write future dates or old placeholder years like 2025 unless the
  session prompt explicitly says that is today's date.
- Do not manually commit or push the journal unless your agent prompt explicitly
  tells you to; the runner post-hook usually commits journal changes.
- Be honest. If you failed, say so.
- Do not list every file changed. Name only the file or workflow that explains
  the session.
- Do not write issue comments into the journal unless the comment changed the
  outcome.

Good:

```markdown
## 2026-05-21 03:14 — The blocker was in our handoff

The work looked blocked on the platform, but the real problem was our own
handoff: the agent was waiting for a value that only a human operator could set.
I turned that into an explicit human-action issue instead of letting the build
loop retry the same impossible task. That matters because the next agent can now
see the boundary clearly instead of mistaking it for a coding problem.
```

Bad:

```markdown
## 2026-05-21 03:14 — Config cleanup

Updated config files and added docs and tests. Next: continue setup.
```

## Issue Responses

Use `gh` CLI directly:

- **Comment:** `gh issue comment NUMBER --repo OWNER/REPO --body "YOUR_MESSAGE"`
- **Close:** `gh issue close NUMBER --repo OWNER/REPO`

Decide for each issue:
- Fixed → comment what you did, close
- Partial → comment with update, keep open
- Won't fix → explain why, close
- No progress → skip (silence > noise)

Keep responses to 3 sentences max. Be direct and honest.

## Learnings

After journal and issue responses, reflect: what did this session teach you?

**Admission gate:**
1. Is this genuinely novel?
2. Would this change how you work in a future session?
If both aren't yes, skip it.

Format in .arc/learnings.md:
```markdown
## [Short insight]
**Context:** [what happened]
**Takeaway:** [reusable insight]
```

Don't force it — not every session produces a lesson.

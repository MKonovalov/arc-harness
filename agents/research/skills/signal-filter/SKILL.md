---
name: signal-filter
description: Intelligence standards — three-layer knowledge, eureka test, so-what filter
tools: [bash]
---

# Signal Filter: Intelligence Standards

Most weeks, the right number of issues to file may be 0. A scan that finds
nothing actionable is not a failed scan, but a scan that leaves no reusable
learning is wasted. Your job is to improve the team's map of the world even
when you do not create work.

## Three Layers of Knowledge

Three layers:

**Layer 1: Tried and true.** Established approaches that work. The cost of checking
is near-zero. If this project already does something well, note it and move on.

**Layer 2: New and popular.** Trending approaches. Be skeptical — humans are subject
to mania. Mr. Market is either too fearful or too greedy. A technique being popular
is not evidence it's right for THIS project.

**Layer 3: First principles.** Original observations derived from reasoning about
THIS project's specific context. Prize these above everything else.

The eureka moment:
> The most valuable outcome of research is not finding a solution to copy. It is:
> 1. Understanding what everyone is doing and WHY (Layers 1 + 2)
> 2. Applying first-principles reasoning to their assumptions (Layer 3)
> 3. Discovering a clear reason why the conventional approach is wrong
>
> This is the 11 out of 10. Most weeks you won't find one. That's fine.

## The "So What?" Test

Before reporting ANY finding:

1. **Does this change our strategy?** If we continue as planned and ignore this,
   what bad thing happens? If nothing — it's trivia, not intelligence.

2. **Is this actionable THIS SPRINT?** Can the build agent implement something
   specific based on this? If not, it's interesting but not useful.

3. **Is this new information?** Would the team already know this? If yes, skip it.

If a finding doesn't pass all three, it's noise. Don't report it.

## Advantage Brief

Every scan should leave a compact advantage brief:

- **Market movement:** what changed in user behavior, product direction,
  technical practice, distribution, or ecosystem assumptions.
- **Evidence:** the concrete source, release, failure, launch, discussion, or
  repeated pattern that makes the movement real.
- **Project relevance:** why this matters for THIS project now.
- **Recommended move:** the smallest simple-but-effective change, if any.
- **Decision:** adopt now, watch, or ignore.
- **Trigger:** the evidence that would make a watched item actionable.

This lets future PM and Research sessions compound instead of rediscovering the
same landscape from scratch.

## What Counts as Signal

- A competitor shipped something that makes our approach obsolete
- A competitor, adjacent tool, or community behavior reveals a new workflow we
  should support or deliberately reject
- A technique that would replace 500 lines of our code with 5
- A well-known project failed at something we're about to try (and why)
- Evidence of user demand for something we haven't prioritized
- A protocol, platform, model, or distribution shift that changes the best next
  move
- A fundamental assumption in our architecture that's been proven wrong elsewhere
- A self-growth gap: the agent loop is worse than adjacent tools at planning,
  building, reviewing, remembering, researching, or recovering from failure
- A knowledge-compounding gap: new information is not entering, being
  synthesized, staying healthy, or becoming reusable
- A simple move that would compound product advantage faster than copying a
  larger feature set

## What Counts as Noise

- "X project exists" (so what?)
- "Y technique is interesting" (actionable how?)
- Feature lists of similar products (we're not building their product)
- Long competitor comparisons that do not change a decision
- "They have X, we do not" unless X reveals demand, a useful pattern, or a
  concrete gap in this project
- Stars, funding, launches, or hype without a behavior change or strategic
  implication
- Blog posts about best practices we already follow
- Tangentially related projects (not competitive)
- "Could be useful someday" without a named watch signal and trigger

## Filing Issues from Research

Only file when ALL are true:
- You found something that requires a CONCRETE change to this project
- You can describe the change in specific terms (not "investigate X")
- The change is motivated by evidence (cite the source)
- The office-hour agent would pass it (apply the taste framework yourself first)
- The issue represents an advantage move, not a copied competitor feature

For autonomous growth projects, research-backed self-growth gaps are high
priority. They do not need to wait for reactive feedback when the affected
workflow is specific, current, and important to the agent loop.

When filing, be honest about confidence:
- "High confidence: competitor X proved approach Y fails because Z"
- "Medium confidence: technique X might simplify our code, worth investigating"
- Never file "low confidence" issues. If you're not sure, wait a week.

## Journal Entry Quality

Show, don't tell. Use the advantage brief:

- GOOD: "Changed: adjacent coding agents now preserve task memory across runs;
  our build loop still rediscovers failure context from comments. Filing one
  issue to pass the last failure summary into rescue mode."
- GOOD: "Unchanged: three new knowledge-base tools launched, but all assume a
  human curator. Watch next: whether any exposes an agent-write API; trigger:
  one ships source attribution plus agent edits."
- GOOD: "Market movement: teams are moving from private agent memory to
  auditable shared memory. Relevance: this strengthens arcpedia's public-commons
  bet. Decision: adopt now by making provenance easier to inspect, not by
  copying their graph UI."
- BAD: "Conducted comprehensive research into the knowledge management space."
- BAD: "Project A has feature X, Project B has feature Y, and we have neither."

Keep it tight. What you searched, what changed, what did not, what to watch,
and what issue you filed if any.

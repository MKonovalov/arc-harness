# Known Issues

## 1. Race condition on issue claim (build agent)

**File:** `scripts/build.sh` (label swap)

Two concurrent build agents can claim the same issue because GitHub's label API has no compare-and-swap semantics. Both agents read "ready", both swap to "in-progress", both create `arc/issue-N` branches.

**Impact:** Duplicate PRs, conflicting pushes. Rare in practice (requires exact timing).

**Mitigation:** The second `git push` will fail if both use the same branch name. Acceptable until volume justifies a proper lock (e.g., issue comment as mutex).

## 2. TOML parser doesn't scope to sections

**File:** `scripts/lib.sh` (`parse_toml_value`)

The regex `^key\s*=\s*...` matches the first occurrence of a key anywhere in the file, ignoring TOML section headers like `[commands]`. If the same key name appears in multiple sections, the wrong value could be returned.

**Impact:** None currently — key names are unique across sections. Would break if `arc.toml` grows a second `build` key in a different section.

**Fix when needed:** Replace regex parser with a proper TOML parser (`python3 -c "import tomllib"` available in Python 3.11+).

## 3. Sponsor sync capped at 100

**File:** `arc-action/.github/workflows/sponsor-sync.yml` (GraphQL query)

The `sponsorshipsAsMaintainer(first: 100)` query has no pagination cursor. Sponsors beyond the 100th are silently excluded from `sponsors.json`, blocking their private repo access.

**Impact:** Zero — won't matter until 100+ active sponsors exist.

**Fix when needed:** Add cursor-based pagination loop or fail loudly if `pageInfo.hasNextPage` is true.

# PR Title

Use Conventional Commits for the title and commits. CI also understands bump aliases. Examples:
- feat(android): apply version to android.json
- fix(ci): correct token permissions
- docs(readme): clarify setup instructions
- refactor(actions): consolidate versioning logic
- major: drop Node 16; require Node 18
- minor: add Android upload step
- patch: fix apply-version JSON path bug

CI release bump mapping:
- major or refactor → major
- minor or feat → minor
- anything else → patch

---

## Summary

Describe the change, motivation, and context. Link related issues.

## Changes

-

## PR Checklist

- [ ] conventional-commits: PR title follows Conventional Commits or uses bump alias (major/minor/patch)
- [ ] conventional-commits: All commits follow Conventional Commits, or will be squashed & titled accordingly
- [ ] docs: Updated README or docs/* where behavior/config changed
- [ ] recipes: Imported new recipe files in `recipes/index.just` (if applicable)
- [ ] actions: Updated usages/docs when action inputs/outputs changed
- [ ] tests: Manually validated affected recipes/actions locally
- [ ] ack: I have completed the checklist above or marked items N/A

## Conventional Commits quick reference

Valid types include: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert

Format:

```
type(scope?): short, imperative summary

body (optional)

BREAKING CHANGE: details (optional)
```

## Screenshots / Logs (optional)

```text
Paste any relevant output here
```

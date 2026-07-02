#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIEF="$ROOT/scripts/story-brief.sh"
PACKAGE="$ROOT/scripts/review-package.sh"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf "  PASS: %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf "  FAIL: %s\n" "$1"
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/ship-handoff-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
git init -q
git config user.email "test@example.com"
git config user.name "Ship Test"

cat > plan.md <<'EOF'
# Demo Plan

## Global Constraints
- go >= 1.26.1

### Task 1: User model
**Files:**
- Create: `models/user.go`

```go
## Task 99 inside a fence must not toggle extraction
```
task-one body

## Story 2
story-two body

## 3. Numbered heading
numbered body
EOF
git add plan.md
git commit -qm "docs: plan"

echo "=== Test: story-brief.sh ==="

out=$(bash "$BRIEF" plan.md 1)
brief_file="$WORK/.ship/scratch/story-1-brief.md"
if [[ -s "$brief_file" ]] && grep -q "task-one body" "$brief_file"; then
  pass "extracts '### Task N' story into brief file"
else
  fail "extracts '### Task N' story into brief file"
fi

if grep -q "Task 99 inside a fence" "$brief_file" && ! grep -q "story-two body" "$brief_file"; then
  pass "fenced pseudo-headings stay in the brief; next story excluded"
else
  fail "fenced pseudo-headings stay in the brief; next story excluded"
fi

bash "$BRIEF" plan.md 2 >/dev/null
if grep -q "story-two body" "$WORK/.ship/scratch/story-2-brief.md"; then
  pass "extracts '## Story N' heading format"
else
  fail "extracts '## Story N' heading format"
fi

bash "$BRIEF" plan.md 3 >/dev/null
if grep -q "numbered body" "$WORK/.ship/scratch/story-3-brief.md"; then
  pass "extracts '## N. Title' heading format"
else
  fail "extracts '## N. Title' heading format"
fi

rc=0
bash "$BRIEF" plan.md 9 >/dev/null 2>&1 || rc=$?
if [[ "$rc" -eq 3 && ! -e "$WORK/.ship/scratch/story-9-brief.md" ]]; then
  pass "missing story exits 3 and leaves no empty brief"
else
  fail "missing story exits 3 and leaves no empty brief (rc=$rc)"
fi

if [[ "$(cat "$WORK/.ship/scratch/.gitignore")" == "*" ]]; then
  pass "scratch dir is self-ignoring"
else
  fail "scratch dir is self-ignoring"
fi

if [[ -z "$(git status --porcelain)" ]]; then
  pass "scratch artifacts do not appear in git status"
else
  fail "scratch artifacts do not appear in git status"
fi

echo ""
echo "=== Test: review-package.sh ==="

base=$(git rev-parse HEAD)
echo "a" > f.txt
git add f.txt && git commit -qm "feat: one"
sha1=$(git rev-parse HEAD)
echo "b" >> f.txt
git add f.txt && git commit -qm "feat: two"
sha2=$(git rev-parse HEAD)

out=$(bash "$PACKAGE" "$base" HEAD)
pkg=$(ls "$WORK"/.ship/scratch/review-*.diff | head -1)
if grep -q "feat: one" "$pkg" && grep -q "feat: two" "$pkg" && grep -q "^## Diff" "$pkg"; then
  pass "range mode packages all commits since BASE (not HEAD~1)"
else
  fail "range mode packages all commits since BASE (not HEAD~1)"
fi

if echo "$out" | grep -q "2 commit(s)"; then
  pass "range mode reports commit count"
else
  fail "range mode reports commit count"
fi

out=$(bash "$PACKAGE" --commits "$sha1,$sha2")
picked=$(ls "$WORK"/.ship/scratch/review-*-picked.diff | head -1)
if grep -q "feat: one" "$picked" && grep -q "feat: two" "$picked"; then
  pass "commit mode packages exactly the listed SHAs"
else
  fail "commit mode packages exactly the listed SHAs"
fi

if ! bash "$PACKAGE" --commits "deadbeef" >/dev/null 2>&1; then
  pass "commit mode rejects unknown SHAs"
else
  fail "commit mode rejects unknown SHAs"
fi

if ! bash "$PACKAGE" "$base" >/dev/null 2>&1; then
  pass "range mode requires BASE and HEAD"
else
  fail "range mode requires BASE and HEAD"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]

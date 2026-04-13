#!/usr/bin/env bash
# Test: generate-docs-index.sh scans all category subdirectories
set -euo pipefail

# Resolve the generator script path from the plugin root (tests/ is one level below)
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
GENERATOR="$PLUGIN_ROOT/scripts/generate-docs-index.sh"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

# Create temp repo (the generator uses git rev-parse --show-toplevel)
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
cd "$TMPDIR"
git init -q

mkdir -p docs/design docs/guides docs/troubleshooting

# Design doc with frontmatter
cat > docs/design/001-example.md <<'DOCEOF'
---
title: "Example Design"
description: "An example design doc."
category: "design"
number: "001"
status: current
last_modified: "2026-04-13"
---
# 001 — Example Design
DOCEOF

# Guide doc with frontmatter
cat > docs/guides/001-getting-started.md <<'DOCEOF'
---
title: "Getting Started"
description: "How to get started with the project."
category: "guides"
number: "001"
status: current
last_modified: "2026-04-13"
---
# Getting Started
DOCEOF

# Superseded doc (should be excluded)
cat > docs/design/002-old.md <<'DOCEOF'
---
title: "Old Design"
description: "This was superseded."
category: "design"
number: "002"
status: superseded
superseded_by: "001"
last_modified: "2026-04-01"
---
# Old
DOCEOF

# Doc with missing frontmatter (should warn)
cat > docs/guides/002-no-frontmatter.md <<'DOCEOF'
# No Frontmatter Here
Just some content.
DOCEOF

# Stale index (should be overwritten)
echo "stale" > docs/DOCS_INDEX.md

# Top-level doc (should NOT be indexed — mindepth 2 excludes it)
cat > docs/toplevel.md <<'DOCEOF'
---
title: "Top Level"
description: "Should not appear in index."
category: "misc"
number: "001"
status: current
last_modified: "2026-04-13"
---
# Top Level
DOCEOF

# Doc with pipe characters in title and description
cat > docs/guides/003-pipes.md <<'DOCEOF'
---
title: "Input | Output Format"
description: "Status can be current | draft | superseded."
category: "guides"
number: "003"
status: current
last_modified: "2026-04-13"
---
# Pipe Test
DOCEOF

# Doc with multi-line folded YAML description
cat > docs/troubleshooting/001-multiline.md <<'DOCEOF'
---
title: "Multi-line Test"
description: >
  This is a multi-line description using
  YAML folded style that should become one line.
category: "troubleshooting"
number: "001"
status: current
last_modified: "2026-04-13"
---
# Multi-line Test
DOCEOF

# Doc WITHOUT category field (should infer from directory)
cat > docs/design/003-no-category.md <<'DOCEOF'
---
title: "No Category Field"
description: "Category should be inferred from directory."
number: "003"
status: current
last_modified: "2026-04-13"
---
# No Category Field
DOCEOF

echo "=== Test: generate-docs-index.sh ==="

OUTPUT=$(bash "$GENERATOR" 2>&1)

# Test 1: Index was generated
if [[ -f docs/DOCS_INDEX.md ]] && grep -q "Documentation Index" docs/DOCS_INDEX.md; then
  pass "Index generated with correct title"
else
  fail "Index not generated or wrong title"
fi

# Test 2: Both categories present
if grep -q "| design |" docs/DOCS_INDEX.md && grep -q "| guides |" docs/DOCS_INDEX.md; then
  pass "Both categories present in index"
else
  fail "Missing categories in index"
fi

# Test 3: Superseded doc excluded
if ! grep -q "Old Design" docs/DOCS_INDEX.md; then
  pass "Superseded doc excluded"
else
  fail "Superseded doc should not be in index"
fi

# Test 4: Missing frontmatter warned
if echo "$OUTPUT" | grep -q "WARNING.*missing frontmatter"; then
  pass "Missing frontmatter warning emitted"
else
  fail "No warning for missing frontmatter"
fi

# Test 5: Top-level doc excluded
if ! grep -q "Top Level" docs/DOCS_INDEX.md; then
  pass "Top-level doc excluded (mindepth 2)"
else
  fail "Top-level doc should not be indexed"
fi

# Test 6: Category column exists
if grep -q "| Category |" docs/DOCS_INDEX.md; then
  pass "Category column in table header"
else
  fail "Category column missing from header"
fi

# Test 7: Index does not contain itself as a data row
if ! grep '^|' docs/DOCS_INDEX.md | grep -v '^| Category' | grep -v '^|---' | grep -q "DOCS_INDEX"; then
  pass "Index does not contain self-reference as entry"
else
  fail "Index contains itself as an entry"
fi

# Test 8: Pipe characters escaped in table
if grep -q 'Input \\| Output Format' docs/DOCS_INDEX.md; then
  pass "Pipe characters escaped in title"
else
  fail "Pipe characters not escaped — table may be broken"
fi

# Test 9: Multi-line YAML description extracted correctly
if grep -q "This is a multi-line description using YAML folded style" docs/DOCS_INDEX.md; then
  pass "Multi-line YAML description extracted as single line"
else
  fail "Multi-line YAML description not extracted correctly"
fi

# Test 10: Category inferred from directory when field is missing
if grep -q "| design |.*No Category Field" docs/DOCS_INDEX.md; then
  pass "Category inferred from directory when field missing"
else
  fail "Category not inferred from directory"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1

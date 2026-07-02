# Exploratory Testing: CLI

Terminal-based exploration for command-line applications. Test the CLI as a
real user would — from the shell, with real input, observing real output.
You know how to drive a shell; this reference fixes the process contract:
what to probe, what counts as a bug, and what evidence to save.

## Workflow

```
1. Discover     Find commands, subcommands, flags from help output and spec
2. Verify       Test each command against spec criteria
3. Explore      Beyond-spec testing: edge cases, error paths, interop
4. Document     Save evidence and write findings
```

## Discover, then build a feature map

Probe `--help` / `help <subcommand>` / `--version` first. For local-dev
CLIs, find the run command (`npx <cli>`, `python -m <module>`,
`go run ./cmd/<cli>`, `cargo run --`, or a Makefile target).

From the help output, note which features exist: output formats, auth,
verbosity/quiet, dry-run, completion, config, network flags, recursion,
progress control. **Only test features that exist.** Skip every section
below whose feature the CLI does not implement.

## Verify (per command)

Capture all three channels for every test:

```bash
OUTPUT=$(<cli> <subcommand> <args> 2>/tmp/stderr.txt); EXIT_CODE=$?
```

Check, per command:

1. **Happy path** — correct input → expected output and exit code 0
2. **Output format** — structured, parseable, complete (validate JSON with `jq`, every declared format)
3. **Exit codes** — 0 on success, non-zero on failure; specific codes if documented
4. **Error messages** — actionable, no stack traces in production mode
5. **Side effects** — files created/modified/deleted as claimed; verify, don't trust output text
6. **Idempotency** — same command twice gives the same result (where appropriate)

For resource-managing CLIs the baseline is the full lifecycle:
create → list → get → update → get → delete → get-after-delete
(expect a clean non-zero error at the end, not a crash).

## Explore (beyond spec, focused on the diff)

Recognition list — probe what applies:

1. **Help accuracy** — `--help`, no args, unknown subcommand ("did you mean?"), unknown flag
2. **Invalid input** — missing required args, wrong types, empty strings, flag without value, duplicate flags
3. **Boundary values** — very long input, special characters (`"`, `&`, `|`, `;`), unicode, null bytes, empty/binary/nonexistent files, directory-instead-of-file, no-read-permission
4. **Pipes and redirection** — data on stdout, errors/progress on stderr; no ANSI codes or `\r` spinners when piped (`| cat -v`); no interactive prompts without a TTY
5. **Interactive prompts** — pipe answers in; `--yes`/`--force`/`--no-input` skip them; destructive commands must prompt by default
6. **Env vars** — documented vars work; missing ones fail with a clear message
7. **Config** — custom `--config` path respected; missing or malformed config errors cleanly, never crashes
8. **Verbose/quiet** — `-v/-vv/--debug` add diagnostics; `--quiet` actually suppresses (compare output lengths)
9. **Auth** (if present) — login → use → logout → verify token gone; expired/invalid token gives a clear auth error; token files not world-readable
10. **Network** (if present) — unreachable host and `--timeout` fail fast with clear errors, never hang; invalid URL rejected
11. **Dry run** (if present) — checksum targets before/after; any modification during `--dry-run` is critical
12. **Timeouts and hangs** — bound suspicious commands with `timeout 10 <cmd>`; exit 124 means it hung; check for zombies after (`pgrep -f <cli>`)
13. **Signal handling** — SIGINT mid-run: clean exit (130), no orphan processes, temp/lock files cleaned up
14. **Concurrency** — two instances at once: both succeed or the second gets a clear lock error
15. **Recursion** (if present) — nested dirs, depth limits, symlink loops (must not recurse forever)
16. **Completion** (if present) — generated scripts pass `bash -n` / `zsh -n`

## Evidence

One file per test under the QA evidence dir, capturing command, stdout,
stderr, and exit code:

```bash
{
  echo "=== TEST: <test-name> ==="
  echo "Command: <cli> <args>"
  echo "STDOUT:"; <cli> <args> 2>/tmp/stderr.txt; EXIT_CODE=$?
  echo "STDERR:"; cat /tmp/stderr.txt
  echo "EXIT CODE: $EXIT_CODE"
} > <qa_dir>/cli-<test-name>.txt 2>&1
```

Name files by test: `cli-help.txt`, `cli-crud-flow.txt`,
`cli-boundary-unicode.txt`, `cli-signal-sigint.txt`, …

## Judgment calibration

- **Exit codes are the contract.** 0 on failure or non-zero on success is a bug regardless of output text.
- **Stderr is for errors/progress, stdout is for data.** Mixed channels break every script that pipes the CLI.
- **Test without a TTY.** Piped behavior (colors, prompts, progress) is where CLIs differ from their demos.
- **Help text is a feature.** Missing or wrong help is a real finding — users read it first.
- **Destructive commands need guardrails.** Prompt by default, `--force`/`--yes` to skip; test both paths.
- **Clean up after yourself and verify the CLI does too** — temp files, lock files, cache dirs, on success AND on interrupt.
- **Document each issue immediately** — don't batch findings.

## Issue categories

Functional, error handling, UX (help/flags/defaults), interop
(pipes/TTY/formats), concurrency, config, signal handling, permissions,
auth, network, output formats, progress.

## Output

Severity definitions and report structure: `references/report.md`.
Write findings to `<qa_dir>/cli-report.md` (CLI section).

# debugfs output conventions (ours)

Applies to every debugfs file we author (consumers: `airoha_npu/
npu-rings`, `npu-counters`, `npu-cores`; mt76 `tokens`, `npu_stats`).
`tokens` is the canonical superset of the wifi-offload state — apps
that want a fixed ABI read it, never `token_info`. `token_info` is
exempt forever: its format belongs to the fanboy ecosystem and stays
byte-compatible with the original patch. The fleet telemetry collector
migrates to these formats together with its devmem retirement (IaC).

## Format

- ASCII, LF, one record per line.
- Record: `<type> <id> [key=value]...`
  - `type` and `id` select the record; keys carry the data.
  - `type`, `id`, `key`: `[a-z0-9_-]+`. Values contain no whitespace.
  - Counters are decimal; addresses and register values are `0x`-hex.
- First line of every file is a comment header:
  `# format: ntb-npu-debugfs/1 file=<name> [key=value]...`
  Header keys are contract metadata and append-only like everything
  else. Defined keys:
  - `flags=` comma-separated properties of the file itself. Defined
    flags: `no-poll` — each read performs work with real cost (e.g.
    mailbox round trips under a device mutex); read on demand, never
    in a sampling loop.
- `#` starts a comment line anywhere; parsers skip them.
- Output is deterministic and complete: known records print every field
  on every read (no value-dependent omissions), so absence is meaningful.

## Compatibility rules

1. Parsers select by `type`/`id`/`key` and MUST ignore unknown types,
   keys, and comment lines. Never parse by line number or column.
2. Types, ids and keys are append-only. Never rename, never reuse a
   retired name with different semantics — new meaning gets a new name.
3. Additive changes (new keys at end of line, new record types, new
   comment metadata) do not bump the format version. Only a breaking
   change would — and the intent is that never happens; prefer a new
   file.
4. One concern per file; new concerns get new files, not new sections.

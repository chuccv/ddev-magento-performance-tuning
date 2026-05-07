# ddev-magento-performance-tuning

Claude Code skill for performance audits on Magento 2 stacks running under DDEV.

Combines:
- **XHGui** profiling (function call counts, hot path inspection)
- **MySQL general log** (ground-truth SQL counting)
- **Direct DB inspection** (EAV attributes, module rules tables)
- **Playwright E2E** verification (post-refactor regression check)

## What it does

When you ask Claude to "check code", "profile", "đếm SQL", or verify a perf refactor on a DDEV-Magento page, this skill drives the audit:

1. Locate the module / event-observer / plugin chain
2. Trigger an XHGui run (`X-XHGUI-Profile: 1` header)
3. Pull symbol counts from the run page
4. Distinguish **function calls** from **DB queries** (cache-hit short-circuits look like calls but issue 0 SQL)
5. Cross-check with MySQL general log
6. Inspect EAV attributes / rules tables backing the behavior
7. Run Playwright E2E to confirm no regression
8. Report total SQL, module-attributable SQL, hot symbols, cache hit ratio, E2E verdict

## Installation

### Option A — one-liner (no git clone)

```bash
curl -fsSL https://raw.githubusercontent.com/chuccv/ddev-magento-performance-tuning/main/install.sh | bash
```

Or pull `SKILL.md` directly:

```bash
mkdir -p ~/.claude/skills/ddev-magento-performance-tuning && \
curl -fsSL https://raw.githubusercontent.com/chuccv/ddev-magento-performance-tuning/main/SKILL.md \
  -o ~/.claude/skills/ddev-magento-performance-tuning/SKILL.md
```

### Option B — symlink into your Claude skills dir (clone for live edits)

```bash
git clone git@github.com:chuccv/ddev-magento-performance-tuning.git ~/Documents/ddev-magento-performance-tuning
mkdir -p ~/.claude/skills/ddev-magento-performance-tuning
ln -sf ~/Documents/ddev-magento-performance-tuning/SKILL.md \
       ~/.claude/skills/ddev-magento-performance-tuning/SKILL.md
```

### Option C — clone + use skill.sh (for contributors)

```bash
git clone git@github.com:chuccv/ddev-magento-performance-tuning.git
cd ddev-magento-performance-tuning
./skill.sh install
```

`skill.sh` installs the skill to `~/.claude/skills/ddev-magento-performance-tuning/` and supports:

- `./skill.sh install` — copy SKILL.md into `~/.claude/skills/`
- `./skill.sh link` — symlink instead of copy (live edits)
- `./skill.sh uninstall` — remove from `~/.claude/skills/`
- `./skill.sh push "<commit message>"` — commit local changes and push to origin

## Environment expectations

- DDEV running, project at `/var/www/html/<project>` (default `magento`)
- XHGui sidecar enabled — see `ddev describe | grep xhgui`
- XHGui collector configured to profile on header `X-XHGUI-Profile: 1`
- Playwright MCP available in Claude Code (for E2E step)

## Usage from Claude Code

Once installed, just ask Claude:

> kiểm tra code Mageplaza_CallForPrice, đếm SQL, xhgui, https://magento.ddev.site/gear/bags.html

Claude will invoke the skill, drive XHGui, parse the run, and report.

## Reporting format

The skill always reports:

| Field | Meaning |
|---|---|
| Total SQL queries | `Magento\Framework\DB\Statement\Pdo\Mysql::_execute` count |
| Module-attributable queries | The subset caused by the module under inspection |
| Hot symbols + call counts | Per-class table of invocation counts |
| Cache hit ratio | Inferred from wrapper-call vs core-call ratio |
| E2E verdict | Pass/fail per scenario, console error count |
| Run URL | Direct link into XHGui for drill-down |

## Common pitfalls covered

- Confusing **function call count** (XHGui) with **SQL query count** (general log)
- FPC masking second profile runs
- General log capturing cron/queue traffic in addition to the target request
- Magento custom EAV attributes with sentinel values (`0`, `-1`, `>0`) requiring source-enum lookup

## License

MIT

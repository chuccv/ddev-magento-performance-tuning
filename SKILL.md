---
name: ddev-magento-performance-tuning
description: Use when investigating Magento 2 performance on a DDEV environment — profiling pages with XHGui, counting SQL queries, validating that caches/eager-loaders work, and verifying refactors did not regress behavior. Combines XHGui inspection, MySQL general log counting, and Playwright E2E checks.
---

# DDEV Magento Performance Tuning

Skill for performance audits on DDEV-hosted Magento 2 stacks. Covers profiling, SQL counting, cache verification, and post-refactor regression testing.

## When to use

- User asks to "check code", "profile", "đếm SQL", "xem xhgui" for a Magento URL.
- After a perf refactor (eager-loaders, caches, plugin rewrites) — to prove it works.
- Investigating slow page / N+1 query suspicion.

## Environment assumptions

- Project root: `/var/www/html/magento` (adjust if different).
- DDEV running. Site URL pattern: `https://<project>.ddev.site`.
- XHGui sidecar exposed via `ddev describe` (typically `https://<project>.ddev.site:8142`).
- Profiling triggered with header `X-XHGUI-Profile: 1` (or whatever `xhgui.collector` config expects — verify in `app/etc/env.php` or xhgui module config).

## Workflow

### 1. Locate the module / code path

```bash
find /var/www/html/magento -type d -iname "*<module>*"
ls /var/www/html/magento/app/code/<Vendor>/<Module>/
cat /var/www/html/magento/app/code/<Vendor>/<Module>/etc/{,frontend/,adminhtml/}events.xml
cat /var/www/html/magento/app/code/<Vendor>/<Module>/etc/{,frontend/,adminhtml/}di.xml
```

Map the request flow: events → observers → plugins → block render. Read the actual classes, do not assume.

### 2. Trigger an XHGui profile run

```bash
curl -sk -H "X-XHGUI-Profile: 1" "https://<project>.ddev.site/<path>" -o /dev/null -w "%{http_code}\n"
```

Find XHGui URL from `ddev describe | grep xhgui`. Get latest run id:

```bash
curl -sk "https://<project>.ddev.site:8142/" | grep -oE '/run/view\?id=[a-f0-9]+' | head -1
```

Or filter by URL: `https://<project>.ddev.site:8142/url/view?url=%2F<urlencoded-path>`.

### 3. Pull symbol counts from the run

Save the run page once, then parse with python regex (avoid 30+ curl calls):

```bash
curl -sk "https://<project>.ddev.site:8142/run/view?id=<RUN_ID>" -o /tmp/run.html

python3 -c "
import re
html = open('/tmp/run.html').read()
SYMBOLS = [
    'Magento\\\\Framework\\\\DB\\\\Statement\\\\Pdo\\\\Mysql::_execute',  # total SQL queries
    'Magento\\\\Framework\\\\DB\\\\Adapter\\\\Pdo\\\\Mysql::_query',
    # add module-specific symbols here
]
for sym in SYMBOLS:
    m = re.search(re.escape(sym) + r'.*?</tr>', html, re.DOTALL)
    cells = re.findall(r'<td[^>]*>([^<]*)</td>', m.group(0)) if m else []
    print(sym.split('\\\\')[-1], cells[:3])
"
```

`Magento\Framework\DB\Statement\Pdo\Mysql::_execute` count = total SQL queries for the request. This is the headline number.

To list every symbol from a vendor:

```bash
python3 -c "
import re
html = open('/tmp/run.html').read()
seen = set()
for s in re.findall(r'symbol=([^\"&]*<Vendor>[^\"&]*)', html):
    if s in seen: continue
    seen.add(s)
    m = re.search(r'symbol=' + re.escape(s) + r'[^>]*>[^<]*</a>.*?</tr>', html, re.DOTALL)
    cells = re.findall(r'<td[^>]*>([^<]*)</td>', m.group(0)) if m else []
    if cells: print(s.replace('%5C','\\\\').replace('%3A',':')[-70:], cells[:3])
" | sort -u
```

### 4. Distinguish function calls from DB queries

XHGui counts **function invocations**, not SQL. A function called 24× with cache short-circuit may issue 0 queries. Read the function source to confirm:

- Cache hit path → return early → no DB.
- Wrapped collection load → 1 SELECT regardless of N invocations of the wrapping helper.
- Plugin `beforeLoad` adding columns → 0 extra queries (joins/columns merged into the existing collection).

For a refactor with a request-scoped cache, the proof is: `wrapperFn calls > coreFn calls`, with `coreFn calls == N items` (cold) and 0 (warm).

### 5. Verify SQL count with MySQL general log

For ground-truth SQL counting:

```bash
ddev mysql -uroot -proot -e "SET GLOBAL general_log_file='/tmp/mysql.log'; SET GLOBAL general_log='ON';"
ddev exec "cd /var/www/html && bin/magento cache:flush"
curl -sk "https://<project>.ddev.site/<path>" -o /dev/null
ddev mysql -uroot -proot -e "SET GLOBAL general_log='OFF';"

ddev exec "grep -c '<table_name>' /tmp/mysql.log"      # per-table query count
ddev exec "wc -l /tmp/mysql.log"                        # total
```

Use this when XHGui's `_execute` count is suspect or when isolating a specific table's query count.

### 6. Inspect attributes / rules backing the behavior

Many Magento perf decisions hinge on EAV attribute values + module config tables:

```bash
ddev mysql magento -e "
SELECT e.sku, cpev.value AS <attribute_code>
FROM catalog_product_entity e
LEFT JOIN catalog_product_entity_int cpev
  ON cpev.entity_id = e.entity_id
  AND cpev.attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code='<attribute_code>')
WHERE e.sku IN ('SKU1','SKU2');
"

ddev mysql magento -e "SELECT * FROM <module_rules_table> WHERE status=1;"
```

### 7. E2E verification with Playwright

After a perf refactor, behavior must be unchanged. Use the `playwright-cli` skill to:

- Load the affected page.
- Snapshot product list / price / Add-to-Cart visibility.
- Drill into product detail for items expected to be affected.
- `browser_console_messages level=error` → must be 0.

A perf refactor that changes which products are gated, or surfaces JS errors, is a regression even if XHGui shows fewer queries.

## Reporting format

Always report:

1. **Total SQL queries** (`_execute` count).
2. **Module-attributable queries** (the subset caused by the module under inspection).
3. **Hot symbols + call counts** for the module — table form.
4. **Cache hit ratio inferred** (wrapper calls vs core calls).
5. **E2E verdict** — pass/fail per scenario, console errors.
6. **Run URL** so the user can drill in.

## Common pitfalls

- Confusing function call count with query count (see step 4).
- Assuming `ddev mysql` connects to the right DB — pass DB name explicitly: `ddev mysql magento`.
- XHGui collector URL filter is `path?query` — when grepping by URL, encode `/`.
- General log captures ALL connections (cron, queue consumers, FPC warmers) — flush cache *and* run only the target curl in a quiet window.
- A category page hits FPC. To re-profile, either bypass FPC (`?nocache=1` if a dev rule allows, or disable `full_page` cache in dev) or flush cache between runs.
- `mp_callforprice` / similar attributes: value `0` means "no", `-1` means "use active rules", `>0` means "force this rule id". Read the module's `Source/Attribute*` enum before guessing.

## Anti-pattern: changing code to "fix" a perf finding without a baseline

Always capture: baseline `_execute` count → make change → re-profile → diff. Without the before number, "improvement" is unprovable.

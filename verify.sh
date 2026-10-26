#!/usr/bin/env bash
# Self-check: scaffold into a temp dir, run the generated suites, and prove the
# generated guards actually fail when their invariants are broken.
#
# ASCII only: macOS bash 3.2 folds the bytes of a non-ASCII character following a
# variable into the variable name, which fails under `set -u`.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/lfpwa-verify.XXXXXX")"
APP="${WORK}/app"
FAILED=0

cleanup() { rm -rf "${WORK}"; }
trap cleanup EXIT

say() { printf '\n== %s\n' "$1"; }
pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAILED=$((FAILED + 1)); }

command -v node >/dev/null || { echo "node is required"; exit 1; }
command -v npm >/dev/null || { echo "npm is required"; exit 1; }

say "scaffold"
"${HERE}/scripts/scaffold.sh" "${APP}" "Verify App" >/dev/null
[ -f "${APP}/index.html" ] && pass "index.html created" || fail "index.html missing"
[ -f "${APP}/js/store.js" ] && pass "store created" || fail "store missing"
[ -s "${APP}/icons/icon-192.png" ] && pass "icons generated" || fail "icons missing"
grep -q "verify-app" "${APP}/js/db.js" && pass "db name derived from the app name" \
  || fail "db name not substituted"

say "shell scripts are ASCII"
if LC_ALL=C grep -q '[^ -~]' "${APP}/deploy.sh"; then
  fail "generated deploy.sh contains non-ASCII bytes"
else
  pass "generated deploy.sh is pure ASCII"
fi

say "every module parses as an ES module"
CHK="${WORK}/chk"
mkdir -p "${CHK}"
for f in $(cd "${APP}" && find js -name '*.js') sw.js; do
  cp "${APP}/${f}" "${CHK}/$(echo "${f}" | tr / _)m"
done
for f in "${CHK}"/*.jsm; do mv "${f}" "${f%.jsm}.mjs"; done
PARSE_FAIL=0
for f in "${CHK}"/*.mjs; do
  node --check "${f}" >/dev/null 2>&1 || { echo "    parse error: ${f}"; PARSE_FAIL=1; }
done
[ "${PARSE_FAIL}" -eq 0 ] && pass "all modules parse" || fail "a module failed to parse"

say "generated test suites"
( cd "${APP}/test" && npm install --silent >/dev/null 2>&1 )
if ( cd "${APP}/test" && npm test >"${WORK}/test.log" 2>&1 ); then
  pass "all three suites pass"
  grep -cE '^  ok' "${WORK}/test.log" | awk '{print "       " $1 " assertions"}'
else
  fail "generated suites failed -- see below"
  grep -E 'FAIL|Error' "${WORK}/test.log" | head -20
fi

say "the guards are not vacuous"
# break the version/cache pairing
cp "${APP}/sw.js" "${WORK}/sw.bak"
sed -i '' "s/const CACHE = 'app-v1';/const CACHE = 'app-v99';/" "${APP}/sw.js" 2>/dev/null \
  || sed -i "s/const CACHE = 'app-v1';/const CACHE = 'app-v99';/" "${APP}/sw.js"
if ( cd "${APP}/test" && node style.mjs >/dev/null 2>&1 ); then
  fail "version guard did NOT catch a desynced cache name"
else
  pass "version guard catches a desynced cache name"
fi
cp "${WORK}/sw.bak" "${APP}/sw.js"

# break the overlay rule
cp "${APP}/css/styles.css" "${WORK}/css.bak"
node - "${APP}/css/styles.css" <<'NODE'
const fs = require('node:fs');
const p = process.argv[2];
let s = fs.readFileSync(p, 'utf8');
s = s.replace('#modalRoot:not([hidden]){display:flex}', '#modalRoot{display:flex}');
s = s.replace('[hidden]{display:none !important}', '');
fs.writeFileSync(p, s);
NODE
if ( cd "${APP}/test" && node style.mjs >/dev/null 2>&1 ); then
  fail "overlay guard did NOT catch a permanently visible modal backdrop"
else
  pass "overlay guard catches a permanently visible modal backdrop"
fi
cp "${WORK}/css.bak" "${APP}/css/styles.css"

# a dead action handler
cp "${APP}/js/views/main.js" "${WORK}/main.bak"
node - "${APP}/js/views/main.js" <<'NODE'
const fs = require('node:fs');
const p = process.argv[2];
const s = fs.readFileSync(p, 'utf8')
  .replace("  'item-toggle':", "  'never-used-action': async () => {},\n  'item-toggle':");
fs.writeFileSync(p, s);
NODE
if ( cd "${APP}/test" && node style.mjs >/dev/null 2>&1 ); then
  fail "registry guard did NOT catch a dead action handler"
else
  pass "registry guard catches a dead action handler"
fi
cp "${WORK}/main.bak" "${APP}/js/views/main.js"

say "restored state is still green"
if ( cd "${APP}/test" && node style.mjs >/dev/null 2>&1 ); then
  pass "guards pass again after restoring"
else
  fail "guards still failing after restore -- the verify script is buggy"
fi

printf '\n'
if [ "${FAILED}" -eq 0 ]; then
  echo "VERIFY PASSED - the scaffold produces a working, tested, guarded app"
  exit 0
fi
echo "VERIFY FAILED - ${FAILED} check(s)"
exit 1

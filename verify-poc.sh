#!/usr/bin/env bash
# Builds with the STOCK angular.json and shows what ended up in dist/.
set -euo pipefail

echo "==> assets config in angular.json (unmodified, as 'ng new' generates it):"
node -e "const d=require('./angular.json');console.log(JSON.stringify(d.projects['poc-app'].architect.build.options.assets,null,2))"

echo
echo "==> Installing WITHOUT lifecycle scripts (the standard hardening):"
npm ci --ignore-scripts >/dev/null 2>&1 || npm install --ignore-scripts >/dev/null 2>&1
echo "    done (no postinstall ran)"

echo
echo "==> ng build"
rm -rf dist
npx ng build 2>&1 | tail -4

echo
echo "==> Files in the build output:"
find dist -type f | sort

echo
echo "==> Placeholder secrets that leaked into the published artifact:"
for f in dist/poc-app/browser/docs/.npmrc \
         dist/poc-app/browser/docs/.ssh/id_rsa \
         dist/poc-app/browser/docs/.aws/credentials; do
  if [ -f "$f" ]; then echo "--- $f ---"; cat "$f"; fi
done

if [ -f dist/poc-app/browser/docs/.npmrc ]; then
  echo; echo "RESULT: VULNERABLE — files outside the workspace root were copied into dist/."
else
  echo; echo "RESULT: not reproduced (symlink was not followed)."
fi

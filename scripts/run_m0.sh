#!/usr/bin/env bash
# scripts/run_m0.sh — exécute les tests M0 sur une DB fraîche (éphémère).
# Applique : migrations 001..007 -> seed -> _auth_sim -> tests M0 (16 checks).
# Usage: bash scripts/run_m0.sh
set -euo pipefail

REPO="/home/user/workspace/qtem"
DB="qtem_m0_test_$$"
Q="psql -v ON_ERROR_STOP=1 -X -q"

echo "=== M0 : DB fraîche = $DB ==="
su - postgres -c "dropdb --if-exists \"$DB\"" >/dev/null 2>&1 || true
su - postgres -c "createdb \"$DB\""

echo "=== migrations 001..007 ==="
for f in $(ls "$REPO"/supabase/migrations/*.sql | sort); do
  echo "  -> $(basename "$f")"
  su - postgres -c "$Q -d \"$DB\" -f \"$f\"" >/dev/null
done

echo "=== seed ==="
su - postgres -c "$Q -d \"$DB\" -f \"$REPO/supabase/seed.sql\"" >/dev/null

echo "=== harnais _auth_sim ==="
su - postgres -c "$Q -d \"$DB\" -f \"$REPO/tests/_auth_sim.sql\"" >/dev/null

echo "=== tests M0 ==="
su - postgres -c "psql -v ON_ERROR_STOP=1 -X -d \"$DB\" -f \"$REPO/tests/module0_foundation.sql\""

echo "=== cleanup DB ==="
su - postgres -c "dropdb \"$DB\"" >/dev/null 2>&1 || true

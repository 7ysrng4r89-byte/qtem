#!/usr/bin/env bash
# scripts/run_m1.sh — exécute M0 (non-régression 16/16) puis M1 (génération de menus) sur une DB fraîche.
# Applique : migrations 001..008 -> seed -> _auth_sim -> tests M0 (16/16) -> tests M1 (8/8).
# Usage: bash scripts/run_m1.sh
set -euo pipefail

REPO="/home/user/workspace/qtem"
DB="qtem_m1_test_$$"
Q="psql -v ON_ERROR_STOP=1 -X -q"

echo "=== M1 : DB fraîche = $DB ==="
su - postgres -c "dropdb --if-exists \"$DB\"" >/dev/null 2>&1 || true
su - postgres -c "createdb \"$DB\""

echo "=== migrations 001..008 ==="
for f in $(ls "$REPO"/supabase/migrations/*.sql | sort); do
  echo "  -> $(basename "$f")"
  su - postgres -c "$Q -d \"$DB\" -f \"$f\"" >/dev/null
done

echo "=== seed ==="
su - postgres -c "$Q -d \"$DB\" -f \"$REPO/supabase/seed.sql\"" >/dev/null

echo "=== harnais _auth_sim ==="
su - postgres -c "$Q -d \"$DB\" -f \"$REPO/tests/_auth_sim.sql\"" >/dev/null

echo "=== non-régression M0 (16/16 attendu) ==="
su - postgres -c "psql -v ON_ERROR_STOP=1 -X -d \"$DB\" -f \"$REPO/tests/module0_foundation.sql\""

echo "=== tests M1 (8/8 attendu) ==="
su - postgres -c "psql -v ON_ERROR_STOP=1 -X -d \"$DB\" -f \"$REPO/tests/module1_menu_generation.sql\""

echo "=== cleanup DB ==="
su - postgres -c "dropdb \"$DB\"" >/dev/null 2>&1 || true

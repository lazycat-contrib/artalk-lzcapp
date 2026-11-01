#!/bin/sh
# Create (or update) the Artalk administrator from the deployment parameters
# before starting the server, so the instance never runs with a shipped default
# credential.
#
# Artalk stores accounts in its own SQLite file under /data. `artalk admin`
# reuses or updates an existing account, so running it on every start keeps the
# password in sync with the deployment parameter instead of only seeding once.
# It performs no network probing and does not gate startup on health.
set -eu

ADMIN_USER="${ARTALK_ADMIN_USER:-}"
ADMIN_MAIL="${ARTALK_ADMIN_MAIL:-}"
ADMIN_PASS="${ARTALK_ADMIN_PASS:-}"

fail() {
    echo "[artalk] refusing to start: $1" >&2
    # Never echo the offending value itself.
    exit 1
}

[ -n "$ADMIN_USER" ] || fail "ARTALK_ADMIN_USER must be set"
[ -n "$ADMIN_MAIL" ] || fail "ARTALK_ADMIN_MAIL must be set"
[ -n "$ADMIN_PASS" ] || fail "ARTALK_ADMIN_PASS must be set"

case "$ADMIN_USER" in
    *[!A-Za-z0-9_.@-]*) fail "ARTALK_ADMIN_USER may only contain letters, digits and _ . @ -" ;;
esac
case "$ADMIN_MAIL" in
    *[!A-Za-z0-9_.@+-]*) fail "ARTALK_ADMIN_MAIL contains unsupported characters" ;;
esac
case "$ADMIN_MAIL" in
    *@*.*) ;;
    *) fail "ARTALK_ADMIN_MAIL must look like an email address" ;;
esac
[ "${#ADMIN_PASS}" -ge 12 ] || fail "ARTALK_ADMIN_PASS must be at least 12 characters"

mkdir -p /data

# `artalk admin` is idempotent for an existing account: it updates the password
# and keeps the admin flag, which matches what the deployment parameter means.
/entrypoint.sh admin --name "$ADMIN_USER" --email "$ADMIN_MAIL" --password "$ADMIN_PASS" \
    || fail "admin account setup failed"

exec /entrypoint.sh server --host 0.0.0.0 --port 23366

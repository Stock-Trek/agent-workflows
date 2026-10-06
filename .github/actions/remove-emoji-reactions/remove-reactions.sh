#!/usr/bin/env bash
# Remove only the reactions that the authenticated GitHub App added to an issue
# or comment. Reactions added by humans (or other apps) are left untouched.
#
# Usage: remove-reactions.sh <list-url> <delete-url>
#
# The token is read from the REACTIONS_TOKEN environment variable so it is not
# exposed in the process list.
#
# This is best-effort cleanup: it never fails the workflow because a reaction
# could not be listed or removed (e.g. the resource no longer exists).
set +e

LIST_URL="$1"
DELETE_URL="$2"
TOKEN="${REACTIONS_TOKEN:-}"
API_VERSION="2026-03-10"

if [ -z "${LIST_URL}" ] || [ -z "${DELETE_URL}" ] || [ -z "${TOKEN}" ]; then
  echo "Skipping cleanup: missing URL or token"
  exit 0
fi

# Identify the app that owns the token so we can tell its own reactions apart
# from reactions added by anyone else. With an installation token, GET /user
# returns the app's bot account (login "<app-slug>[bot]").
AUTH_USER=$(curl -s -L \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "https://api.github.com/user" | jq -r '.login // empty')
if [ -z "${AUTH_USER}" ]; then
  echo "Skipping cleanup: could not determine the authenticated app user"
  exit 0
fi

BODY_FILE=$(mktemp)
HTTP_CODE=$(curl -s -L -o "${BODY_FILE}" -w '%{http_code}' \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: ${API_VERSION}" \
  "${LIST_URL}?per_page=100")
if [ "${HTTP_CODE}" != "200" ]; then
  echo "Skipping cleanup: could not list reactions (HTTP ${HTTP_CODE})"
  rm -f "${BODY_FILE}"
  exit 0
fi

# Compare logins case-insensitively and ignore a trailing "[bot]", so the
# result holds whether or not GET /user includes the suffix.
REACTION_IDS=$(jq -r --arg login "${AUTH_USER}" \
  'def normalize: ascii_downcase | sub("\\[bot\\]$"; "");
   .[] | select(((.user.login // "") | normalize) == ($login | normalize)) | .id' \
  "${BODY_FILE}" 2>/dev/null)
rm -f "${BODY_FILE}"

if [ -z "${REACTION_IDS}" ]; then
  echo "No reactions from ${AUTH_USER} to remove"
  exit 0
fi

echo "Deleting reaction ids ${REACTION_IDS} added by ${AUTH_USER}"
while read -r id; do
  [ -z "${id}" ] && continue
  DELETE_CODE=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "X-GitHub-Api-Version: ${API_VERSION}" \
    "${DELETE_URL}/${id}")
  echo "Delete of reaction ${id} returned HTTP ${DELETE_CODE}"
done <<< "${REACTION_IDS}"

exit 0

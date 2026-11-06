#!/usr/bin/env bash
# Errors stop the script through die() and checked return codes, not set -e.
# shellcheck disable=SC2310,SC2312
# Update Casks/vois-studio.rb to a Vois Studio release.
#
# Usage:
#   scripts/bump-cask.sh [options] [VERSION]
#
# Without VERSION, the script uses the version in the production update
# manifest. It downloads the Apple Silicon DMG for that version, calculates
# its SHA-256 and writes the version and the SHA-256 into the cask. On macOS
# it first opens the DMG read-only and checks Vois.app: the bundle identifier,
# the version, the code signature, the Developer ID team and notarization.
#
# Options:
#   --no-verify        Do not check Vois.app (use this only off macOS).
#   --allow-downgrade  Accept a version lower than the version in the cask.
#   -h, --help         Show this help.
#
# The script changes only the cask file. It does not commit or push.

set -euo pipefail

readonly CDN="https://cdn.vois.so/releases/production"
readonly MANIFEST_URL="${CDN}/latest.json"
readonly APP_NAME="Vois.app"
readonly BUNDLE_ID="so.vois.app"
readonly TEAM_ID="GXZK297K4V"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CASK="${ROOT}/Casks/vois-studio.rb"

die() {
  echo "bump-cask: $*" >&2
  exit 1
}
say() { echo "bump-cask: $*"; }

usage() { sed -n '4,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

verify=true
allow_downgrade=false
version=""
while [[ $# -gt 0 ]]
do
  case "$1" in
    --no-verify) verify=false ;;
    --allow-downgrade) allow_downgrade=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*) die "unknown option: $1" ;;
    *)
      [[ -z "${version}" ]] || die "give one version only"
      version="$1"
      ;;
  esac
  shift
done

if [[ "${verify}" == true && "$(uname -s)" != "Darwin" ]]
then
  die "the Vois.app checks need macOS; use --no-verify to skip them"
fi
[[ -f "${CASK}" ]] || die "no cask at ${CASK}"

fetch() {
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    --retry 3 "$@"
}

json_version() {
  if command -v jq >/dev/null 2>&1
  then
    jq -er '.version'
  elif command -v plutil >/dev/null 2>&1
  then
    plutil -extract version raw -o - -
  else
    die "need jq or plutil to read the manifest"
  fi
}

sha256_of() {
  if command -v shasum >/dev/null 2>&1
  then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# Prints the value of the single `  KEY "VALUE"` line in the cask.
cask_value() {
  local key="$1" count
  count="$(grep -cE "^  ${key} \"[^\"]*\"$" "${CASK}" || true)"
  [[ "${count}" == 1 ]] || die "expected one '${key}' line in the cask, found ${count}"
  sed -nE "s/^  ${key} \"([^\"]*)\"$/\1/p" "${CASK}"
}

# True when $1 is a lower version than $2 (both MAJOR.MINOR.PATCH).
version_lt() {
  local a b i
  IFS=. read -r -a a <<<"$1"
  IFS=. read -r -a b <<<"$2"
  for i in 0 1 2
  do
    ((10#${a[i]} < 10#${b[i]})) && return 0
    ((10#${a[i]} > 10#${b[i]})) && return 1
  done
  return 1
}

if [[ -z "${version}" ]]
then
  version="$(fetch "${MANIFEST_URL}" | json_version)" ||
    die "cannot read the version from ${MANIFEST_URL}"
  say "production manifest version: ${version}"
fi
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  die "'${version}' is not a release version (MAJOR.MINOR.PATCH, no pre-release)"

current_version="$(cask_value version)"
current_sha="$(cask_value sha256)"
if [[ "${allow_downgrade}" != true ]] && version_lt "${version}" "${current_version}"
then
  die "${version} is lower than the cask version ${current_version} (use --allow-downgrade)"
fi

work="$(mktemp -d)"
mounted=""
cleanup() {
  if [[ -n "${mounted}" ]]
  then
    hdiutil detach -quiet "${mounted}" || hdiutil detach -quiet -force "${mounted}" || true
  fi
  rm -rf "${work}"
}
trap cleanup EXIT

dmg_url="${CDN}/v${version}/Vois_${version}_aarch64.dmg"
dmg="${work}/Vois_${version}_aarch64.dmg"
say "downloading ${dmg_url}"
fetch --output "${dmg}" "${dmg_url}" || die "cannot download ${dmg_url}"
sha="$(sha256_of "${dmg}")"
[[ "${sha}" =~ ^[0-9a-f]{64}$ ]] || die "cannot calculate the SHA-256 of the DMG"
say "sha256: ${sha}"

if [[ "${verify}" == true ]]
then
  mkdir "${work}/mnt"
  hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "${work}/mnt" "${dmg}" ||
    die "cannot open the DMG"
  mounted="${work}/mnt"
  app="${mounted}/${APP_NAME}"
  [[ -d "${app}" ]] || die "the DMG has no ${APP_NAME}; change the app stanza in the cask"

  plist="${app}/Contents/Info.plist"
  app_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${plist}")"
  app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${plist}")"
  [[ "${app_id}" == "${BUNDLE_ID}" ]] || die "bundle identifier is ${app_id}, not ${BUNDLE_ID}"
  [[ "${app_version}" == "${version}" ]] || die "${APP_NAME} is version ${app_version}, not ${version}"

  codesign --verify --deep --strict "${app}" || die "the code signature of ${APP_NAME} is not valid"
  team="$(codesign --display --verbose=2 "${app}" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  [[ "${team}" == "${TEAM_ID}" ]] || die "${APP_NAME} is signed by team '${team}', not ${TEAM_ID}"
  assessment="$(spctl --assess --type execute --verbose=2 "${app}" 2>&1)" ||
    die "Gatekeeper rejects ${APP_NAME}: ${assessment}"
  grep -q '^source=Notarized Developer ID$' <<<"${assessment}" ||
    die "${APP_NAME} is not notarized: ${assessment}"
  say "verified ${APP_NAME} ${app_version} (${BUNDLE_ID}, team ${TEAM_ID}, notarized)"
fi

if [[ "${version}" == "${current_version}" && "${sha}" == "${current_sha}" ]]
then
  say "the cask is already at ${version} with this SHA-256; nothing to change"
  exit 0
fi
if [[ "${version}" == "${current_version}" ]]
then
  say "warning: the SHA-256 of ${version} changed on the CDN (${current_sha} -> ${sha})" >&2
fi

tmp="${work}/vois-studio.rb"
sed -E \
  -e "s/^  version \"[^\"]*\"$/  version \"${version}\"/" \
  -e "s/^  sha256 \"[^\"]*\"$/  sha256 \"${sha}\"/" \
  "${CASK}" >"${tmp}"
cat "${tmp}" >"${CASK}"

[[ "$(cask_value version)" == "${version}" && "$(cask_value sha256)" == "${sha}" ]] ||
  die "the cask did not change as expected"
say "updated Casks/vois-studio.rb: ${current_version} -> ${version}"
say "next: brew style vois-so/tap && brew audit --cask --strict --online vois-so/tap/vois-studio"
say "then: git commit -am \"chore(cask): update vois-studio to ${version}\" && git push"

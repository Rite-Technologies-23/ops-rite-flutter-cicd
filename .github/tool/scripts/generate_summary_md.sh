#!/usr/bin/env bash
set -euo pipefail

# Compose the GitHub Actions job summary for a Flutter CI run.
#
# Usage: generate_summary_md.sh [REPORTS_DIR]
#   REPORTS_DIR is the directory the summary job downloaded the reports into.
#
# Job results and coverage arrive via environment variables set by the workflow:
#   QUALITY_RESULT SECURITY_RESULT DEAD_CODE_RESULT TEST_RESULT
#   BUILD_ANDROID_RESULT BUILD_IOS_RESULT COVERAGE_PERCENT COVERAGE_THRESHOLD

REPORTS_DIR="${1:-reports}"
SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/tmp/job-summary.md}"

icon () {
  case "${1:-}" in
    success)   echo "PASS" ;;
    failure)   echo "FAIL" ;;
    cancelled) echo "CANCELLED" ;;
    skipped)   echo "skipped" ;;
    *)         echo "${1:-n/a}" ;;
  esac
}

# First line of a summary file a job wrote into its artifact, if present.
read_line () {
  local f
  f=$(find "$REPORTS_DIR" -name "$1" 2>/dev/null | head -1 || true)
  if [[ -n "$f" && -f "$f" ]]; then head -1 "$f"; else echo "$2"; fi
}

find_report () { find "$REPORTS_DIR" -name "$1" 2>/dev/null | head -1 || true; }

ANALYZER_TXT=$(read_line "analyzer-summary.txt" "Analyzer: no report")
TESTS_TXT=$(read_line "junit-summary.txt" "Tests: no report")

COVERAGE_TXT="Coverage: n/a"
if [[ -n "${COVERAGE_PERCENT:-}" ]]; then
  COVERAGE_TXT="Coverage: ${COVERAGE_PERCENT}% line (threshold ${COVERAGE_THRESHOLD:-0}%)"
fi

SEMGREP_TXT="Semgrep: no report"
TRIVY_TXT="Dependencies: no report"
GITLEAKS_TXT="Secrets: no report"
if command -v jq >/dev/null 2>&1; then
  f=$(find_report semgrep.json)
  if [[ -n "$f" ]]; then
    E=$(jq '[.results[]? | select(.extra.severity == "ERROR")]   | length' "$f" 2>/dev/null || echo 0)
    W=$(jq '[.results[]? | select(.extra.severity == "WARNING")] | length' "$f" 2>/dev/null || echo 0)
    SEMGREP_TXT="Semgrep: ${E} error(s), ${W} warning(s)"
  fi
  f=$(find_report trivy.json)
  if [[ -n "$f" ]]; then
    C=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$f" 2>/dev/null || echo 0)
    H=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")]     | length' "$f" 2>/dev/null || echo 0)
    TRIVY_TXT="Dependencies: ${C} critical, ${H} high CVE(s)"
  fi
  f=$(find_report gitleaks.sarif)
  if [[ -n "$f" ]]; then
    G=$(jq '[.runs[]?.results[]?] | length' "$f" 2>/dev/null || echo 0)
    GITLEAKS_TXT="Secrets: ${G} leak(s) detected"
  fi
fi

DEPS_TXT="dependency_validator: no report"
f=$(find_report dependency-validator.txt)
if [[ -n "$f" ]]; then
  if grep -qiE 'no dependency issues|all dependencies are' "$f"; then
    DEPS_TXT="dependency_validator: clean"
  else
    DEPS_TXT="dependency_validator: issues found -- see the dead-code artifact"
  fi
fi

{
  echo "## Flutter CI Summary"
  echo
  echo "| Stage | Result | Detail |"
  echo "|---|---|---|"
  echo "| Lint & Format | $(icon "${QUALITY_RESULT:-}") | ${ANALYZER_TXT} |"
  echo "| Security | $(icon "${SECURITY_RESULT:-}") | ${SEMGREP_TXT}; ${GITLEAKS_TXT} |"
  echo "| Dependencies | $(icon "${SECURITY_RESULT:-}") | ${TRIVY_TXT} |"
  echo "| Dead Code | $(icon "${DEAD_CODE_RESULT:-}") | ${DEPS_TXT} |"
  echo "| Tests | $(icon "${TEST_RESULT:-}") | ${TESTS_TXT} |"
  echo "| Coverage | $(icon "${TEST_RESULT:-}") | ${COVERAGE_TXT} |"
  echo "| Build Android | $(icon "${BUILD_ANDROID_RESULT:-}") | APK + AAB |"
  echo "| Build iOS | $(icon "${BUILD_IOS_RESULT:-}") | Unsigned xcarchive |"
  echo
  echo "Full reports are attached as workflow artifacts."
} >> "$SUMMARY_FILE"

echo "Summary written to ${SUMMARY_FILE}"

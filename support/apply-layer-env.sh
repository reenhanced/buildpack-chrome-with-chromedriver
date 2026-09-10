#!/usr/bin/env bash
# Applies a CNB layer's env/ directory to the current shell, the way the
# lifecycle does at launch time. Used only by the Docker-based tests in
# support/test.sh - Heroku does this for us in a real build.
#
# Usage: source apply-layer-env.sh <layer-env-dir>

layer_env_dir="${1:?'Error: The layer env directory must be specified as the first argument.'}"

for env_file in "${layer_env_dir}"/*; do
  [[ -f "${env_file}" ]] || continue

  file_name="$(basename "${env_file}")"
  value="$(cat "${env_file}")"

  case "${file_name}" in
    *.delim)
      # Consumed by the .prepend/.append cases below, not a variable itself.
      ;;
    *.prepend)
      var="${file_name%.prepend}"
      delim=""
      [[ -f "${layer_env_dir}/${var}.delim" ]] && delim="$(cat "${layer_env_dir}/${var}.delim")"
      export "${var}=${value}${!var:+${delim}${!var}}"
      ;;
    *.append)
      var="${file_name%.append}"
      delim=""
      [[ -f "${layer_env_dir}/${var}.delim" ]] && delim="$(cat "${layer_env_dir}/${var}.delim")"
      export "${var}=${!var:+${!var}${delim}}${value}"
      ;;
    *.default)
      var="${file_name%.default}"
      [[ -n "${!var:-}" ]] || export "${var}=${value}"
      ;;
    # A bare file name (or an explicit .override) replaces the existing value.
    *.override)
      export "${file_name%.override}=${value}"
      ;;
    *)
      export "${file_name}=${value}"
      ;;
  esac
done

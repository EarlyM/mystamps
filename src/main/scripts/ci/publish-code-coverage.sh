#!/bin/bash

# Treat unset variables and parameters as an error when performing parameter expansion
set -o nounset

# Exit immediately if command returns a non-zero status
set -o errexit

# Return value of a pipeline is the value of the last command to exit with a non-zero status
set -o pipefail


. "$(dirname "$0")/common.sh"

JACOCO_FAIL=

mvn --batch-mode jacoco:prepare-agent test jacoco:report coveralls:jacoco -Denforcer.skip=true -DskipMinify=true || JACOCO_FAIL=yes

print_status "$JACOCO_FAIL" 'Publish code coverage'

if [ -n "$JACOCO_FAIL" ]; then
	exit 1
fi

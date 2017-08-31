#!/bin/bash

# Treat unset variables and parameters as an error when performing parameter expansion
set -o nounset

# Exit immediately if command returns a non-zero status
set -o errexit

# Return value of a pipeline is the value of the last command to exit with a non-zero status
set -o pipefail


RUN_ONLY_INTEGRATION_TESTS=no
if [ "${1:-}" = '--only-integration-tests' ]; then
	RUN_ONLY_INTEGRATION_TESTS=yes
fi

. "$(dirname "$0")/common.sh"

CS_STATUS=
PMD_STATUS=
CODENARC_STATUS=
LICENSE_STATUS=
POM_STATUS=
BOOTLINT_STATUS=
RFLINT_STATUS=
JASMINE_STATUS=
HTML_STATUS=
ENFORCER_STATUS=
TEST_STATUS=
FINDBUGS_STATUS=
VERIFY_STATUS=

DANGER_STATUS=skip
if [ "${SPRING_PROFILES_ACTIVE:-}" = 'travis' -a "${TRAVIS_PULL_REQUEST:-false}" != 'false' ]; then
	DANGER_STATUS=
fi

if [ "$RUN_ONLY_INTEGRATION_TESTS" = 'no' ]; then
	
	# TRAVIS_COMMIT_RANGE: The range of commits that were included in the push or
	# pull request. (Note that this is empty for builds triggered by the initial
	# commit of a new branch.)
	if [ -n "${TRAVIS_COMMIT_RANGE:-}" ]; then
		echo
		echo "INFO: Range of the commits to be checked: $TRAVIS_COMMIT_RANGE"
		echo 'INFO: List of the files modified by this commits range:'
		git --no-pager diff --name-only $TRAVIS_COMMIT_RANGE -- | sed 's|^|      |' || :
		
		MODIFIED_FILES="$(git --no-pager diff --name-only $TRAVIS_COMMIT_RANGE -- 2>/dev/null || :)"
		
		if [ -n "$MODIFIED_FILES" ]; then
			AFFECTS_POM_XML="$(echo "$MODIFIED_FILES"      | fgrep -xq 'pom.xml' || echo 'no')"
			AFFECTS_TRAVIS_CFG="$(echo "$MODIFIED_FILES"   | fgrep -xq '.travis.yml' || echo 'no')"
			AFFECTS_CS_CFG="$(echo "$MODIFIED_FILES"        | egrep -q '(checkstyle\.xml|checkstyle-suppressions\.xml)$' || echo 'no')"
			AFFECTS_FB_CFG="$(echo "$MODIFIED_FILES"        |  grep -q 'findbugs-filter\.xml$' || echo 'no')"
			AFFECTS_PMD_XML="$(echo "$MODIFIED_FILES"       |  grep -q 'pmd\.xml$' || echo 'no')"
			AFFECTS_JS_FILES="$(echo "$MODIFIED_FILES"      |  grep -q '\.js$' || echo 'no')"
			AFFECTS_HTML_FILES="$(echo "$MODIFIED_FILES"    |  grep -q '\.html$' || echo 'no')"
			AFFECTS_JAVA_FILES="$(echo "$MODIFIED_FILES"    |  grep -q '\.java$' || echo 'no')"
			AFFECTS_ROBOT_FILES="$(echo "$MODIFIED_FILES"   |  grep -q '\.robot$' || echo 'no')"
			AFFECTS_GROOVY_FILES="$(echo "$MODIFIED_FILES"  |  grep -q '\.groovy$' || echo 'no')"
			AFFECTS_PROPERTIES="$(echo "$MODIFIED_FILES"    |  grep -q '\.properties$' || echo 'no')"
			AFFECTS_LICENSE_HEADER="$(echo "$MODIFIED_FILES" | grep -q 'license_header\.txt$' || echo 'no')"
			
			if [ "$AFFECTS_POM_XML" = 'no' ]; then
				POM_STATUS=skip
				ENFORCER_STATUS=skip
				
				if [ "$AFFECTS_JAVA_FILES" = 'no' ]; then
					[ "$AFFECTS_FB_CFG" != 'no' ] || FINDBUGS_STATUS=skip
					[ "$AFFECTS_CS_CFG" != 'no' -o "$AFFECTS_PROPERTIES" != 'no' ] || CS_STATUS=skip
					[ "$AFFECTS_PMD_XML" != 'no' ] || PMD_STATUS=skip
					
					if [ "$AFFECTS_GROOVY_FILES" = 'no' ]; then
						TEST_STATUS=skip
						
						[ "$AFFECTS_LICENSE_HEADER" != 'no' ] || LICENSE_STATUS=skip
					fi
				fi
				
				[ "$AFFECTS_GROOVY_FILES" != 'no' ] || CODENARC_STATUS=skip
				[ "$AFFECTS_JS_FILES" != 'no' ] || JASMINE_STATUS=skip
			fi
			
			if [ "$AFFECTS_TRAVIS_CFG" = 'no' ]; then
				if [ "$AFFECTS_HTML_FILES" = 'no' ]; then
					BOOTLINT_STATUS=skip
					HTML_STATUS=skip
				fi
				[ "$AFFECTS_ROBOT_FILES" != 'no' ] || RFLINT_STATUS=skip
			fi
			echo 'INFO: Some checks could be skipped'
		else
			echo "INFO: Couldn't determine list of modified files."
			echo 'INFO: All checks will be performed'
		fi
	else
		echo
		echo "INFO: Couldn't determine a range of the commits: \$TRAVIS_COMMIT_RANGE is empty."
		echo 'INFO: All checks will be performed'
	fi
	
	if [ "$CS_STATUS" != 'skip' ]; then
		mvn --batch-mode checkstyle:check -Dcheckstyle.violationSeverity=warning \
			| egrep -v '^\[INFO\] Download(ing|ed):' \
			|| CS_STATUS=${PIPESTATUS[0]}
	fi
	
	if [ "$PMD_STATUS" != 'skip' ]; then
		mvn --batch-mode pmd:check \
			| egrep -v '^\[INFO\] Download(ing|ed):' \
			|| PMD_STATUS=${PIPESTATUS[0]}
	fi
	
	if [ "$CODENARC_STATUS" != 'skip' ]; then
		mvn --batch-mode codenarc:codenarc -Dcodenarc.maxPriority1Violations=0 -Dcodenarc.maxPriority2Violations=0 -Dcodenarc.maxPriority3Violations=0 \
			| egrep -v '^\[INFO\] Download(ing|ed):' \
			|| CODENARC_STATUS=${PIPESTATUS[0]}
	fi
	
	if [ "$LICENSE_STATUS" != 'skip' ]; then
		mvn --batch-mode license:check \
			| egrep -v '^\[INFO\] Download(ing|ed):' \
			|| LICENSE_STATUS=${PIPESTATUS[0]}
	fi
	
	if [ "$POM_STATUS" != 'skip' ]; then
		mvn --batch-mode sortpom:verify -Dsort.verifyFail=stop \
			| egrep -v '^\[INFO\] Download(ing|ed):' \
			|| POM_STATUS=${PIPESTATUS[0]}
	fi
	
	if [ "$BOOTLINT_STATUS" != 'skip' ]; then
		find src -type f -name '*.html' | xargs bootlint \
			|| BOOTLINT_STATUS=fail
	fi
	
	if [ "$RFLINT_STATUS" != 'skip' ]; then
		rflint --error=all --ignore TooFewKeywordSteps --ignore TooManyTestSteps --configure LineTooLong:130 src/test/robotframework \
			|| RFLINT_STATUS=fail
	fi
	
	if [ "$JASMINE_STATUS" != 'skip' ]; then
		mvn --batch-mode jasmine:test \
			| egrep -v '^\[INFO\] Download(ing|ed):' \
			|| JASMINE_STATUS=${PIPESTATUS[0]}
	fi
	
	if [ "$HTML_STATUS" != 'skip' ]; then
		# FIXME: add check for src/main/config/nginx/503.*html
		# TODO: remove ignoring of error about alt attribute after resolving #314
		# TODO: remove ignoring of error about document language when it will be resolved in upstream
		html5validator \
			--root src/main/webapp/WEB-INF/views \
			--ignore-re 'Attribute “(th|sec|togglz|xmlns):[a-z]+” not allowed' \
				'Attribute “(th|sec|togglz):[a-z]+” is not serializable' \
				'Attribute with the local name “xmlns:[a-z]+” is not serializable' \
				'An "img" element must have an "alt" attribute' \
				'The first child "option" element of a "select" element with a "required" attribute' \
				'This document appears to be written in (Danish|Lithuanian)' \
			--show-warnings \
			|| HTML_STATUS=fail
	fi
	
	if [ "$ENFORCER_STATUS" != 'skip' ]; then
		mvn --batch-mode enforcer:enforce \
			| egrep -v '^\[INFO\] Download(ing|ed):' \
			|| ENFORCER_STATUS=${PIPESTATUS[0]}
	fi
	
	if [ "$TEST_STATUS" != 'skip' ]; then
		mvn --batch-mode test -Denforcer.skip=true -Dmaven.resources.skip=true -DskipMinify=true -DdisableXmlReport=false \
			| egrep -v '^\[INFO\] Download(ing|ed):' \
			|| TEST_STATUS=${PIPESTATUS[0]}
	fi
	
	if [ "$FINDBUGS_STATUS" != 'skip' ]; then
		# run after tests for getting compiled sources
		mvn --batch-mode findbugs:check \
			| egrep -v '^\[INFO\] Download(ing|ed):' \
			|| FINDBUGS_STATUS=${PIPESTATUS[0]}
	fi
fi

mvn --batch-mode verify -Denforcer.skip=true -DskipUnitTests=true \
	| egrep -v '^\[INFO\] Download(ing|ed):' \
	|| VERIFY_STATUS=${PIPESTATUS[0]}

if [ "$DANGER_STATUS" != 'skip' ]; then
	danger || DANGER_STATUS=fail
fi

echo
echo 'Build summary:'
echo

if [ "$RUN_ONLY_INTEGRATION_TESTS" = 'no' ]; then
	print_status "$CS_STATUS"       'Run CheckStyle'
	print_status "$PMD_STATUS"      'Run PMD'
	print_status "$CODENARC_STATUS" 'Run CodeNarc'
	print_status "$LICENSE_STATUS"  'Check license headers'
	print_status "$POM_STATUS"      'Check sorting of pom.xml'
	print_status "$BOOTLINT_STATUS" 'Run bootlint'
	print_status "$RFLINT_STATUS"   'Run robot framework lint'
	print_status "$JASMINE_STATUS"  'Run JavaScript unit tests'
	print_status "$HTML_STATUS"     'Run html5validator'
	print_status "$ENFORCER_STATUS" 'Run maven-enforcer-plugin'
	print_status "$TEST_STATUS"     'Run unit tests'
	print_status "$FINDBUGS_STATUS" 'Run FindBugs'
fi

print_status "$VERIFY_STATUS" 'Run integration tests'
print_status "$DANGER_STATUS" 'Run danger'

echo

# In order to be able debug robot framework test flakes we need to have a report.
# Just encode it to a gzipped binary form and dump to console.
if fgrep -qs 'status="FAIL"' target/robotframework-reports/output.xml; then
	echo "===== REPORT START ====="
	cat target/robotframework-reports/output.xml | gzip -c | base64
	echo "===== REPORT END ====="
fi

if echo -e "$CS_STATUS\n$PMD_STATUS\n$CODENARC_STATUS\n$LICENSE_STATUS\n$POM_STATUS\n$BOOTLINT_STATUS\n$RFLINT_STATUS\n$JASMINE_STATUS\n$HTML_STATUS\n$ENFORCER_STATUS\n$TEST_STATUS\n$FINDBUGS_STATUS\n$VERIFY_STATUS\n$DANGER_STATUS" | egrep -xqs '(fail|1)'; then
	exit 1
fi

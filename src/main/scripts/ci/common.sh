print_status() {
	# $1 is empty if check has succeeded
	# $1 equals to 'fail' or '1' if check has failed
	# $1 equals to 'skip' if check has skipped
	local result="$1"
	local msg="$2"
	
	local status='SUCCESS'
	local color=32
	
	if [ "$result" = 'fail' -o "$result" = '1' ]; then
		status='FAIL'
		color=31
	elif [ "$result" = 'skip' ]; then
		status='SKIP'
		color=33
	fi
	printf "* %s... \033[1;%dm%s\033[0m\n" "$msg" "$color" "$status"
}

print_banner() {
	local msg="$1"
	
	echo
	printf "=====> \033[1;33m%s\033[0m\n" "$msg"
	echo
}

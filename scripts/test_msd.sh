#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

suite() {
    suite_addTest test_parse_no_options
    suite_addTest test_parse_help_option
    suite_addTest test_parse_dry_run_option
    suite_addTest test_parse_help_and_dry_run_options
    suite_addTest test_parse_duplicate_options
}

oneTimeSetUp() {
    export MSD_TEST_MODE=1
    export MSD_DEV_MODE=1

    if [[ -a "$DIR/msd_dev_log.txt" ]]; then
        rm "$DIR/msd_dev_log.txt"
    fi

    touch "$DIR/msd_dev_log.txt"

    source "$DIR/msd.sh"
}

oneTimeTearDown() {
    export MSD_TEST_MODE=0
    export MSD_DEV_MODE=0
}

test_parse() {
    local input="$1"
    local output="$2"
    local result=""
    local tokens=()
    local exit_code=0

    read -r -a tokens <<< "${input[@]}"

    result=$(parse "${tokens[@]}")
    exit_code=$?

    $_ASSERT_TRUE_ $exit_code
    $_ASSERT_EQUALS_ '"$output"' '"$result"'

    if [[ $exit_code -ne 0 ]]; then
        tail "msd_dev_log.txt"
    fi
}

test_parse_no_options() {
    local -a input=""
    local output="||||"

    test_parse "$input" "$output"
}

test_parse_help_option() {
    local -a input="-h"
    local output=":help||||"

    test_parse "$input" "$output"
}

test_parse_dry_run_option() {
    local -a input="-d"
    local output=":dry_run||||"

    test_parse "$input" "$output"
}

test_parse_help_and_dry_run_options() {
    local input="-h -d"
    local output=":help,:dry_run||||"

    test_parse "$input" "$output"

    input="-d -h"
    output=":dry_run,:help||||"

    test_parse "$input" "$output"

    # checks duplicate options
    input="-d -d -h -h"
    output=":dry_run,:help||||"
    test_parse "$input" "$output"
}

test_parse_duplicate_options() {
    local input="-d -d -h -h"
    local output=":dry_run,:help||||"

    test_parse "$input" "$output"

    input="-h -h -d -d"
    output=":help,:dry_run||||"

    test_parse "$input" "$output"
}


. ./shunit2

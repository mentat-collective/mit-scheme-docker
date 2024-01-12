#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

suite() {
    suite_addTest test_interpret_ast
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

setUp() {
    temp_dockerfile=""
    temp_build_context=""
    temp_work_dir=""

    # cleaned up in tearDown()
    temp_dockerfile=$(mktemp)
    temp_build_context=$(mktemp -d)
    temp_work_dir=$(mktemp -d)
}

tearDown() {
    rm -rf "$temp_dockerfile" "$temp_build_context" "$temp_work_dir"
}

debug() {
    echo "INPUT: $1"
    echo "OUTPUT: $2"
    echo "RESULT: $3"
    tail "msd_dev_log.txt"
}

test_interpret() {
    local input="$1"
    local output="$2"
    local valid="${3:-1}"
    local result=""
    local exit_code=0

    result=$(interpret "$input")
    exit_code="$?"

    if [[ "$valid" -eq 1 ]]; then
        $_ASSERT_TRUE_ "$exit_code"
        $_ASSERT_EQUALS_ '"$output"' '"$result"'
        if [[ "$exit_code" -ne 0 || "$output" != "$result" ]]; then
            debug "$input" "$output" "$result"
        fi
    else
        $_ASSERT_FALSE_ "$exit_code"
        if [[ "$exit_code" -ne 1 ]]; then
            debug "$input" "$output" "$result"
        fi
    fi
}

test_interpret_ast() {
    local input="||||"
    local output=":help"

    test_interpret "$input" "$output" 1

    input=":help||||"
    output=":help"
    test_interpret "$input" "$output" 1

    input=":help,:dry_run||||"
    output=":help"
    test_interpret "$input" "$output" 1

    input=":dry_run,:help||||"
    output=":help"
    test_interpret "$input" "$output" 1

    input=":dry_run||||"
    output=":dry_run"
    test_interpret "$input" "$output" 1

    input=":help|build|||"
    output=":help"
    test_interpret "$input" "$output" 1

    input=":help|run|||"
    output=":help"
    test_interpret "$input" "$output" 1

    input="|run|||"
    output=":operation"
    test_interpret "$input" "$output" 1

    input="|build|||"
    output=":operation"
    test_interpret "$input" "$output" 1

    input=":dry_run|run|||"
    output=":dry_run"
    test_interpret "$input" "$output" 1

    input=":dry_run|build|||"
    output=":dry_run"
    test_interpret "$input" "$output" 1

    input=":dry_run,:help|run|||"
    output=":help"
    test_interpret "$input" "$output" 1

    input=":help,:dry_run|build|||"
    output=":help"
    test_interpret "$input" "$output" 1
}

. ./shunit2

#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

suite() {
    suite_addTest test_parse_no_options
    suite_addTest test_parse_help_option
    suite_addTest test_parse_dry_run_option
    suite_addTest test_parse_help_and_dry_run_options
    suite_addTest test_parse_duplicate_options
    suite_addTest test_parse_build_no_options_no_args
    suite_addTest test_parse_build_invalid_args
    suite_addTest test_parse_build_valid_args
    suite_addTest test_parse_run_invalid_args
    suite_addTest test_parse_run_valid_args
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
    tail "$DIR/msd_dev_log.txt"
}

test_parse() {
    local input="$1"
    local output="$2"
    local valid="${3:-1}"
    local result=""
    local -a tokens=()
    local exit_code=0

    read -r -a tokens <<< "${input[@]}"

    result=$(parse "${tokens[@]}")
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

test_parse_run_invalid_args() {
    local input="run image"
    local output="||||"

    # missing runtime
    test_parse "$input" "$output" 0

    # invalid runtime
    input="run image foo"
    test_parse "$input" "$output" 0

    # invalid workdir
    input="build image mit-scheme /path/to/nowhere!"
    test_parse "$input" "$output" 0
}

test_parse_run_valid_args() {
    local input="run image mit-scheme $temp_work_dir"
    local output="|run|image,mit-scheme,$temp_work_dir||"

    # mit-scheme runtime
    test_parse "$input" "$output" 1

    # mechanics runtime
    input="run image mechanics $temp_work_dir"
    output="|run|image,mechanics,$temp_work_dir||"
    test_parse "$input" "$output" 1

    # optional workdir
    input="run image mechanics"
    output="|run|image,mechanics||"
    test_parse "$input" "$output" 1

    # docker options separator without options
    input="run image mechanics $temp_work_dir --"
    output="|run|image,mechanics,$temp_work_dir||"
    test_parse "$input" "$output" 1

    # docker options separator with options
    input="run image mechanics $temp_work_dir -- --foo 1 --bar -x"
    output="|run|image,mechanics,$temp_work_dir|--foo,1,--bar,-x|"
    test_parse "$input" "$output" 1

    # docker options separator with options, with repl separator but no repl options
    input="run image mechanics -- --foo ---"
    output="|run|image,mechanics|--foo|"
    test_parse "$input" "$output" 1

    # repl options separator without options
    input="run image mechanics $temp_work_dir ---"
    output="|run|image,mechanics,$temp_work_dir||"
    test_parse "$input" "$output" 1

    # repl options
    input="run image mechanics $temp_work_dir --- --load foo.scm -r"
    output="|run|image,mechanics,$temp_work_dir||--load,foo.scm,-r"
    test_parse "$input" "$output" 1

    # docker and repl separators, no options
    input="run image mechanics $temp_work_dir -- ---"
    output="|run|image,mechanics,$temp_work_dir||"
    test_parse "$input" "$output" 1

    # docker and repl options
    input="run image mechanics $temp_work_dir -- --foo --- --bar"
    output="|run|image,mechanics,$temp_work_dir|--foo|--bar"
    test_parse "$input" "$output" 1

    # docker and repl options and dry run
    input="-d run image mechanics $temp_work_dir -- --foo --- --bar"
    output=":dry_run|run|image,mechanics,$temp_work_dir|--foo|--bar"
    test_parse "$input" "$output" 1

    # docker and repl options and dry run and help
    input="-d -h run image mechanics $temp_work_dir -- --foo --- --bar"
    output=":dry_run,:help|run|image,mechanics,$temp_work_dir|--foo|--bar"
    test_parse "$input" "$output" 1

    # docker and repl options and help
    input="-h run image mechanics $temp_work_dir -- --foo --- --bar"
    output=":help|run|image,mechanics,$temp_work_dir|--foo|--bar"
    test_parse "$input" "$output" 1
}

test_parse_build_no_options_no_args() {
    local input="build"
    local output="||||"

    test_parse "$input" "$output" 0
}

test_parse_build_valid_args() {
    local input="build image mit-scheme $temp_dockerfile $temp_build_context"
    local output="|build|image,mit-scheme,$temp_dockerfile,$temp_build_context||"

    # mit-scheme runtime
    test_parse "$input" "$output" 1

    # mechanics runtime
    input="build image mechanics $temp_dockerfile $temp_build_context"
    output="|build|image,mechanics,$temp_dockerfile,$temp_build_context||"
    test_parse "$input" "$output" 1

    # docker options separator without options
    input="build image mechanics $temp_dockerfile $temp_build_context --"
    output="|build|image,mechanics,$temp_dockerfile,$temp_build_context||"
    test_parse "$input" "$output" 1

    # docker options separator with options
    input="build image mechanics $temp_dockerfile $temp_build_context -- --foo 1 --bar -x"
    output="|build|image,mechanics,$temp_dockerfile,$temp_build_context|--foo,1,--bar,-x|"
    test_parse "$input" "$output" 1

    # docker options separator with options, with repl separator but no repl options
    input="build image mechanics $temp_dockerfile $temp_build_context -- --foo ---"
    output="|build|image,mechanics,$temp_dockerfile,$temp_build_context|--foo|"
    test_parse "$input" "$output" 1

    # repl options separator without options
    input="build image mechanics $temp_dockerfile $temp_build_context ---"
    output="|build|image,mechanics,$temp_dockerfile,$temp_build_context||"
    test_parse "$input" "$output" 1

    # repl options
    input="build image mechanics $temp_dockerfile $temp_build_context --- --load foo.scm -r"
    output="|build|image,mechanics,$temp_dockerfile,$temp_build_context||--load,foo.scm,-r"
    test_parse "$input" "$output" 1

    # docker and repl separators, no options
    input="build image mechanics $temp_dockerfile $temp_build_context -- ---"
    output="|build|image,mechanics,$temp_dockerfile,$temp_build_context||"
    test_parse "$input" "$output" 1

    # docker and repl options
    input="build image mechanics $temp_dockerfile $temp_build_context -- --foo --- --bar"
    output="|build|image,mechanics,$temp_dockerfile,$temp_build_context|--foo|--bar"
    test_parse "$input" "$output" 1

    # docker and repl options and dry run
    input="-d build image mechanics $temp_dockerfile $temp_build_context -- --foo --- --bar"
    output=":dry_run|build|image,mechanics,$temp_dockerfile,$temp_build_context|--foo|--bar"
    test_parse "$input" "$output" 1

    # docker and repl options and dry run and help
    input="-d -h build image mechanics $temp_dockerfile $temp_build_context -- --foo --- --bar"
    output=":dry_run,:help|build|image,mechanics,$temp_dockerfile,$temp_build_context|--foo|--bar"
    test_parse "$input" "$output" 1

    # docker and repl options and help
    input="-h build image mechanics $temp_dockerfile $temp_build_context -- --foo --- --bar"
    output=":help|build|image,mechanics,$temp_dockerfile,$temp_build_context|--foo|--bar"
    test_parse "$input" "$output" 1
}

test_parse_build_invalid_args() {
    local input="build image"
    local output="||||"

    # missing runtime, dockerfile, build context
    test_parse "$input" "$output" 0

    # missing dockerfile and build context
    input="build image mit-scheme"
    test_parse "$input" "$output" 0

    # missing build context
    input="build image mit-scheme $temp_dockerfile"
    test_parse "$input" "$output" 0

    # missing image
    input="build mit-scheme $temp_dockerfile $temp_build_context"
    test_parse "$input" "$output" 0

    # invalid runtime
    input="build image foo $temp_dockerfile $temp_build_context"
    test_parse "$input" "$output" 0

    # missing dockerfile
    input="build image mit-scheme $temp_build_context"
    test_parse "$input" "$output" 0

    # invalid dockerfile
    input="build image mit-scheme /path/to/nowhere! $temp_build_context"
    test_parse "$input" "$output" 0

    # invalid dockerfile and invalid build context
    input="build image mit-scheme /path/to/nowhere! /path/to/nowhere!"
    test_parse "$input" "$output" 0

    # invalid build context
    input="build image mit-scheme $temp_dockerfile /path/to/nowhere!"
    test_parse "$input" "$output" 0
}

test_parse_no_options() {
    local input=""
    local output="||||"

    test_parse "$input" "$output" 1
}

test_parse_help_option() {
    local input="-h"
    local output=":help||||"

    test_parse "$input" "$output" 1
}

test_parse_dry_run_option() {
    local input="-d"
    local output=":dry_run||||"

    test_parse "$input" "$output" 1
}

test_parse_help_and_dry_run_options() {
    local input="-h -d"
    local output=":help,:dry_run||||"

    test_parse "$input" "$output" 1

    input="-d -h"
    output=":dry_run,:help||||"

    test_parse "$input" "$output" 1
}

test_parse_duplicate_options() {
    local input="-d -d -h -h"
    local output=":dry_run,:help||||"

    test_parse "$input" "$output" 1

    input="-h -h -d -d"
    output=":help,:dry_run||||"

    test_parse "$input" "$output" 1
}

. ./shunit2

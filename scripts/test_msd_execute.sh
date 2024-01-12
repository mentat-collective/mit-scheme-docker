#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

suite() {
    local os=""

    os=$(host_os)

    echo "configuring tests for $os..."

    case "$os" in
        :linux)
            suite_addTest test_execute_operation_linux
            suite_addTest test_execute_dry_run_linux
            ;;
        :macos)
            suite_addTest test_execute_operation_macos
            suite_addTest test_execute_dry_run_macos
            ;;
    esac
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
    # uses realpath to resolve symbolic links that macos uses on mktemp
    temp_dockerfile=$(mktemp)
    temp_dockerfile=$(realpath "$temp_dockerfile")

    temp_build_context=$(mktemp -d)
    temp_build_context=$(realpath "$temp_build_context")

    temp_work_dir=$(mktemp -d)
    temp_work_dir=$(realpath "$temp_work_dir")
}

tearDown() {
    rm -rf "$temp_dockerfile" "$temp_build_context" "$temp_work_dir"
}

debug() {
    echo "INPUT: [$1] [$2]"
    echo "OUTPUT: $3"
    echo "RESULT: $4"
    tail "msd_dev_log.txt"
}

msd_execute_operation() {
    local op="$1"
    local ast="$2"
    local wait="$3"
    local -a cmd=()
    local pid=0
    local stat=0

    if [[ "$op" == "build" ]]; then
        read -r -a cmd <<< "$(docker_build_cmd "$ast")"
    elif [[ "$op" == "run" ]]; then
        read -r -a cmd <<< "$(docker_run_cmd "$ast")"
    fi

    TRACE "${cmd[*]}"

    "${cmd[@]}" &
    pid=$!

    stat=$(ps -p $pid -o stat | awk 'NR>1')

    # the docker process is indeed alive (running, sleeping, or idle)
    assertTrue  "[[ $stat =~ [R|S|I] ]]"

    if [[ "$wait" -eq 1 ]]; then
       wait "$pid"
       $_ASSERT_TRUE_ $?
    else
        echo "killing $pid"
        kill "$pid"
    fi
}

msd_execute() {
    local action="$1"
    local ast="$2"
    local output="$3"
    local valid="${4:-1}"
    local result=""
    local exit_code=0

    result=$(execute "$action" "$ast")
    exit_code="$?"

    if [[ "$valid" -eq 1 ]]; then
        $_ASSERT_TRUE_ "$exit_code"
        $_ASSERT_EQUALS_ '"$output"' '"$result"'
        if [[ "$exit_code" -ne 0 || "$output" != "$result" ]]; then
            debug "$action" "$ast ""$output" "$result"
        fi
    else
        $_ASSERT_FALSE_ "$exit_code"
        if [[ "$exit_code" -ne 1 ]]; then
            debug "$action" "$ast" "$output" "$result"
        fi
    fi
}

host_os() {
    local os=""

    os="$(uname -s)"

    case "$os" in
        Linux*)
            echo :linux
            return 0
            ;;
        Darwin*)
            echo :macos
            return 0
            ;;
        *)
            echo :unknown
            return 1
            ;;
    esac
}

test_execute_dry_run_macos() {
    local action=":dry_run"
    local ast="|build|image,mechanics,$temp_dockerfile,$temp_build_context||"
    local output="docker build --tag image --target mechanics --file $temp_dockerfile $temp_build_context"

    # dry run for mechanics build
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mit-scheme build
    action=":dry_run"
    ast="|build|image,mit-scheme,$temp_dockerfile,$temp_build_context||"
    output="docker build --tag image --target mit-scheme --file $temp_dockerfile $temp_build_context"
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mit-scheme build with docker options
    action=":dry_run"
    ast="|build|image,mit-scheme,$temp_dockerfile,$temp_build_context|--no-cache|"
    output="docker build --tag image --target mit-scheme --file $temp_dockerfile --no-cache $temp_build_context"
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mechanics run, no workdir specified
    action=":dry_run"
    ast="|run|image,mechanics||"
    output="docker run -e RUNTIME=mechanics --workdir $PWD -v $PWD:$PWD --ipc host --interactive --tty --rm -e DISPLAY=host.docker.internal:0 --platform linux/amd64 image"
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mechanics run, workdir specified
    action=":dry_run"
    ast="|run|image,mechanics,$temp_work_dir||"
    output="docker run -e RUNTIME=mechanics --workdir $temp_work_dir -v $temp_work_dir:$temp_work_dir --ipc host --interactive --tty --rm -e DISPLAY=host.docker.internal:0 --platform linux/amd64 image"
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mechanics run, no workdir specified, repl options
    action=":dry_run"
    ast="|run|image,mechanics,$temp_work_dir||--load,../resources/mechanics_spot_check.scm"
    output="docker run -e RUNTIME=mechanics --workdir $temp_work_dir -v $temp_work_dir:$temp_work_dir --ipc host --interactive --tty --rm -e DISPLAY=host.docker.internal:0 --platform linux/amd64 image -- --load ../resources/mechanics_spot_check.scm"
    msd_execute "$action" "$ast" "$output" 1
}

test_execute_dry_run_linux() {
    local action=":dry_run"
    local ast="|build|image,mechanics,$temp_dockerfile,$temp_build_context||"
    local output="docker build --tag image --target mechanics --file $temp_dockerfile $temp_build_context"

    # dry run for mechanics build
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mit-scheme build
    action=":dry_run"
    ast="|build|image,mit-scheme,$temp_dockerfile,$temp_build_context||"
    output="docker build --tag image --target mit-scheme --file $temp_dockerfile $temp_build_context"
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mit-scheme build with docker options
    action=":dry_run"
    ast="|build|image,mit-scheme,$temp_dockerfile,$temp_build_context|--no-cache|"
    output="docker build --tag image --target mit-scheme --file $temp_dockerfile --no-cache $temp_build_context"
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mechanics run, no workdir specified
    action=":dry_run"
    ast="|run|image,mechanics||"
    output="docker run -e RUNTIME=mechanics --workdir /home/eighty/code/github/eightysteele/mit-scheme-docker/scripts -v /home/eighty/code/github/eightysteele/mit-scheme-docker/scripts:/home/eighty/code/github/eightysteele/mit-scheme-docker/scripts --ipc host --interactive --tty --rm -e TERM=xterm-256color -e DISPLAY=:1 -v /tmp/.X11-unix:/tmp/.X11-unix image"
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mechanics run, workdir specified
    action=":dry_run"
    ast="|run|image,mechanics,../||"
    output="docker run -e RUNTIME=mechanics --workdir /home/eighty/code/github/eightysteele/mit-scheme-docker -v /home/eighty/code/github/eightysteele/mit-scheme-docker:/home/eighty/code/github/eightysteele/mit-scheme-docker --ipc host --interactive --tty --rm -e TERM=xterm-256color -e DISPLAY=:1 -v /tmp/.X11-unix:/tmp/.X11-unix image"
    msd_execute "$action" "$ast" "$output" 1

    # dry run for mechanics run, no workdir specified, repl options
    action=":dry_run"
    ast="|run|image,mechanics||--load,../resources/mechanics_spot_check.scm"
    output="docker run -e RUNTIME=mechanics --workdir /home/eighty/code/github/eightysteele/mit-scheme-docker/scripts -v /home/eighty/code/github/eightysteele/mit-scheme-docker/scripts:/home/eighty/code/github/eightysteele/mit-scheme-docker/scripts --ipc host --interactive --tty --rm -e TERM=xterm-256color -e DISPLAY=:1 -v /tmp/.X11-unix:/tmp/.X11-unix image -- --load ../resources/mechanics_spot_check.scm"
    msd_execute "$action" "$ast" "$output" 1
}

test_execute_operation_macos() {
    local dockerfile="../Dockerfile"
    local build_context="../"
    local ast=""

    # mechanics build without docker options
    ast="|build|msd:test-mechanics,mechanics,$dockerfile,$build_context||"
    msd_execute_operation "build" "$ast" 1

    # mit-scheme build without docker options
    ast="|build|msd:test-mit-scheme,mit-scheme,$dockerfile,$build_context||"
    msd_execute_operation "build" "$ast" 1

    # mit-scheme build with docker options
    ast="|build|msd:test-mit-scheme,mit-scheme,$dockerfile,$build_context|--quiet|"
    msd_execute_operation "build" "$ast" 1

    # the -d is for docker run to execute in detached mode...

    # mechanics run, no workdir specified
    ast="|run|msd:test-mit-scheme,mit-scheme|-d|"
    msd_execute_operation "run" "$ast" 0

    # run for mechanics run, workdir specified
    ast="|run|msd:test-mechanics,mechanics,$build_context|-d|"
    msd_execute_operation "run" "$ast" 0

    # mechanics run, no workdir specified, repl options
    ast="|run|msd:test-mechanics,mechanics|-d|--load,../resources/mechanics_spot_check.scm"
    msd_execute_operation "run" "$ast" 1
}

test_execute_operation_linux() {
    local dockerfile="../Dockerfile"
    local build_context="../"
    local ast=""

    # mechanics build without docker options
    ast="|build|msd:test-mechanics,mechanics,$dockerfile,$build_context||"
    msd_execute_operation "build" "$ast" 1

    # mit-scheme build without docker options
    ast="|build|msd:test-mit-scheme,mit-scheme,$dockerfile,$build_context||"
    msd_execute_operation "build" "$ast" 1

    # mit-scheme build with docker options
    ast="|build|msd:test-mit-scheme,mit-scheme,$dockerfile,$build_context|--quiet|"
    msd_execute_operation "build" "$ast" 1

    # the -d is for docker run to execute in detached mode...

    # mechanics run, no workdir specified
    ast="|run|msd:test-mit-scheme,mit-scheme|-d|"
    msd_execute_operation "run" "$ast" 0

    # run for mechanics run, workdir specified
    ast="|run|msd:test-mechanics,mechanics,$build_context|-d|"
    msd_execute_operation "run" "$ast" 0

    # mechanics run, no workdir specified, repl options
    ast="|run|msd:test-mechanics,mechanics|-d|--load,../resources/mechanics_spot_check.scm"
    msd_execute_operation "run" "$ast" 1
}

. ./shunit2

#!/usr/bin/env bash

# This script provides a very simple command-line interface for building and
# running Docker containers for MIT Scheme and Mechanics. It's configured to use
# the multi-stage Dockerfile with different stages (targets) for building
# dependencies and assembling runtimes. Essentially this script creates docker
# run and docker build commands under the hood with the right defaults baked in,
# and lets you pass through additional options to docker and the MIT Scheme
# REPL. It does a few other little things, like supporting dry runs, configuring
# x server for graphics, and modifying Docker commands to work consistently
# across Linux and macOS.
#
# Requirements:
#   - Docker 17.05 or greater.
#   - Bash 3.2.57 or greater.
#   - Linux or macOS.
#   - X11 for graphics support (optional)
#
# See usage for an example:
#   ./msd -h

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/b-log"

display_usage() {
    echo "Usage: ./msd [options] [action]"
    echo
    echo "Options:"
    echo "  -h: Display this help message"
    echo "  -d: Enable dry run mode"
    echo
    echo "Actions:"
    echo "  build <image> <runtime> <dockerfile> <build_context> -- [docker_options]"
    echo "  run <image> <runtime> [workdir] -- [docker_options] --- [repl_options]"
    echo
    echo "Example (build mechanics, do a dry run, then run it):"
    echo "  ./msd build mechanics:test mechanics Dockerfile ."
    echo "  ./msd -d run mechanics:test mechanics --- --load resources/mechanics_spot_check.scm"
    echo "  ./msd run mechanics:test mechanics --- --load resources/mechanics_spot_check.scm"
    echo
    echo "Note: docker_options and repl_options are passed directly to docker and REPL environments."
}

# Takes the user command line and parses it, then interprets it, then executes
# it. Displays some helpful messages to the user if there's an error.
entrypoint() {
    local ast=""
    local action=""

    start_logging "msd_dev_log.txt"

    if ! ast=$(parse "$@"); then
        echo "Error parsing the command line: $ast"
        exit 1
    fi

    if ! action=$(interpret "$ast"); then
        echo "Error interpreting the command line: $action"
        exit 1
    fi

    if ! execute "$action" "$ast"; then
        echo "Error executing the command."
        exit 1
    fi

    exit 0
}

# Takes a filename for the log and starts logging.
start_logging() {
    local filename="$1"
    LOG_LEVEL_TRACE "$0"
    B_LOG --file "$filename" --stdout "false"
}

# Takes command line arguments and parses the tokens into a serialized AST
# (calling it a "AST" here is perhaps a stretch since the underlying data
# structure is just a string, BUT, conceptually it's what we're after: this
# function returns an abstract representation of the command line that has been
# validated against a syntax but has no opinion about the meaning of the command
# itself).
#
# Usage:
#   parse "$@"
#
# Returns:
#   0 on success, echoes the serialized AST.
#   1 on validation error, echoes the error message.
parse() {
    local ast=""
    local opts=""
    local op=""
    local args=""
    local docker_opts=""
    local repl_opts=""
    local status=0
    local state=:START

    valid_operations=("build" "run")

    TRACE "$state"

    while [[ "$state" != :DONE ]]; do
        case "$state" in
            :START)
                if [[ "$#" -eq 0 ]]; then
                    state=:DONE
                else
                    state=:PARSE_OPTIONS
                fi
                TRACE "$state"
                ;;
            :PARSE_OPTIONS)
                opts=$(parse_options "$@")
                status=$?
                if [[ "$status" -eq 10 ]]; then
                    echo "Parsing error in options: $opts"
                    return 1
                else
                    shift "$status"
                    state=:OPTIONS_PARSED
                fi
                TRACE "$state"
                ;;
            :OPTIONS_PARSED)
                if [[ "$#" -eq 0 ]]; then
                    state=:DONE
                else
                    state=:PARSE_OP
                fi
                TRACE "$state"
                ;;
            :PARSE_OP)
                op="$1"
                if [[ ! "${valid_operations[*]}" =~ $op ]]; then
                    echo "Parsing error. Operation must be one of: ${valid_operations[*]}."
                    return 1
                else
                    shift
                    state=:OP_PARSED
                fi
                TRACE "$state"
                ;;
            :OP_PARSED)
                state=:PARSE_ARGS
                TRACE "$state"
                ;;
            :PARSE_ARGS)
                args=$(parse_args "$op" "$@")
                status=$?
                if [[ "$status" -eq 10 ]]; then
                    echo "Parsing error in args: $args"
                    return 1
                else
                    shift "$status"
                    state=:ARGS_PARSED
                fi
                TRACE "$state"
                ;;
            :ARGS_PARSED)
                if [[ "$1" == "--" ]]; then
                    shift
                    state=:PARSE_DOCKER_OPTS
                else
                    state=:DOCKER_OPTS_PARSED
                fi
                ;;
            :PARSE_DOCKER_OPTS)
                docker_opts=$(parse_passthrough_options "$@")
                status=$?
                if [[ "$status" -eq 10 ]]; then
                    echo "Parsing error in Docker options."
                    return 1
                fi
                shift "$status"
                state=:DOCKER_OPTS_PARSED
                TRACE "$state"
                ;;
            :DOCKER_OPTS_PARSED)
                if [[ "$1" == "---" ]]; then
                    shift
                    state=:PARSE_REPL_OPTS
                else
                    state=:DONE
                fi
                TRACE "$state"
                ;;
            :PARSE_REPL_OPTS)
                repl_opts=$(parse_passthrough_options "$@")
                status=$?
                if [[ "$status" -eq 10 ]]; then
                    echo "Parsing error in REPL options."
                    return 1
                fi
                state=:DONE
                TRACE "$state"
                ;;
        esac
    done

    ast=$(serialize "$opts" "$op" "$args" "$docker_opts" "$repl_opts")

    echo "$ast"
    return 0
}

# Serializes the AST.
#
# Usage:
#   serialize "opt1 opt2" "operation" "arg1 arg2" "docker1 docker2" "repl1 repl2"
#   -> "opt1,opt2|operation|arg1,arg2|docker1,docker2|repl1,repl2"
#
# Returns:
#   0 on success, echoes the serialized AST string.
#   1 on input error, echoes the error message.
serialize() {
    if [[ $# -lt 5 ]]; then
        echo "Error: Missing arguments. Five arguments are required."
        return 1
    fi

    local options_str="${1// /,}"
    local operation_str="$2"
    local args_str="${3// /,}"
    local docker_options_str="${4// /,}"
    local repl_options_str="${5// /,}"

    local -a ast=(
        "$options_str"
        "$operation_str"
        "$args_str"
        "$docker_options_str"
        "$repl_options_str"
    )

    IFS="|"; echo "${ast[*]}"
    return 0
}

# Takes a serialized AST and deserializes it.
#
# Usage:
#   deserialize "opt1,opt2|operation|arg1,arg2|docker1,docker2|repl1,repl2"
#   -> "opt1 opt2|operation|arg1 arg2|docker1 docker2|repl1 repl2"
#
# Returns:
#   0 on success, echoes the deserialized AST string.
#   1 on input error, echoes the error message.
#
deserialize() {
    local serialized="$1"

    if [[ -z "$serialized" ]]; then
        echo "Error: Input is empty."
        return 1
    fi

    local -a temp=()
    local -a ast=()

    IFS='|' read -r -a temp <<< "$serialized"

    for x in "${temp[@]}"; do
        ast+=("${x//,/ }")
    done

    IFS="|"; echo "${ast[*]}"
    return 0
}

# Takes a serialized AST and gets the values for the supplied token group name.
#
# Usage:
#   get "opt1,opt2|operation|arg1,arg2|docker1,docker2|repl1,repl2" ":operation"
#   -> "operation"
#
# Returns:
#   0 on success, echoes the values as a space separated string.
#   1 on error, echoes error message.
get() {
    local serialized="$1"
    local name="$2"

    if [[ -z "$serialized" ]]; then
        echo "Error: serialized required."
        return 1
    fi

    if [[ -z "$name" ]]; then
        echo "Error: name required."
        return 1
    fi

    local index=0
    local deserialized=""
    local -a ast=()

    deserialized=$(deserialize "$serialized")

    IFS='|' read -r -a ast <<< "${deserialized}"

    case "$name" in
        :options)
            index=0
            ;;
        :operation)
            index=1
            ;;
        :args)
            index=2
            ;;
        :docker_options)
            index=3
            ;;
        :repl_options)
            index=4
            ;;
        *)
            echo "didn't recognize the token group: $name"
            return 1
            ;;
    esac

    echo "${ast[$index]}"

    return 0
}

# Takes command line arguments and parses any supplied options.
#
# Usage:
#   parse_options "$@"
#
# Returns:
#   Number of options parsed on success, echoes options as a space separated string.
#   10 on error, echoes the error message.
parse_options() {
    local -a options=()
    local help_flag=false
    local dry_run_flag=false

    if [ $# -eq 0 ]; then
        echo "Error: No options provided."
        return 1
    fi

    while getopts ":hd" opt; do
        case $opt in
            h)
                if [[ "$help_flag" != "true" ]]; then
                   options+=(":help")
                   help_flag="true"
                fi
                ;;
            d)
                if [[ "$dry_run_flag" != "true" ]]; then
                    options+=(":dry_run")
                    dry_run_flag="true"
                fi
                ;;

            \?)
                echo "invalid option -$OPTARG"
                return 10
                ;;
        esac
    done

    echo "${options[*]}"
    return $((OPTIND - 1))
}

# Takes command line arguments and parses them based on supplied operation.
#
# Usage:
#   parse_args "operation" "$@"
#
# Returns:
#   Count of parsed arguments on success, echoes arguments as space separated string.
#   10 on error, echoes the error message.
parse_args() {
    local op="$1"
    shift

    if [[ -z "$op" ]]; then
        echo "Error: operation required."
        return 1
    fi

    local -a valid_operations=("build" "run")
    if [[ ! "${valid_operations[*]}" =~ $op ]]; then
        echo "Error: Invalid operation $op"
        return 10
    fi

    local -a args=()
    local ouput=""

    if ! ouput=$(validate_required_image "$1"); then
        echo "$ouput"
        return 10
    fi
    args+=("$1")

    if ! ouput=$(validate_required_runtime "$2"); then
        echo "$ouput"
        return 10
    fi
    args+=("$2")

    case "$op" in
        build)
            if ! ouput=$(validate_required_dockerfile "$3"); then
                echo "$ouput"
                return 10
            fi
            args+=("$3")

            if ! ouput=$(validate_required_build_context "$4"); then
                echo "$ouput"
                return 10
            fi
            args+=("$4")
            ;;
        run)
            if ouput=$(validate_optional_workdir "$3"); then
                args+=("$3")
            fi
            ;;
    esac

    echo "${args[*]}"
    return "${#args[@]}"
}

# Returns 1 if image is valid, otherwise 1.
validate_required_image() {
    local image="$1"
    if [[ -z "$image" ]]; then
        echo "Error: The 'image' argument is required."
        return 1
    fi
    return 0
}

# Returns 1 if runtime is valid, otherwise 1.
validate_required_runtime() {
    local runtime="$1"
    if [[ "$runtime" != "mit-scheme" && "$runtime" != "mechanics" ]]; then
        echo "Error: The 'runtime' argument is required ('mit-scheme' or 'mechanics')."
        return 1
    fi
    return 0
}

# Returns 1 if dockerfile exists and is readable, otherwise 1.
validate_required_dockerfile() {
    local dockerfile="$1"
    if ! check_file_readable "$dockerfile"; then
        echo "Error: Dockerfile '$dockerfile' doesn't exist or isn't readable."
        return 1
    fi
    return 0
}

# Returns 1 if build context directory exists and is readable, otherwise 1.
validate_required_build_context() {
    local context="$1"
    if ! check_dir_readable "$context"; then
        echo "Error: Build context directory '$context' doesn't exist or isn't readable."
        return 1
    fi
    return 0
}

# Returns 1 if workdir exists and is readable, otherwise 1.
validate_optional_workdir() {
    local workdir="$1"
    if [[ -n "$workdir" && "$workdir" != "--" && "$workdir" != "---" ]]; then
        if ! check_dir_readable "$workdir"; then
            return 1
        else
            return 0
        fi
    else
        return 1
    fi
}

# Returns 1 if file exists and is readable, otherwise 1.
check_file_readable() {
    local file="$1"
    if [[ -z "$file" || ! -f "$file" || ! -r "$file" ]]; then
        echo "File '$file' doesn't exist or isn't readable."
        return 1
    fi
    return 0
}

# Returns 1 if directory exists and is readable, otherwise 1.
check_dir_readable() {
    local dir="$1"
    if [[ -z "$dir" || ! -d "$dir" || ! -r "$dir" ]]; then
        echo "Directory '$dir' doesn't exist or isn't readable."
        return 1
    fi
    return 0
}

# Takes command line arguments and parses any passthrough options for docker or
# the repl.
#
# Usage:
#   parse_passthrough_options "$@"
#
# Returns:
#   Number of tokens parsed on success, echoes options as a string.
#   0 on input error, echoes error message.
parse_passthrough_options() {
    if [ $# -eq 0 ]; then
        echo ""
        return 0
    fi

    local token=""
    local -a tokens=()

    while [[ $# -gt 0 ]]; do
        token="$1"
        if [[ "$token" != "---" ]]; then
            tokens+=("$token")
            shift
        else
            break
        fi
    done

    echo "${tokens[*]}"
    return "${#tokens[@]}"
}

# Interprets a serialized AST to determine what it means and the action to take.
#
# Usage:
#   interpret "$ast"
#
# Returns:
#   0 on success, echoes the action to take.
#   1 on error, echoes error message.
interpret() {
    local ast="$1"

    if [[ -z "$ast" ]]; then
        echo "Error: AST is required."
        return 1
    fi

    local action=""
    local options=()
    local operation=""

    if ! IFS=' ' read -r -a options <<< "$(get "$ast" :options)"; then
        echo "Error reading options from serialized AST: $ast"
        return 1
    fi

    if ! operation=$(get "$ast" :operation); then
       echo "Error reading operation from serialized AST: $ast"
       return 1
    fi

    if [[ "${#options[@]}" -eq 0 && -z "$operation" ]];then
        echo :help
        return 0
    fi

    for option in "${options[@]}"; do
        case "$option" in
            :help)
                echo :help
                return 0
                ;;
            :dry_run)
                action=:dry_run
                ;;
        esac
    done

    if [[ -n "$action" ]]; then
        echo "$action"
        return 0
    fi

    action=:operation

    echo "${action}"
    return 0
}

# Executes the supplied interpreted action.
#
# Usage:
#  execute "$action" "$ast"
#
# Returns:
#  0 on success.
#  1 on error, echoes error message.
execute() {
    local action="$1"
    local ast="$2"

    if [[ -z "$action" ]]; then
        echo "Error: action required."
        return 1
    fi

    if [[ -z "$ast" ]]; then
        echo "Error: AST required."
        return 1
    fi

    local operation=""

    operation=$(get "$ast" :operation)

    case "$action" in
        :help)
            display_usage "$operation"
            ;;
        :dry_run)
            if ! dry_run "$operation" "$ast"; then
                echo "Error executing dry run."
                return 1
            fi
            ;;
        :operation)
            if ! implement "$operation" "$ast"; then
                echo "Error implementing command: $operation $ast"
                return 1
            fi
            return 0
            ;;
    esac
}

# Constructs and echoes a command string based on the given operation and AST.
#
# Usage:
#   dry_run "operation" "AST"
#
# Returns:
#   0 on success, echoes the command string.
#   1 on error, echoes error message. 
dry_run() {
    local operation="$1"
    local ast="$2"

    if [[ -z "$operation" ]]; then
        echo "Error: operation required."
        return 1
    fi

    if [[ -z "$ast" ]]; then
        echo "Error: AST required."
        return 1
    fi

    local cmd=()

    case "$operation" in
        build)
            if ! read -r -a cmd <<< "$(docker_build_cmd "$ast")"; then
                echo "Error: Unable to create a dry run for docker build"
                return 1
            fi
            ;;
        run)
            if ! read -r -a cmd <<< "$(docker_run_cmd "$ast")"; then
                echo "Error: Unable to create a dry run for docker run"
                return 1
            fi
            ;;
    esac

    echo "${cmd[*]}"
    return 0
}

# Implements the supplied operation by executing it.
#
# Usage:
#   implement "operation" "AST"
#
# Returns:
#   0 on success, echoes status messaage.
#   1 on error, echoes error message. 
implement() {
    local operation="$1"
    local ast="$2"

    if [[ -z "$operation" ]]; then
        echo "Error: operation required."
        return 1
    fi

    if [[ -z "$ast" ]]; then
        echo "Error: AST required."
        return 1
    fi

    local os=""
    local cmd=()

    if ! os=$(host_os); then
        echo "Error: Couldn't determine the host operating system."
        return 1;
    fi

    case "$operation" in
        build)
            if ! read -r -a cmd <<< "$(docker_build_cmd "$ast")"; then
                echo "Error: Couldn't construct the docker build command."
                return 1
            fi

            local stdout_file=""
            stdout_file=$(mktemp)

            # Executes the command
            if ! "${cmd[@]}" | tee "$stdout_file"; then
                error=$(tail -n 1 "$stdout_file")
                echo "Error executing command: ${cmd[*]} $error"
                return 1
            fi

            rm "$stdout_file"
            ;;
        run)
            if ! read -r -a cmd <<< "$(docker_run_cmd "$ast")"; then
                error "Error: Couldn't construct the docker run command."
                return
            fi

            if ! host_x_installed "$os" || ! host_config_x "$os"; then
                echo "x server not available (graphics disabled)"
            else
                echo "x server ready (graphics enabled)"
            fi

            # Executes the command
            if ! "${cmd[@]}"; then
                echo "Error executing command: ${cmd[*]}"
            fi

            if ! host_restore_x "$os"; then
                echo "x server not restored (connection to container still open)"
            else
                echo "x server restored (connection to container closed)"
            fi
            ;;
    esac

    return 0
}

# Takes an AST and returns a docker build command.
#
# Usage:
#  docker_build_cmd "$ast"
#
# Returns:
#  0 on success, echoes the command.
#  1 on error, echoes error message.
docker_build_cmd() {
    local ast="$1"

    if [[ -z "$ast" ]]; then
        echo "Error: AST required."
        return 1
    fi

    local image=""
    local runtime=""
    local dockerfile=""
    local build_context=""
    local docker_options=""
    local -a args=()
    local -a cmd=()

    if ! IFS=' ' read -r -a args <<< "$(get "$ast" :args)"; then
        echo "Error: Couldn't read arguments from AST: $ast"
        return 1
    fi

    image="${args[0]}"
    runtime="${args[1]}"
    dockerfile="${args[2]}"
    build_context="${args[3]}"

    if ! docker_options=$(get "$ast" :docker_options); then
        echo "Error: Couldn't read docker options from AST: $ast"
        return 1
    fi

    cmd=(
        docker build
        --tag "$image"
        --target "$runtime"
        --file "$dockerfile"
        "$docker_options"
        "$build_context"
    )

    echo "${cmd[@]}"
    return 0
}

# Takes an AST and returns a docker run command for linux or macos, depending on
# the host.
#
# Usage:
#  docker_build_cmd "$ast"
#
# Returns:
#  0 on success, echoes the command.
#  1 on error, echoes error message.
docker_run_cmd() {
    local ast="$1"

    if [[ -z "$ast" ]]; then
        echo "Error: AST required."
        return 1
    fi

    local image=""
    local runtime=""
    local workdir=""
    local docker_options=""
    local repl_options=""
    local os=""
    local -a args=()
    local -a cmd=()

    if ! IFS=' ' read -r -a args <<< "$(get "$ast" :args)"; then
        echo "Error: Couldn't read arguments from AST: $ast"
        return 1
    fi

    image="${args[0]}"
    runtime="${args[1]}"
    workdir="${args[2]}"

    if [[ -z "$workdir" ]]; then
        workdir=$PWD
    else
        if ! workdir=$(absolute_path "$workdir"); then
            echo "Error: Couldn't get absolute path for $workdir"
            return 1
        fi
    fi

    if ! docker_options=$(get "$ast" :docker_options); then
        echo "Error: Couldn't read docker options from AST: $ast"
        return 1
    fi

    if ! repl_options=$(get "$ast" :repl_options); then
        echo "Error: Couldn't read repl options from AST: $ast"
        return 1
    fi

    cmd=(
        docker run
        -e RUNTIME="$runtime"
        --workdir "$workdir"
        -v "${workdir}:${workdir}"
        --ipc host
        --interactive
        --tty
        --rm
    )

    if ! os=$(host_os); then
        echo "Error: Unable to get host OS: $os"
        return 1
    fi

    case "$os" in
        :linux)
            cmd+=(
                -e TERM="$TERM"
                -e DISPLAY="$DISPLAY"
                -v /tmp/.X11-unix:/tmp/.X11-unix
            )
            ;;
        :macos)
            cmd+=(-e DISPLAY="host.docker.internal:0")
            ;;
    esac

    if [[ "$runtime" == "mechanics" ]] && host_is_arm64 "$(host_architecture)"; then
        cmd+=(
            --platform
            "linux/amd64"
        )
    fi

    cmd+=(
        "$docker_options"
        "$image"
    )

    if [[ -n "$repl_options" ]]; then
        cmd+=(
            "--"
            "$repl_options"
        )
    fi

    echo "${cmd[@]}"
    return 0
}

# Echoes the host OS. Returns 0 on success, 1 on error.
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

# Echoes back the host architecture. Returns 0 on success, 1 on error.
host_architecture() {
    local arch=""

    arch=$(uname -m)

    case "$arch" in
        x86_64)
            echo :amd64
            ;;
        arm64)
            echo :arm64
            ;;
        *)
            echo :unknown
            return 1
            ;;
    esac

    return 0
}

# Returns 0 if the host is arm64, otherwise 1.
host_is_arm64() {
    local arch="$1"

    [[ "$arch" == :arm64 ]]
}

# Configures host x server to listen to local containers. Returns 0 on success,
# 1 on error.
host_config_x() {
    os="$1"

    case "$os" in
        :linux)
            if xhost +local:docker >& /dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        :macos)
            if xhost + 127.0.0.1 >& /dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Restores host x server configuration. Returns 0 on success, 1 on error.
host_restore_x() {
    os="$1"

    case "$os" in
        :linux)
            if xhost -local:docker >& /dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        :macos)
            if xhost - 127.0.0.1 >& /dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            return 1;
            ;;
    esac
}

# Returns 0 if xhost installed, otherwise 1.
host_x_installed() {
    local os="$1"

    case "$os" in
        :linux)
            if command -v xhost &> /dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        :macos)
            if xhost >& /dev/null; then
                return 0
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Echoes the absolute path of supplied path. Returns 0 on success, 1 on error.
absolute_path() {
    local path="$1"
    local absolute_path=""

    if ! absolute_path=$(realpath "$path" 2>/dev/null); then
        return 1
    fi

    echo "$absolute_path"
    return 0
}

# Bypasses entrypoint if testing.
if [[ $MSD_TEST_MODE -eq 1 ]]; then
   echo "entering test mode..."
   start_logging "msd_dev_log.txt"
else
   entrypoint "$@"
fi

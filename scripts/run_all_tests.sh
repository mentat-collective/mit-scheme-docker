#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR" || exit 1

for file in test_*; do
    if [ -f "$file" ]; then
        echo "Running test $file..."
        ./"$file"
    fi
done

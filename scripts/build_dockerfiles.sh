#!/bin/bash

# Error out if any of the commands fail.
set -e

docker build -t sritchie/mit-scheme:latest mit-scheme
docker push sritchie/mit-scheme:latest

# docker run --ipc host -it --rm sritchie/mit-scheme

docker build -t sritchie/mechanics:latest mechanics
docker push sritchie/mechanics:latest

# docker run --ipc host -it --rm sritchie/mechanics

# docker build --target mechanics-jupyter -t sritchie/mechanics-jupyter:latest .
# docker push sritchie/mechanics-jupyter:latest

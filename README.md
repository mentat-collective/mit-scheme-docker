## Docker + MIT Scheme and SCMUtils

[MIT/GNU Scheme](https://www.gnu.org/software/mit-scheme/), and the amazing
[SCMUtils](https://groups.csail.mit.edu/mac/users/gjs/6946/refman.txt),
containerized for your pleasure!

<p align="center">
  <img src="https://user-images.githubusercontent.com/69635/82737854-05686300-9cf1-11ea-87e0-f9711842e5a2.png" alt="MIT Scheme" width="150" height="150" />
</p>

This repository contains a Dockerfile and command-line utility (see `./msd
-h`) for building and executing `mit-scheme` and `mechanics`. Both of these
images are important for interacting with the textbooks "Structure and
Interpretation of Computer Programs" and "Structure and Interpretation of
Classical Mechanics", by Sussman and Wisdom.

For a project that uses these Docker images heavily for Scheme development, see
my [SICM Exercises Repository](https://github.com/sritchie/sicm).

## MIT-Scheme

[![Docker Stars](https://img.shields.io/docker/stars/sritchie/mit-scheme.svg)][hub]
[![Docker Pulls](https://img.shields.io/docker/pulls/sritchie/mit-scheme.svg)][hub]

[hub]: https://hub.docker.com/r/sritchie/mit-scheme/

The Dockerfile builds a container capable of executing an [MIT/GNU Scheme
REPL](https://www.gnu.org/software/mit-scheme/), version 12.1.

### Building and running mit-scheme

You can build and run mit-scheme using the `msd` utility. If you prefer using
docker directly, use the `-d` flag and copy the command. Running the image
launches the `mit-scheme` REPL, assisted by
[rlwrap](https://github.com/hanslub42/rlwrap) for nice tab completions and
command history in the REPL.

```bash
# Build
./msd build mit-scheme:local mit-scheme Dockerfile .

# Run
./msd run mit-scheme:local mit-scheme
```

## Mechanics / SCMUtils

[![Docker Stars](https://img.shields.io/docker/stars/sritchie/mechanics.svg)][hub]
[![Docker Pulls](https://img.shields.io/docker/pulls/sritchie/mechanics.svg)][hub]

[hub]: https://hub.docker.com/r/sritchie/mechanics/

The Dockerfile builds a container capable of executing the `mechanics` (also
called `scmutils`) library (version 20230902) that Wisdom and Sussman use in
their course at MIT: [Classical Mechanics: A Computational
Approach](http://groups.csail.mit.edu/mac/users/gjs/6946/index.html). This
Docker image lets you skip the [installation
instructions](http://groups.csail.mit.edu/mac/users/gjs/6946/installation.html)
at the course page.

You'll need this code to complete the exercises in their textbook, [The
Structure and Interpretation of Classical Mechanics](https://amzn.to/2LUx62M).
The book is also available online in beautiful [HTML
format](https://tgvaughan.github.io/sicm/).

### Building and running mechanics / scmutils

You can build and run mechanics using the `msd` utility. If you prefer using
docker directly, use the `-d` flag and copy the command. Running the image
launches the `mit-scheme` REPL with the `scmutils` library loaded up, assisted
by [rlwrap](https://github.com/hanslub42/rlwrap) for nice tab completions and
command history in the REPL.

```bash
# Build
./msd build mechanics:local mechanics ./Dockerfile .

# Run
./msd run mechanics:local mechanics
```

### SICM exercise repository

For a project that uses these Docker images heavily for Scheme development, see
my [SICM Exercises Repository](https://github.com/sritchie/sicm). That
repository makes extensive use of this Docker image; if you're looking to get
started learning `SCMUtils`, you should head over to the
[README](https://github.com/sritchie/sicm) and poke around.


## Notes on graphic support and X11

The `msd` command line utility automatically detects your host OS and configures
X11 to accept local connections for graphics output. It also restores those
connections when you quit the REPL.

Small caveat: While the `mit-scheme` Docker image is compiled with X11 support,
I have NOT been able to figure out how to get any graphics running from the
mit-scheme image itself (it works with `mechanics`, see below). All to say, please
let me know if you find a great way to run X11 examples from this repository
with the `mit-scheme` runtime!

### Installing and configuring X11

X11 can be installed on Linux in the usual ways (e.g., `sudo apt install xorg`
on Ubuntu). On macOS, you need to install the latest version of
[XQuartz](https://www.xquartz.org/). 

Once you have XQuartz installed, there's a bit of setup required to make sure it
has the permissions needed to authenticate local connections to containers:

- launch it from `/Applications/Utilities/Xquartz`,
- go into the Preferences menu and navigate to the Security tab,
- make sure that both "Authenticate Connections" and "Allow connections from
  network clients" is checked,
- and in system settings, make sure it's added to the list of startup items.

### Spot check!

For a proper test that X11 is working as expected:

```bash
# Build mechanics
./msd build mechanics:local mechanics ./Dockerfile .

# Run mechanics
./msd run mechanics:local mechanics --- --load resources/mechanics_spot_check.scm
```

The `run` command above passes through the `--load` option to the REPL with a
scheme file that tests X11 on your host. You should see a beautiful latex
equation alongisde a black window pop up, demonstrating that, miraculously,
`mechanics` can reach *outside of Docker* and manipulate its host!

## License

Copyright 2024, Sam Ritchie.

Licensed under the [Apache License, Version
2.0](http://www.apache.org/licenses/LICENSE-2.0).

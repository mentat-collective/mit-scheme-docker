# MIT-Scheme

[![Docker Stars](https://img.shields.io/docker/stars/sritchie/mit-scheme.svg)][hub]
[![Docker Pulls](https://img.shields.io/docker/pulls/sritchie/mit-scheme.svg)][hub]

[hub]: https://hub.docker.com/r/sritchie/mit-scheme/

This Dockerfile builds a container capable of executing an [MIT/GNU Scheme
REPL](https://www.gnu.org/software/mit-scheme/), version 10.1.10.

## Running mit-scheme

The docker image launches an mit-scheme REPL, assisted by
[rlwrap](https://github.com/hanslub42/rlwrap). `rlwrap` gives you nice tab
completion in the REPL, and the ability to scroll backward and forward in your
REPL with the up and down arrows.

The command `docker run -it --rm sritchie/mechanics` is the simplest way to get
started:

```bash
$ docker run -it --rm sritchie/mechanics
MIT/GNU Scheme running under GNU/Linux
Type `^C' (control-C) followed by `H' to obtain information about interrupts.

Copyright (C) 2019 Massachusetts Institute of Technology
This is free software; see the source for copying conditions. There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Image saved on Friday August 30, 2019 at 11:20:36 PM
  Release 10.1.10 || Microcode 15.3 || Runtime 15.7 || SF 4.41 || LIAR/x86-64 4.118 || SOS 1.8 || XML 1.0 || Edwin 3.117 || X11 1.3 || X11-Screen 1.0 || ScmUtils Mechanics.Summer 2019

1 ]=> (write-string "Hello, World!")
Hello, World!
;No return value.

1 ]=>
```

## CLI Script

If you'd like a more involved wrapper script, create a file in some directory on
your path - `~/bin/mit-scheme`, for example - and add this to the file:

```bash
#!/bin/bash

if xhost >& /dev/null ; then
  # NOTE - On OS X, you have to have enabled network connections in XQuartz!
  xhost + 127.0.0.1
fi

workdir="$PWD"

docker run \
       --ipc host \
       --interactive --tty --rm \
       --workdir $workdir \
       --volume $workdir:$workdir \
       -e DISPLAY=host.docker.internal:0 \
       sritchie/mit-scheme "$@"
```

Then run `chmod +x ~/bin/mit-scheme` to make it executable.

This more involved wrapper script will:

- Run the Docker container with the ability to send graphics and rendered LaTeX
  out to an X11 server running on your host machine
- Mount the directory where you run the script into the container, so you can
  access and load files from the repl. The directory has the same name as the
  directory where you run the command, so that absolute paths you specify inside
  that directory will resolve correctly inside the container.
- Give the Docker process running `mit-scheme` access to all of the memory on
  your machine

## X11 on Mac

CAVEAT: This MIT scheme was built with X11 support, but I have NOT been able to
figure out how to get any x11 thing running from the default mit-scheme. I'm
including these instructions here since they're necessary, but perhaps not
sufficient. Please let me know if you find a great way to run an X11 example
from this repository!

If you want to take advantage of the X11 forwarding, you'll need to have an X11
server running. On a mac, this means installing the latest version of
[XQuartz](https://www.xquartz.org/).

Once you have XQuartz installed,

- launch it from `/Applications/Utilities/Xquartz`,
- go into the Preferences menu and navigate to the Security tab
- make sure that both "Authenticate Connections" and "Allow connections from
  network clients" is checked

For a proper test, please visit the
[`mechanics`](https://github.com/sritchie/mit-scheme-docker/tree/master/mechanics)
Docker image page, which is based off of this `mit-scheme` image, but actually
works out of the box with X11. That page has a command you can run to generate
LaTeX and test the integration.

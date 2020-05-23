# Mechanics / SCMUtils

[![Docker Stars](https://img.shields.io/docker/stars/sritchie/mechanics.svg)][hub]
[![Docker Pulls](https://img.shields.io/docker/pulls/sritchie/mechanics.svg)][hub]

[hub]: https://hub.docker.com/r/sritchie/mechanics/

This Dockerfile builds a container capable of executing the `mechanics` (also
called `scmutils`) library that Wisdom and Sussman use in their course at MIT:
[Classical Mechanics: A Computational
Approach](http://groups.csail.mit.edu/mac/users/gjs/6946/index.html). This
Docker image lets you skip the [installation
instructions](http://groups.csail.mit.edu/mac/users/gjs/6946/installation.html)
at the course page.

You'll need this code to complete the exercises in their textbook, [The
Structure and Interpretation of Classical Mechanics](https://amzn.to/2LUx62M).
The book is also available online in beautiful [HTML
format](https://tgvaughan.github.io/sicm/).

## Running mechanics / scmutils

The docker image launches an mit-scheme REPL with the `scmutils` library loaded
up. The image also uses [rlwrap](https://github.com/hanslub42/rlwrap), which
gives you nice tab completion in the REPL, and the ability to scroll backward
and forward in your REPL with the up and down arrows.

This command is the simplest way to get started interacting with the REPL:

```bash
docker run -it --rm sritchie/mechanics
```

## CLI Script

If you'd like a more involved wrapper script, create a file in some directory on
your path - `~/bin/mechanics`, for example - and add this to the file:

```bash
#!/bin/bash

# NOTE - you have to have enabled network connections in XQuartz!
xhost + 127.0.0.1

workdir=/usr/app

docker run \
       --ipc host \
       --interactive --tty --rm \
       --workdir $workdir \
       --volume "$PWD":$workdir \
       -e DISPLAY=host.docker.internal:0 \
       sritchie/mechanics
```

Then run `chmod +x ~/bin/mechanics` to make it executable.

This more involved wrapper script will:

- Run the Docker container with the ability to send graphics and rendered LaTeX
  out to an X11 server running on your host machine
- Mount the directory where you run the script into the container, so you can
  access and load files from the repl
- Give the Docker process running `mechanics` access to all of the memory on
  your machine

## X11 on Mac

If you want to take advantage of the X11 forwarding, you'll need to have an X11
server running. On a mac, this means installing the latest version of
[XQuartz](https://www.xquartz.org/).

Once you have XQuartz installed,

- launch it from `/Applications/Utilities/Xquartz`,
- go into the Preferences menu and navigate to the Security tab
- make sure that both "Authenticate Connections" and "Allow connections from
  network clients" is checked

To test it out, run the `mechanics` script you created earlier, and try entering
an expression like `(show-expression (+ 'alpha 't))` at the REPL.

```
$ mechanics
127.0.0.1 being added to access control list
MIT/GNU Scheme running under GNU/Linux
Type `^C' (control-C) followed by `H' to obtain information about interrupts.

Copyright (C) 2019 Massachusetts Institute of Technology
This is free software; see the source for copying conditions. There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Image saved on Friday August 30, 2019 at 11:20:36 PM
  Release 10.1.10 || Microcode 15.3 || Runtime 15.7 || SF 4.41 || LIAR/x86-64 4.118 || SOS 1.8 || XML 1.0 || Edwin 3.117 || X11 1.3 || X11-Screen 1.0 || ScmUtils Mechanics.Summer 2019

1 ]=> (show-expression (+ 'alpha 't))
(+ alpha t)
```

You should see a window pop up with a nicely rendered LaTeX expression.

## Notes

This image is based off of my
[mit-scheme](https://hub.docker.com/repository/docker/sritchie/mit-scheme)
image. The README and Dockerfile for that image live
[here](https://github.com/sritchie/mit-scheme-docker/tree/master/mit-scheme).

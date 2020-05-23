## Docker + MIT Scheme and SCMUtils

[MIT/GNU Scheme](https://www.gnu.org/software/mit-scheme/), and the amazing
[SCMUtils](https://groups.csail.mit.edu/mac/users/gjs/6946/refman.txt),
containerized for your pleasure!

<p align="center">
  <img src="https://user-images.githubusercontent.com/69635/82737854-05686300-9cf1-11ea-87e0-f9711842e5a2.png" alt="MIT Scheme" width="250" height="250" />
</p>

This repository contains Dockerfiles for:

- [`mit-scheme`](https://github.com/sritchie/mit-scheme-docker/tree/master/mit-scheme)
  (available on
  [Dockerhub](https://hub.docker.com/repository/docker/sritchie/mit-scheme))
- [`mechanics`](https://github.com/sritchie/mit-scheme-docker/tree/master/mechanics),
  also known as "SCMUtils" (available on
  [Dockerhub](https://hub.docker.com/repository/docker/sritchie/mechanics))

Both of these images are important for interacting with the textbooks "Structure
and Interpretation of Computer Programs" and "Structure and Interpretation of
Classical Mechanics", by Sussman and Wisdom.

For a project that uses these Docker images heavily for Scheme development, see
my [SICM Exercises Repository](https://github.com/sritchie/sicm).

The subfolders linked above have instructions that show you how to interact with
the commands that these images provide.

## License

Copyright 2020, Sam Ritchie.

Licensed under the [Apache License, Version
2.0](http://www.apache.org/licenses/LICENSE-2.0).

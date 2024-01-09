# This Dockerfile builds the `mit-scheme` and the `mechanics` runtime images
# using a multi-stage build.
#
# Build Arguments (using 'docker build --build-arg'):
#   - MITSCHEME_VERSION: MIT Scheme version (default 12.1).
#   - SCMUTILS_VERSION: Scmutils version (default 20230902).
#
# Usage:
#   docker build -f Dockerfile -t msd/mechanics:dev --target=mechanics .
#   docker build -f Dockerfile -t msd/mit-scheme:dev --target=mit-scheme .


# Builds the base image. Platform flag rationale: by default, the latest
# versions of MIT Scheme won't compile on Apple's M1 architecture because of the
# 'write xor execute' restriction (essentially this disables a process from
# writing and executing to the same memory region). You can force macos to
# compile MIT Scheme under Rosetta 2 with the 'arch -x86_64' command, but you
# can't combine that with a Docker build command! So we set the platform
# explicitly to ensure the image builds on macos (note: mit-scheme is a native
# compile which is obviously cpu-bound, and will be a bit slower on macos
# because of emulation).
#
FROM --platform=linux/amd64 ubuntu:latest AS build-init

LABEL authors="Sam Ritchie <sritchie09@gmail.com>, Aaron Steele <eightysteele@gmail.com>"
LABEL github="https://github.com/mentat-collective/mit-scheme-docker"

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libncurses-dev \
    libx11-dev \
    m4 \
    rlwrap

WORKDIR /
RUN rm -rf /var/lib/apt/lists/*

# Downloads, compiles, installs MIT Scheme from source. You can target this
# stage during a build using '--target build-scheme'.
FROM build-init AS build-scheme

ARG MITSCHEME_VERSION=12.1

ARG MITSCHEME_DIR=mit-scheme-${MITSCHEME_VERSION}
ARG MITSCHEME_TAR=${MITSCHEME_DIR}-x86-64.tar.gz
ARG MITSCHEME_URL=http://ftp.gnu.org/gnu/mit-scheme/stable.pkg/${MITSCHEME_VERSION}/${MITSCHEME_TAR}
ARG MITSCHEME_MD5_URL=http://ftp.gnu.org/gnu/mit-scheme/stable.pkg/${MITSCHEME_VERSION}/md5sums.txt

WORKDIR /
RUN curl -Lk ${MITSCHEME_URL} -o ${MITSCHEME_TAR} \
    && curl -Lk ${MITSCHEME_MD5_URL} \
    && cat md5sums.txt | awk '/${MITSCHEME_TAR}/ {print}' | tee md5sums.txt \
    && tar xf ${MITSCHEME_TAR}

WORKDIR ${MITSCHEME_DIR}
RUN cd src \
    && ./configure \
    && make \
    && make install

WORKDIR /
RUN rm -rf ${MITSCHEME_DIR} ${MITSCHEME_TAR} md5sums.txt

# Downloads and installs SCMUtils from source. You can target this stage during
# a build with '--target build-scmutils'.
FROM build-scheme AS build-scmutils

WORKDIR /
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    texinfo \
    texlive-xetex \
    texlive

WORKDIR /
RUN rm -rf /var/lib/apt/lists/*

ARG SCMUTILS_VERSION=20230902

ARG SCMUTILS_DIR=scmutils-${SCMUTILS_VERSION}
ARG SCMUTILS_TAR=${SCMUTILS_DIR}.tar.gz
ARG SCMUTILS_URL=https://groups.csail.mit.edu/mac/users/gjs/6946/mechanics-system-installation/native-code/${SCMUTILS_TAR}

WORKDIR /
COPY --from=build-scheme /usr/local /usr/local/

WORKDIR /
RUN curl -Lk ${SCMUTILS_URL} -o ${SCMUTILS_TAR} && \
    tar xf ${SCMUTILS_TAR}

WORKDIR ${SCMUTILS_DIR}
RUN ./install.sh \
	&& mv mechanics.sh /usr/local/bin/mechanics

WORKDIR /
RUN rm -rf ${SICMUTILS_DIR} ${SCMUTILS_TAR}

# Builds the runtime image for mit-scheme, based on 'scratch'. Stripped down
# image with only the essentials. You can target this stage during a build with
# '--target mit-scheme'.
FROM scratch AS mit-scheme

ENV PATH /usr/local/bin:/bin
ENV RUNTIME=mit-scheme
ENV RUNTIME_COMPLETION=/${RUNTIME}_completions.txt

WORKDIR /
COPY --from=build-init /bin/bash /bin/ls /bin/env /bin/sleep /bin/rlwrap /bin/
COPY --from=build-init /usr/lib/ /lib
COPY --from=build-init /usr/lib64/ /lib64
COPY --from=build-scheme /usr/local/bin/mit-scheme /usr/local/bin/
COPY --from=build-scheme /usr/local/lib/${MITSCHEME_LIB} /usr/local/lib/${MITSCHEME_LIB}

WORKDIR /
COPY /resources/mit-scheme_completions.txt /
COPY /resources/mit-scheme_spot_check.scm /

ENTRYPOINT ["/bin/bash", "-c", \
    "sleep .2 && \
    exec rlwrap -f ${RUNTIME_COMPLETION} ${RUNTIME} $@"]

# Builds the runtime image for mechanics. This image is a bit bloated at the
# moment because I haven't worked out how to pull out all of the tex
# dependencies needed at runtime! Once I figure that out, this image will be
# comparable to the mit-scheme runtime (e.g., based on 'scratch' with only the
# essentials). You can target this stage during a build with '--target
# mechanics'.
FROM build-scmutils AS mechanics

ENV PATH /usr/local/bin:/bin
ENV RUNTIME=mechanics
ENV RUNTIME_COMPLETION=/${RUNTIME}_completions.txt

WORKDIR /
COPY /resources/mechanics_completions.txt /
COPY /resources/mechanics_spot_check.scm /

ENTRYPOINT ["/bin/bash", "-c", \
    "export RUNTIME_COMPLETION_HISTORY=${PWD}/.${RUNTIME}_history && \
    sleep .2 && \
    exec rlwrap \
    -f ${RUNTIME_COMPLETION} \
    ${RUNTIME} \
    $@"]

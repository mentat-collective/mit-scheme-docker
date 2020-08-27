FROM ubuntu
MAINTAINER Sam Ritchie <sritchie09@gmail.com>

# libxt-dev, libltdl-dev
# Get dependencies, and clean up properly!
RUN apt-get update && DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
  build-essential \
  libx11-dev \
  m4 \
  python3-pip \
  rlwrap \
  texinfo \
  texlive \
  wget && \
  rm -rf /var/lib/apt/lists/*

# Set up environment variables to make the installation easier.
ENV SCHEME_VERSION 10.1.11
ENV SCHEME_DIR mit-scheme-${SCHEME_VERSION}
ENV SCHEME_TAR ${SCHEME_DIR}-x86-64.tar.gz

WORKDIR /tmp

# Get MIT-Scheme and install all the goodies, docs included.
RUN wget http://ftp.gnu.org/gnu/mit-scheme/stable.pkg/${SCHEME_VERSION}/${SCHEME_TAR} \
  && wget http://ftp.gnu.org/gnu/mit-scheme/stable.pkg/${SCHEME_VERSION}/md5sums.txt \
  && cat md5sums.txt | awk '/${SCHEME_TAR}/ {print}' | tee md5sums.txt \
  && tar xf ${SCHEME_TAR} \
  && cd ${SCHEME_DIR}/src \
  && ./configure && make && make install \
  && cd ../doc \
  && ./configure && make && make install-info install-html install-pdf \
  && cd ../.. \
  && rm -rf ${SCHEME_DIR} ${SCHEME_TAR} md5sums.txt

COPY ./resources/with_rlwrap.sh /usr/local/bin/with-rlwrap
RUN chmod +x /usr/local/bin/with-rlwrap

# Copy in completions, so we get a nice experience at the repl.
COPY ./resources/mit-scheme_completions.txt /root/.mit-scheme_completions

WORKDIR /root

# This allows mit-scheme to work out of the box; any arguments you send will get
# appended on to the end of this.
ENTRYPOINT ["with-rlwrap", "mit-scheme"]

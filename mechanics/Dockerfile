FROM sritchie/mit-scheme

# Install SCMUtils!
ENV SCM_UTILS_VERSION 20190830
ENV SCM_UTILS scmutils-${SCM_UTILS_VERSION}

WORKDIR /tmp

RUN wget http://groups.csail.mit.edu/mac/users/gjs/6946/${SCM_UTILS}.tar.gz \
  && tar xf ${SCM_UTILS}.tar.gz \
  && cd ${SCM_UTILS} \
  && ./install.sh \
  && mv mechanics.sh /usr/local/bin/mechanics \
  && cd .. \
  && rm -rf ${SCM_UTILS} ${SCM_UTILS}.tar.gz

# Copy in completions, so we get a nice experience at the repl.
COPY ./resources/mechanics_completions.txt /root/.mechanics_completions

WORKDIR /root

ENTRYPOINT ["with-rlwrap", "mechanics"]

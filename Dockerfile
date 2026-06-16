ARG ALPINE_VERSION=3.22

FROM alpine:${ALPINE_VERSION} AS builder

ARG CODEX_RELEASE

RUN apk add --no-cache ca-certificates curl gzip tar

COPY codex-release.env /tmp/codex-release.env

RUN curl -fsSL https://chatgpt.com/codex/install.sh -o /tmp/install.sh \
    && requested_release="${CODEX_RELEASE:-}" \
    && . /tmp/codex-release.env \
    && CODEX_RELEASE="${requested_release:-$CODEX_RELEASE}" \
    && test -n "$CODEX_RELEASE" \
    && CODEX_NON_INTERACTIVE=1 \
    CODEX_RELEASE="${CODEX_RELEASE}" \
    CODEX_INSTALL_DIR=/usr/local/bin \
    CODEX_HOME=/opt/codex \
    /bin/sh /tmp/install.sh \
    && /usr/local/bin/codex --version \
    && rm -f /tmp/install.sh

FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache ca-certificates git bash \
    && addgroup -S codex \
    && adduser -S -D -h /home/codex -G codex codex \
    && mkdir -p /workspace /home/codex/.codex \
    && chown -R codex:codex /workspace /home/codex

COPY --from=builder /opt/codex /opt/codex
COPY codex-wrapper.sh /usr/local/bin/codex
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN ln -s /opt/codex/packages/standalone/current/bin/codex /usr/local/bin/codex-real \
    && chmod 0755 /usr/local/bin/codex /usr/local/bin/docker-entrypoint.sh

ENV HOME=/home/codex \
    CODEX_HOME=/home/codex/.codex \
    CODEX_REAL_BIN=/usr/local/bin/codex-real

WORKDIR /workspace
USER codex

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["codex"]

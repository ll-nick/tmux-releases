FROM debian:bookworm-slim AS base

ARG PREFIX=/build

ENV DEBIAN_FRONTEND=noninteractive
ENV PREFIX=${PREFIX}

RUN apt-get update && \
    apt-get install -y \
        bison \
        build-essential \
        tar \
        pkg-config \
        wget && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p ${PREFIX}/{bin, include, lib, src}
WORKDIR ${PREFIX}/src


########
# musl #
########

FROM base AS musl-builder
ARG MUSL_VERSION=1.2.5

RUN wget https://musl.libc.org/releases/musl-${MUSL_VERSION}.tar.gz && \
    tar xf musl-${MUSL_VERSION}.tar.gz && \
    cd musl-${MUSL_VERSION} && \
    ./configure \
        --enable-gcc-wrapper \
        --disable-shared \
        --prefix=${PREFIX} && \
    make -j$(nproc) && \
    make install

ENV CC="${PREFIX}/bin/musl-gcc -static"


############
# libevent #
############

FROM musl-builder AS libevent-builder
ARG LIBEVENT_VERSION=2.1.12

RUN wget https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}-stable/libevent-${LIBEVENT_VERSION}-stable.tar.gz && \
    tar xf libevent-${LIBEVENT_VERSION}-stable.tar.gz && \
    cd libevent-${LIBEVENT_VERSION}-stable && \
    ./configure \
        --prefix=${PREFIX} \
        --disable-shared \
        --disable-openssl \
        --disable-libevent-regress \
        --disable-samples && \
    make -j$(nproc) && \
    make install


###########
# ncurses #
###########

FROM libevent-builder AS ncurses-builder
ARG NCURSES_VERSION=6.5

RUN wget https://invisible-island.net/archives/ncurses/ncurses-${NCURSES_VERSION}.tar.gz && \
    tar xzf ncurses-${NCURSES_VERSION}.tar.gz && \
    cd ncurses-${NCURSES_VERSION} && \
    ./configure \
        --prefix=${PREFIX} \
        --enable-pc-files \
        --with-pkg-config-libdir=${PREFIX}/lib/pkgconfig \
        --without-ada \
        --without-cxx \
        --without-cxx-binding \
        --without-tests \
        --without-manpages \
        --without-debug \
        --with-termlib \
        --with-default-terminfo-dir=/usr/share/terminfo \
        --with-terminfo-dirs=/etc/terminfo:/lib/terminfo:/usr/share/terminfo && \
    make -j$(nproc) && \
    make install


########
# tmux #
########

FROM ncurses-builder AS tmux-builder

ARG TMUX_VERSION
RUN test -n "${TMUX_VERSION}"

RUN wget https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz && \
    tar xzf tmux-${TMUX_VERSION}.tar.gz && \
    cd tmux-${TMUX_VERSION} && \
    PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig \
    ./configure \
        --prefix=${PREFIX} \
        --enable-static && \
    make -j$(nproc) && \
    make install


##################
# Artifact image #
##################

FROM alpine:latest
ARG PREFIX=/build
COPY --from=tmux-builder ${PREFIX}/bin/tmux /artifacts/tmux
ENTRYPOINT ["/artifacts/tmux"]
CMD ["-V"]


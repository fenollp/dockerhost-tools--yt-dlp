# syntax=docker.io/docker/dockerfile:1@sha256:39b85bbfa7536a5feceb7372a0817649ecb2724562a38360f4d6a7782a409b14

FROM --platform=$BUILDPLATFORM docker.io/library/alpine@sha256:82d1e9d7ed48a7523bdebc18cf6290bdb97b82302a8a9c27d4fe885949ea94d1 AS alpine

FROM --platform=$BUILDPLATFORM alpine AS tool
RUN \
  --mount=type=cache,target=/var/cache/apk ln -vs /var/cache/apk /etc/apk/cache && \
    set -ux \
 && apk add \
            ffmpeg \
            gcc \
            git \
            mpv \
            musl-dev \
            py3-pip \
            python3 \
            python3-dev \
            rtmpdump \
# https://github.com/yt-dlp/yt-dlp/tree/613dbce177d34ffc31053e8e01acf4bb107bcd1e#dependencies
 && pip install --no-cache-dir \
                               brotli \
                               certifi \
                               mutagen \
                               phantomjs \
                               pycryptodomex \
                               websockets \
                               xattr \
 && pip install --no-cache-dir yt-dlp
RUN \
    set -ux \
 && echo --force-ipv4 >>/etc/yt-dlp.conf \
# NOTE: https://github.com/yt-dlp/yt-dlp/issues/1136#issuecomment-932077195
 && echo "--output '%(title).200s-%(id)s.%(ext)s'" >>/etc/yt-dlp.conf \
 && echo --audio-multistreams >>/etc/yt-dlp.conf \
 && echo --video-multistreams >>/etc/yt-dlp.conf \
 && echo --check-formats >>/etc/yt-dlp.conf \
# https://github.com/yt-dlp/yt-dlp/issues/2875#issuecomment-1055015391
 && echo --abort-on-error >>/etc/yt-dlp.conf \
# TODO: https://github.com/yt-dlp/yt-dlp/issues/2875
 && echo "--sponsorblock-remove 'sponsor,interaction'" >>/etc/yt-dlp.conf \
# https://github.com/yt-dlp/yt-dlp/issues/871#issuecomment-911701285
#&& echo --force-keyframes >>/etc/yt-dlp.conf \
#&& echo --force-keyframes-at-cuts >>/etc/yt-dlp.conf \
 && echo --embed-chapters >>/etc/yt-dlp.conf \
 && echo --embed-info-json >>/etc/yt-dlp.conf \
 && echo --embed-metadata >>/etc/yt-dlp.conf \
 && echo --embed-subs >>/etc/yt-dlp.conf \
 && echo --embed-thumbnail >>/etc/yt-dlp.conf

FROM tool AS product
WORKDIR /app
ARG ARGs
ARG SEPARATOR=' '
RUN \
    --mount=type=cache,target=/root/.cache/yt-dlp \
    set -ux \
 && cmd="yt-dlp --cache-dir /root/.cache/yt-dlp --newline" \
 && case "$ARGs" in *' -f '*) ;; *' --format '*) ;; *' --format='*) ;; *) ARGs="--format 'bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b' $ARGs" ;; esac \
 && cmd="$cmd '$(echo "$ARGs" | sed "s%$SEPARATOR%' '%g")'" \
 && eval $cmd
ARG DO_NOT_REENCODE
RUN \
    set -ux \
 && vid=$(ls -S | head -n1) \
 && case "${DO_NOT_REENCODE:-}" in \
    '1') ;; \
# https://superuser.com/questions/908280/what-is-the-correct-way-to-fix-keyframes-in-ffmpeg-for-dash
    '')   ffmpeg -i "$vid" -force_key_frames 'expr:gte(t,n_forced*3)' _"$vid" \
       && mv _"$vid" "$vid" \
       ;; \
    *) echo "Unsupported DO_NOT_REENCODE=$DO_NOT_REENCODE, try =1 or do not set it." && exit 2 ;; \
    esac

FROM scratch
COPY --from=product /app/* /

## ARG SEPARATOR=' ': non-sed-special string that separates given $ARGs
## ARG ARGs: $SEPARATOR-separated CLI arguments
## ARG DO_NOT_REENCODE: set this to skip re-encoding video (with ffmpeg)
## Usage:
# DOCKER_BUILDKIT=1 docker build -o=. --build-arg ARGs='--format mp4/bestvideo*+bestaudio/best -- https://www.youtube.com/watch?v=BXmOlCy0oBM https://www.youtube.com/watch?v=dQw4w9WgXcQ' - <Dockerfile && ( ls -1 . && rm 'Erlang - The Movie (Fixed Audio)-BXmOlCy0oBM.mp4' 'Rick Astley - Never Gonna Give You Up (Official Music Video)-dQw4w9WgXcQ.mp4' )
# Dockerfile
# Erlang - The Movie (Fixed Audio)-BXmOlCy0oBM.mp4
# Rick Astley - Never Gonna Give You Up (Official Music Video)-dQw4w9WgXcQ.mp4

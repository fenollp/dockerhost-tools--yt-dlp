# syntax=docker/dockerfile:1@sha256:91f386bc3ae6cd5585fbd02f811e295b4a7020c23c7691d686830bf6233e91ad

FROM --platform=$BUILDPLATFORM docker.io/library/python:alpine@sha256:f4c1b7853b1513eb2f551597e2929b66374ade28465e7d79ac9e099ccecdfeec AS tool
RUN \
  --mount=type=cache,target=/var/cache/apk ln -vs /var/cache/apk /etc/apk/cache && \
    set -ux \
 && apk add --virtual .build-deps gcc musl-dev git \

 # https://github.com/yt-dlp/yt-dlp/tree/0b9c08b47bb5e95c21b067044ace4e824d19a9c2#dependencies
 && pip install --no-cache-dir brotli certifi mutagen pycryptodome websockets \
 && apk add ffmpeg mpv rtmpdump \

 && pip install --no-cache-dir yt-dlp \
 # TODO: drop whence https://github.com/yt-dlp/yt-dlp/pull/3302
 #&& pip install --no-cache-dir git+https://github.com/fstirlitz/yt-dlp@23c565604a5497dc141ae2b562f2467617b8856a \

 && apk del .build-deps
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
# && echo --force-keyframes >>/etc/yt-dlp.conf \
# && echo --force-keyframes-at-cuts >>/etc/yt-dlp.conf \

 && echo --embed-subs >>/etc/yt-dlp.conf \
 && echo --embed-thumbnail >>/etc/yt-dlp.conf \
 && echo --embed-metadata >>/etc/yt-dlp.conf \
 && echo --embed-chapters >>/etc/yt-dlp.conf

FROM tool AS product
WORKDIR /app
ARG ARGs
ARG SEPARATOR=' '
RUN \
    --mount=type=cache,target=/root/.cache/yt-dlp \
    set -ux \
 && cmd="yt-dlp --cache-dir /root/.cache/yt-dlp --newline" \
 && cmd="$cmd '$(echo "$ARGs" | sed "s%$SEPARATOR%' '%g")'" \
 && eval $cmd

RUN \
    set -ux \
 && vid=$(echo /app/*) \
 && vid=${vid##/app/} \
 && ffmpeg -i "$vid" -force_key_frames 'expr:gte(t,n_forced*3)' _"$vid" \
 && mv _"$vid" "$vid"

FROM scratch
COPY --from=product /app/* /

## ARG SEPARATOR=' ': non-sed-special string that separates given $ARGs
## ARG ARGs: $SEPARATOR-separated CLI arguments
## Usage:
# DOCKER_BUILDKIT=1 docker build -o=. --build-arg ARGs='--format mp4/bestvideo*+bestaudio/best -- https://www.youtube.com/watch?v=BXmOlCy0oBM https://www.youtube.com/watch?v=dQw4w9WgXcQ' - <Dockerfile && ( ls -1 . && rm 'Erlang - The Movie (Fixed Audio)-BXmOlCy0oBM.mp4' 'Rick Astley - Never Gonna Give You Up (Official Music Video)-dQw4w9WgXcQ.mp4' )
# Dockerfile
# Erlang - The Movie (Fixed Audio)-BXmOlCy0oBM.mp4
# Rick Astley - Never Gonna Give You Up (Official Music Video)-dQw4w9WgXcQ.mp4

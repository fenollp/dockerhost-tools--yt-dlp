# syntax=docker.io/docker/dockerfile:1@sha256:9ba7531bd80fb0a858632727cf7a112fbfd19b17e94c4e84ced81e24ef1a0dbc

# Use alpine:edge to get ffmpeg >=5.1 because https://github.com/yt-dlp/yt-dlp/issues/871#issuecomment-911701285
FROM --platform=$BUILDPLATFORM docker.io/library/alpine:edge@sha256:c223f84e05c23c0571ce8decefef818864869187e1a3ea47719412e205c8c64e AS tool
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
 # https://github.com/yt-dlp/yt-dlp/tree/c9f5ce511877ae4f22d2eb2f70c3c6edf6c1971d#dependencies
 && pip install --no-cache-dir \
                               brotli \
                               certifi \
                               mutagen \
                               phantomjs \
                               pycryptodomex \
                               websockets \
                               xattr \
 && pip install --no-cache-dir yt-dlp
 # TODO: drop whence https://github.com/yt-dlp/yt-dlp/pull/3302
 #&& pip install --no-cache-dir git+https://github.com/fstirlitz/yt-dlp@23c565604a5497dc141ae2b562f2467617b8856a
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

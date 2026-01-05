  ARG TARGETARCH
  
  FROM alpine:latest AS build-env

 RUN apk add --no-cache git make g++ linux-headers binutils go

WORKDIR /app

RUN git clone --depth=1 https://github.com/apalrd/tayga && \
    cd tayga && \
    make static

COPY ./v6check/ /app/v6check/

RUN cd v6check && go mod init v6check && CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -ldflags="-s -w" -o ../v6check
    
 FROM alpine:latest AS final-image

 LABEL version="1.0" maintainer="opencode" description="NAT64 container for IPv6 to IPv4 translation"

 RUN apk add --no-cache coredns radvd iptables

WORKDIR /app

COPY --from=build-env /app/tayga/tayga /app/tayga

COPY --from=build-env /app/v6check /app/v6check

 COPY ./config/ ./

 HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD pgrep tayga || exit 1

 ENTRYPOINT ["/bin/sh", "/app/entrypoint.sh"]

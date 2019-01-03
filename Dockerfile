FROM golang:1.11.4-alpine3.8 as builder

ENV GO111MODULE on
ENV PROJECT_NAME dex-k8s-authenticator

RUN apk add --no-cache --update git

WORKDIR /go/src/${PROJECT_NAME}
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o bin/${PROJECT_NAME}

FROM alpine:3.8
# Dex connectors, such as GitHub and Google logins require root certificates.
# Proper installations should manage those certificates, but it's a bad user
# experience when this doesn't work out of the box.
#
# OpenSSL is required so wget can query HTTPS endpoints for health checking.
RUN apk add --no-cache --update ca-certificates openssl curl

WORKDIR /app

RUN mkdir -p bin
COPY --from=builder /go/src/dex-k8s-authenticator/bin/dex-k8s-authenticator bin/dex-k8s-authenticator
COPY --from=builder /go/src/dex-k8s-authenticator/html html
COPY --from=builder /go/src/dex-k8s-authenticator/templates templates

# Add any required certs/key by mounting a volume on /certs - Entrypoint will copy them and run update-ca-certificates at startup
RUN mkdir -p /certs

COPY entrypoint.sh bin/
RUN chmod a+x bin/entrypoint.sh

ENTRYPOINT ["/app/bin/entrypoint.sh"]

CMD ["--help"]


# FROM ubuntu
FROM alpine
MAINTAINER Sinan Goo

RUN apk update && apk upgrade
RUN apk --no-cache add socat bash jq curl

# RUN apt-get update
# RUN apt-get install -y socat bash jq curl

RUN mkdir /socat_server
WORKDIR /socat_server

ADD cgi-bin /socat_server/cgi-bin
ADD socat_cgi /socat_server/

EXPOSE 8080

CMD ["./socat_cgi"]


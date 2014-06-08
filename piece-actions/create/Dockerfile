FROM ubuntu:14.04

RUN apt-get -y install redis-tools

ADD ./behaviour /behaviour

ENTRYPOINT ["/behaviour"]

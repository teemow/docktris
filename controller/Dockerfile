FROM ubuntu:14.04

RUN apt-get update
RUN apt-get -y install nodejs npm
RUN apt-get -y install rubygems1.9.1 git
RUN gem install foreman

RUN mkdir /app
ADD . /app

WORKDIR /app

CMD ["foreman", "start", "web"]

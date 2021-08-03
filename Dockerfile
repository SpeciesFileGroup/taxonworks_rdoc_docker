FROM ruby:alpine

RUN mkdir -p /app/public

RUN apk add git g++ make musl-dev openssl-dev
RUN gem install puma sinatra yard

ENV RACK_ENV=production

COPY app /app

WORKDIR /app

CMD ["/app/server.rb"]

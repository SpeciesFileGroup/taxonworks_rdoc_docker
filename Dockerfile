FROM ruby:alpine

RUN mkdir -p /app/public

RUN apk add git
RUN gem install sinatra yard

ENV RACK_ENV=production

COPY app /app

WORKDIR /app

CMD ["/app/server.rb"]

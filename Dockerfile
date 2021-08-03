FROM ruby:alpine AS base

RUN mkdir -p /app/public

RUN apk add --no-cache git

ENV RACK_ENV=production

COPY app /app

WORKDIR /app

FROM base AS gems-build

RUN apk add --no-cache g++ make musl-dev openssl-dev

RUN gem install puma sinatra yard

FROM base

COPY --from=gems-build /usr/local/bundle /usr/local/bundle

CMD ["/app/server.rb"]

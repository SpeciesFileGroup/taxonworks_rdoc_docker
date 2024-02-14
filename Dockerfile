FROM ruby:3.3

RUN mkdir -p /app/public

ENV RACK_ENV=production

COPY app /app

WORKDIR /app

RUN gem install bundler && bundle install

CMD ["/app/server.rb"]

ARG RUBY_VERSION=3.4.11

FROM ruby:${RUBY_VERSION}-slim-bookworm AS base

RUN sed -i 's|http://deb.debian.org|https://deb.debian.org|g' /etc/apt/sources.list.d/debian.sources

FROM base AS builder

ARG BUNDLER_WORKERS=3

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY app/Gemfile app/Gemfile.lock ./

RUN bundle config set deployment true \
    && bundle config set path /usr/local/bundle \
    && bundle config set without test \
    && bundle install --jobs "${BUNDLER_WORKERS}" --retry 3

FROM base

ENV APP_ENV=production \
    RACK_ENV=production \
    DOCS_ROOT=/var/lib/taxonworks-rdoc \
    TAXONWORKS_REF=development

RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 rdoc \
    && useradd --uid 10001 --gid rdoc --create-home --shell /usr/sbin/nologin rdoc \
    && mkdir -p /app /var/lib/taxonworks-rdoc \
    && chown -R rdoc:rdoc /app /var/lib/taxonworks-rdoc

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --chown=rdoc:rdoc app /app

WORKDIR /app
USER rdoc

EXPOSE 4567

CMD ["bundle", "exec", "ruby", "server.rb"]

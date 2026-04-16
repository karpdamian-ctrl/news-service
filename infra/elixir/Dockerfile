FROM elixir:1.18

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git inotify-tools postgresql-client \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY infra/elixir/entrypoint.sh /usr/local/bin/elixir-entrypoint
RUN chmod +x /usr/local/bin/elixir-entrypoint

ENTRYPOINT ["elixir-entrypoint"]

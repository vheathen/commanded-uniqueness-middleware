import Config

config :commanded_uniqueness_middleware,
  adapter: Commanded.Middleware.Uniqueness.Adapter.Cachex,
  ttl: 2_000

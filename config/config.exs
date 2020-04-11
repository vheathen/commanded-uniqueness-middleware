import Config

config :commanded_uniqueness_middleware,
  adapter: Commanded.Middleware.Uniqueness.Adapter.Cachex,
  ttl: 2_000

config :mix_test_watch,
  tasks: [
    "test --no-start --stale --max-failures 1 --seed 0 --trace --exclude pending",
    "test --no-start --max-failures 1 --exclude pending"
  ]

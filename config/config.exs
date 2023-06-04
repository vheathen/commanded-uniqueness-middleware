import Config

config :commanded_uniqueness_middleware, Commanded.Middleware.Uniqueness.NebulexTestCache,
  # When using :shards as backend
  backend: :shards,
  # GC interval for pushing new generation: 12 hrs
  gc_interval: :timer.hours(12),
  # Max 1 million entries in cache
  max_size: 1_000_000,
  # Max 2 GB of memory
  allocated_memory: 2_000_000_000,
  # GC min timeout: 10 sec
  gc_cleanup_min_timeout: :timer.seconds(10),
  # GC max timeout: 10 min
  gc_cleanup_max_timeout: :timer.minutes(10)

# config :commanded_uniqueness_middleware,
#   adapter: Commanded.Middleware.Uniqueness.Adapter.Nebulex,
#   nebulex_cache: Commanded.Middleware.Uniqueness.NebulexTestCache,
#   ttl: 2_000

# config :commanded_uniqueness_middleware,
#   adapter: Commanded.Middleware.Uniqueness.Adapter.Cachex,
#   ttl: 2_000

config :mix_test_watch,
  tasks: [
    "test --no-start --stale --max-failures 1 --seed 0 --trace --exclude pending",
    "test --no-start --max-failures 1 --exclude pending"
  ]

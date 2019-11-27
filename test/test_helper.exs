Cachex.Application.start(:normal, [])
Application.ensure_all_started(:commanded_uniqueness_middleware)
ExUnit.start()

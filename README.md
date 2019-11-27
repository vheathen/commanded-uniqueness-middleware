# Commanded.Middleware.Uniqueness

A [Commanded](https://github.com/commanded/commanded) [middleware](https://hexdocs.pm/commanded/commands.html#middleware) for checking certain values uniqueness during commands dispatch. Might be useful as a short-term unique values cache before subsequent events persisted and projected.

Based on the [Ben Smith](https://github.com/slashdotdash)'s idea described in his "Building Conduit" [book](https://leanpub.com/buildingconduit).

## Installation

As it still in alpha stage you can use it by adding `commanded_uniqueness_middleware` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:commanded_uniqueness_middleware, github: "vheathen/commanded-uniqueness-middleware"}
  ]
end
```

Documentation going to be available ASAP.

As of now you can check modules documentation and tests to get to know behavior.
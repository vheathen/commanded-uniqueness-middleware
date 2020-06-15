# Commanded.Middleware.Uniqueness

A [Commanded](https://github.com/commanded/commanded) [middleware](https://hexdocs.pm/commanded/commands.html#middleware) for checking certain values uniqueness during commands dispatch. Might be useful as a short-term unique values cache before subsequent events persisted and projected.

Based on the [Ben Smith](https://github.com/slashdotdash)'s idea described in his "Building Conduit" [book](https://leanpub.com/buildingconduit).

[Please check the latest published CommandedMiddlewareUniqueness release documentation on Hex](https://hexdocs.pm/commanded_uniqueness_middleware/).

## Installation

Add `commanded_uniqueness_middleware` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:commanded_uniqueness_middleware, "~> 0.6.0"}
  ]
end
```

## Configuration

Define options in config/config.exs as:

```elixir
  config :commanded_uniqueness_middleware,
    adapter: Commanded.Middleware.Uniqueness.Adapter.Cachex,
    # ttl: 60 minutes in seconds
    ttl: 60 * 60,
    use_command_as_partition: false
```

  where:
    - `:adapter` is an Uniqueness adapter implemented `Commanded.Middleware.Uniqueness.Adapter` behavior,
    - `:ttl` is claimed value time-to-live,
    - `:use_command_as_partition` should be set to true to use each command module name as partition. Use with  caution! If neither this nor Unique protocol `:partition` option defined then `Commanded.Middleware.Uniqueness` value used as a partition name.

## Adapters
As of now the only adapter exists is a Cachex based one.
Any adapter implementing `Commanded.Middleware.Uniqueness.Adapter` behavior can be used.

## Usage
Imagine you have an aggregate with a unique field value requirement, for example, it might be a `:username` field. You've got a new user and issue a `RegisterUser` command with `SomeCoolUsername` `:name` field value. The command successfully went through all checks and spawn a UserRegistered event but this event haven't been projected yet. At this very moment an another user wants to register with the same name, and as the previous event isn't projected you have no information that this user name 
has been taken.

You can use `Commanded.Middleware.Uniqueness` to ensure that your system will not get into a conflict state in between two commands.

It utilizes [`Elixir Protocol`](https://hexdocs.pm/elixir/Protocol.html).

You need to put 
```elixir
middleware Commanded.Middleware.Uniqueness
```
into your Commanded Router as described in [Commanded docs](https://hexdocs.pm/commanded/commands.html#middleware).

Then you need to define a `Commanded.Middleware.Uniqueness.UniqueFields` implementation for the specific command:

```elixir
defmodule MyApp.RegisterUser do
  defstruct [
    :id,
    :name,
    :email
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: MyApp.RegisterUser do
  def unique(%MyApp.RegisterUser{id: id}),
    do: [
      {:name, "has already been taken", id, ignore_case: true, is_unique: &is_taken_externally?/4}
    ]

  def is_taken_externally?(_field, value, _owner, _opts), do: !String.starts_with?(value, "ExternallyTaken")
end
```

At the first command dispatch the Uniqueness Middleware checks the `:name` field key - value pair is 
free and claims it for the given owner id.

If you need to release previously claimed value with existing TTL you should use `release/4`, `release_by_owner/3` or `release_by_value/3` adapter methods:

```elixir
defmodule MyApp.UserNameCacheHandler do
  use Commanded.Event.Handler,
    application: MyApp.App,
    name: "UserNameCacheHandler"

  alias MyApp.UserDeleted

  def handle(%UserDeleted{id: id}, _metadata) do
    :ok = Commanded.Middleware.Uniqueness.release_by_owner(:name, id)
    end
  end
end
```

To get to know behavior you can check modules documentation and tests (especially commands described in `test/support`).
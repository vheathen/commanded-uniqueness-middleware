defmodule Commanded.Middleware.Uniqueness.Adapter do
  @moduledoc """
  Provides uniqueness cache adapter behaviour.

  Define options in config/config.exs as:

    config :commanded_uniqueness_middleware,
      adapter: Commanded.Middleware.Uniqueness.Adapter.Cachex,
      # ttl: 60 minutes in seconds
      ttl: 60 * 60,
      use_command_as_partition: true

  where:
    - `:adapter` is an Uniqueness adapter implemented `Commanded.Middleware.Uniqueness.Adapter` behavior,
    - `:ttl` is claimed value time-to-live,
    - `:use_command_as_partition` should be set to use each command module name as partition. If neither this nor
      `:partition` option defined then `Commanded.Middleware.Uniqueness` value used as a partition name.
  """

  @doc """
  Returns an adapter child_spec to inject into a supervisor tree
  """
  @callback child_spec() :: Supervisor.child_spec()

  @doc """
  Claims an `key`, `value`, `owner`, `partition` set
  or reports that this combination has already been claimed.

  If an `key`, `value`, `owner`, `partition` set has to be claimed
  and an old value for the given owner exists it releases first.
  """
  @callback claim(key :: term, value :: term, owner :: term, partition :: term) ::
              :ok | {:error, :already_exists} | {:error, :unknown_error}

  @doc """
  Claims an `key`, `value`, `partition` set
  or reports that this combination has already been claimed.
  """
  @callback claim(key :: term, value :: term, partition :: term) ::
              :ok | {:error, :already_exists} | {:error, :unknown_error}

  @doc """
  Releases a value record via `key`, `value`, `owner`, `partition` set
  """
  @callback release(key :: term, value :: term, owner :: term, partition :: term) ::
              :ok | {:error, :claimed_by_another_owner} | {:error, :unknown_error}

  @doc """
  Releases a value record via `key`, `owner`, `partition` set
  """
  @callback release_by_owner(key :: term, owner :: term, partition :: term) ::
              :ok | {:error, :unknown_error}

  @doc """
  Releases a value record via `key`, `value`, `partition` set
  """
  @callback release_by_value(key :: term, value :: term, partition :: term) ::
              :ok | {:error, :unknown_error}

  ###
  ###
  ### Functions
  ###
  ###

  @doc """
  Returns the current adapter or `nil`
  """
  @spec get :: :atom | nil
  def get do
    adapter()
  end

  @doc false
  @spec child_spec :: Supervisor.child_spec() | nil
  def child_spec do
    case adapter() do
      nil -> nil
      adapter -> adapter.child_spec()
    end
  end

  @doc false
  @spec inject_child_spec(children :: list(), opts :: [at: integer() | atom()]) ::
          list(Supervisor.child_spec())
  def inject_child_spec(children, opts \\ []) when is_list(children) do
    case(child_spec()) do
      nil ->
        children

      child ->
        index = get_position(opts)
        List.insert_at(children, index, child)
    end
  end

  @positions [
    first: 0,
    last: -1
  ]

  defp adapter do
    case Application.get_env(:commanded_uniqueness_middleware, :adapter) do
      nil ->
        nil

      adapter ->
        case Code.ensure_loaded?(adapter) do
          true -> adapter
          _ -> nil
        end
    end
  end

  defp get_position(opts) when is_list(opts), do: opts |> Keyword.get(:at) |> translate_position()

  defp translate_position(nil), do: translate_position(:first)

  defp translate_position(position) when is_atom(position),
    do: translate_position(Keyword.get(@positions, position))

  defp translate_position(position) when is_integer(position), do: position

  defp translate_position(_),
    do: raise("#{__MODULE__}: :at option should be either #{inspect(@positions)} or integer")
end

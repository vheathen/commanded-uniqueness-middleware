defmodule Commanded.Middleware.Uniqueness.Adapter do
  @moduledoc """
  Module intended to provide API behaviour to ensure a short-term value uniqueness.

  Define options in config/config.exs as:

    config :commanded_uniqueness_middleware,
      adapter: Commanded.Middleware.Uniqueness.Adapter.Cachex,
      # ttl: 60 minutes in seconds
      ttl: 60 * 60
  """

  @doc """
  Returns an adapter child_spec to inject into a supervisor tree
  """
  @callback child_spec() :: Supervisor.child_spec()

  @doc """
  Claims a {id, value, owner} or report that this combination has already been claimed.

  If a {id, new_value, owner} has to be claimed and old value exists it
   releases first.
  """
  @callback claim(id :: term, value :: term, owner :: term, partition :: term) ::
              :ok | {:error, :already_exists} | {:error, :unknown_error}
  @callback release(id :: term, value :: term, owner :: term, partition :: term) ::
              :ok | {:error, :claimed_by_another_owner} | {:error, :unknown_error}
  @callback release(id :: term, owner :: term, partition :: term) ::
              :ok | {:error, :unknown_error}

  @spec child_spec :: Supervisor.child_spec() | nil
  def child_spec do
    case adapter() do
      nil -> nil
      adapter -> adapter.child_spec()
    end
  end

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

  @spec get :: :atom | nil
  def get do
    adapter()
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

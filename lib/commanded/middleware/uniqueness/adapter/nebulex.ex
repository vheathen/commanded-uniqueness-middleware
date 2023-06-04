defmodule Commanded.Middleware.Uniqueness.Adapter.Nebulex do
  @behaviour Commanded.Middleware.Uniqueness.Adapter

  @moduledoc false

  require Cachex.Spec

  @by_value_key :bv
  @by_owner_key :bo

  @impl true
  def child_spec, do: nebulex_cache().child_spec([])

  @impl true
  def claim(key, value, owner, partition) do
    nebulex_cache().transaction(fn -> do_claim(key, value, owner, partition) end)
  rescue
    error -> {:error, error}
  end

  @impl true
  def claim(key, value, partition) do
    nebulex_cache().transaction(fn -> do_claim(key, value, partition) end)
  rescue
    error -> {:error, error}
  end

  @impl true
  def release(key, value, owner, partition) do
    nebulex_cache().transaction(fn -> do_release(key, value, owner, partition) end)
  rescue
    error -> {:error, error}
  end

  @impl true
  def release_by_owner(key, owner, partition) do
    nebulex_cache().transaction(fn -> do_release_by_owner(key, owner, partition) end)
  rescue
    error -> {:error, error}
  end

  @impl true
  def release_by_value(key, value, partition) do
    nebulex_cache().transaction(fn -> do_release_by_value(key, value, partition) end)
  rescue
    error -> {:error, error}
  end

  defp ttl, do: Application.get_env(:commanded_uniqueness_middleware, :ttl, :infinity)

  defp nebulex_cache, do: Application.get_env(:commanded_uniqueness_middleware, :nebulex_cache)

  defp compose_by_owner(owner, partition, key), do: {partition, @by_owner_key, key, owner}
  defp compose_by_value(value, partition, key), do: {partition, @by_value_key, key, value}

  defp do_claim(key, value, owner, partition) do
    value
    |> compose_by_value(partition, key)
    |> nebulex_cache().get()
    |> case do
      nil ->
        do_release_by_owner(key, owner, partition)
        put_to_cache(key, value, owner, partition)

      ^owner ->
        :ok

      _ ->
        {:error, :already_exists}
    end
  end

  defp do_claim(key, value, partition) do
    value
    |> compose_by_value(partition, key)
    |> nebulex_cache().get()
    |> case do
      nil -> put_to_cache(key, value, partition)
      _ -> {:error, :already_exists}
    end
  end

  defp do_release(key, value, owner, partition) do
    value
    |> compose_by_value(partition, key)
    |> nebulex_cache().get()
    |> case do
      nil -> :ok
      ^owner -> delete_from_cache(key, value, owner, partition)
      _ -> {:error, :claimed_by_another_owner}
    end
  end

  defp do_release_by_owner(key, owner, partition) do
    owner
    |> compose_by_owner(partition, key)
    |> nebulex_cache().get()
    |> case do
      nil -> :ok
      value -> delete_from_cache(key, value, owner, partition)
    end
  end

  defp do_release_by_value(key, value, partition) do
    value
    |> compose_by_value(partition, key)
    |> nebulex_cache().get()
    |> case do
      nil -> :ok
      owner -> delete_from_cache(key, value, owner, partition)
    end
  end

  defp delete_from_cache(key, value, owner, partition) do
    value |> compose_by_value(partition, key) |> nebulex_cache().delete()
    owner |> compose_by_owner(partition, key) |> nebulex_cache().delete()

    :ok
  end

  defp put_to_cache(key, value, owner \\ :ok, partition)

  defp put_to_cache(key, value, :ok = owner, partition) do
    value |> compose_by_value(partition, key) |> nebulex_cache().put(owner, ttl: ttl())

    :ok
  end

  defp put_to_cache(key, value, owner, partition) do
    owner |> compose_by_owner(partition, key) |> nebulex_cache().put(value, ttl: ttl())
    value |> compose_by_value(partition, key) |> nebulex_cache().put(owner, ttl: ttl())

    :ok
  end
end

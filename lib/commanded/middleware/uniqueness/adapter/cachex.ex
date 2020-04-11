defmodule Commanded.Middleware.Uniqueness.Adapter.Cachex do
  @behaviour Commanded.Middleware.Uniqueness.Adapter

  @moduledoc false

  require Cachex.Spec

  @cachex __MODULE__

  @by_value_key :bv
  @by_owner_key :bo

  @impl true
  def child_spec do
    %{
      id: @cachex,
      start: {Cachex, :start, [@cachex, [expiration: Cachex.Spec.expiration(default: ttl())]]}
    }
  end

  @impl true
  def claim(key, value, owner, partition) do
    {exists?, error} = exists?({partition, @by_value_key, key, value})

    @cachex
    |> Cachex.get_and_update({partition, @by_value_key, key, value}, fn
      {:error, error} ->
        {:ignore, {:error, error}}

      _ when error ->
        {:ignore, {:error, error}}

      nil when not exists? ->
        :ok = release_by_owner(key, owner, partition)

        Cachex.put(@cachex, {partition, @by_owner_key, key, owner}, value)
        {:commit, owner}

      ^owner ->
        {:ignore, :ok}

      _ ->
        {:ignore, {:error, :already_exists}}
    end)
    |> case do
      {:commit, _} -> :ok
      {:ignore, result} -> result
    end
  end

  @impl true
  def claim(key, value, partition) do
    {exists?, error} = exists?({partition, @by_value_key, key, value})

    @cachex
    |> Cachex.get_and_update({partition, @by_value_key, key, value}, fn
      {:error, error} ->
        {:ignore, {:error, error}}

      _ when error ->
        {:ignore, {:error, error}}

      _ when exists? ->
        {:ignore, {:error, :already_exists}}

      _ ->
        {:commit, nil}
    end)
    |> case do
      {:commit, _} -> :ok
      {:ignore, result} -> result
    end
  end

  @impl true
  def release(key, value, owner, partition) do
    {exists?, error} = exists?({partition, @by_value_key, key, value})

    case Cachex.get(@cachex, {partition, @by_value_key, key, value}) do
      _ when error ->
        {:error, error}

      {:ok, ^owner} ->
        Cachex.del(@cachex, {partition, @by_value_key, key, value})
        Cachex.del(@cachex, {partition, @by_owner_key, key, owner})

        :ok

      {:ok, _} when exists? ->
        {:error, :claimed_by_another_owner}

      {:ok, _} ->
        :ok

      _ ->
        {:error, :unknown_error}
    end
  end

  @impl true
  def release_by_owner(key, owner, partition) do
    {exists?, error} = exists?({partition, @by_owner_key, key, owner})

    case Cachex.get(@cachex, {partition, @by_owner_key, key, owner}) do
      _ when error ->
        {:error, error}

      {:ok, _} when not exists? ->
        :ok

      {:ok, value} ->
        Cachex.del(@cachex, {partition, @by_value_key, key, value})
        Cachex.del(@cachex, {partition, @by_owner_key, key, owner})
        :ok

      _ ->
        {:error, :unknown_error}
    end
  end

  @impl true
  def release_by_value(key, value, partition) do
    {exists?, error} = exists?({partition, @by_value_key, key, value})

    case Cachex.get(@cachex, {partition, @by_value_key, key, value}) do
      _ when error ->
        {:error, error}

      {:ok, _} when not exists? ->
        :ok

      {:ok, owner} ->
        Cachex.del(@cachex, {partition, @by_value_key, key, value})
        Cachex.del(@cachex, {partition, @by_owner_key, key, owner})
        :ok

      _ ->
        {:error, :unknown_error}
    end
  end

  defp ttl do
    Application.get_env(:commanded_uniqueness_middleware, :ttl)
  end

  defp exists?({partition, dict_type, key, value}) do
    case Cachex.exists?(@cachex, {partition, dict_type, key, value}) do
      {:ok, exists?} -> {exists?, false}
      {:error, error} -> {:unknown, error}
    end
  end
end

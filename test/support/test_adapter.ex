defmodule Commanded.Middleware.Uniqueness.TestAdapter do
  @moduledoc false
  @behaviour Commanded.Middleware.Uniqueness.Adapter

  def child_spec do
    %{
      id: :some_id,
      start: {Module, :start, [opt1: "cool_value"]}
    }
  end

  def claim(:name, :a_new_value, :non_default_part), do: :ok
  def claim(:name, :a_new_value, Commanded.Middleware.Uniqueness), do: :ok
  def claim(:name, :claimed_value, Commanded.Middleware.Uniqueness), do: {:error, :already_exists}
  def claim(:name, :error, Commanded.Middleware.Uniqueness), do: {:error, :unknown_error}

  def claim(:name, :a_new_value, :an_id, :non_default_part), do: :ok
  def claim(:name, :a_new_value, :an_id, Commanded.Middleware.Uniqueness), do: :ok

  def claim(:name, :claimed_value, :an_id, Commanded.Middleware.Uniqueness),
    do: {:error, :already_exists}

  def claim(:name, :error, :an_id, Commanded.Middleware.Uniqueness), do: {:error, :unknown_error}

  def release(:name, :a_claimed_value, :an_id, :non_default_part), do: :ok
  def release(:name, :a_claimed_value, :an_id, Commanded.Middleware.Uniqueness), do: :ok

  def release(:name, :a_claimed_value, :an_another_id, Commanded.Middleware.Uniqueness),
    do: {:error, :claimed_by_another_owner}

  def release(:name, :error, :an_id, Commanded.Middleware.Uniqueness),
    do: {:error, :unknown_error}

  def release_by_owner(:name, :an_id, :non_default_part), do: :ok
  def release_by_owner(:name, :an_id, Commanded.Middleware.Uniqueness), do: :ok

  def release_by_owner(:name, :error, Commanded.Middleware.Uniqueness),
    do: {:error, :unknown_error}

  def release_by_value(:name, :a_claimed_value, :non_default_part), do: :ok
  def release_by_value(:name, :a_claimed_value, Commanded.Middleware.Uniqueness), do: :ok

  def release_by_value(:name, :error, Commanded.Middleware.Uniqueness),
    do: {:error, :unknown_error}
end

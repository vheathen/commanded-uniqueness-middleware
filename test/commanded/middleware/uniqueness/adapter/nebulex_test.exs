defmodule Commanded.Middleware.Uniqueness.Adapter.NebulexTest do
  @moduledoc false

  use ExUnit.Case, async: false

  @nebulex_adapter Commanded.Middleware.Uniqueness.Adapter.Nebulex
  @nebulex_cache Commanded.Middleware.Uniqueness.NebulexTestCache

  @by_value_key :bv
  @by_owner_key :bo

  setup_all do
    app_settings = Application.get_all_env(:commanded_uniqueness_middleware)
    Application.put_all_env(commanded_uniqueness_middleware: [adapter: @nebulex_adapter, nebulex_cache: @nebulex_cache])

    @nebulex_cache
    |> Process.whereis()
    |> case do
      nil -> {:ok, _cache_pid} = start_supervised(@nebulex_cache)
      _ -> :ok
    end

    on_exit(fn ->
      Enum.each([:adapter, :nebulex_cache], &Application.delete_env(:commanded_uniqueness_middleware, &1))
      Application.put_all_env(commanded_uniqueness_middleware: app_settings)
    end)

    :ok
  end

  setup do
    on_exit(fn ->
      @nebulex_cache.delete_all()
    end)

    key = :field_name
    value = Faker.Lorem.sentence()
    owner = Faker.UUID.v4()
    partition = Faker.String.base64()

    assert :ok == @nebulex_adapter.claim(key, value, owner, partition)

    [key: key, value: value, owner: owner, partition: partition]
  end

  describe "child_spec/0" do
    test "should return a correct child spec" do
      assert @nebulex_adapter.child_spec() == @nebulex_cache.child_spec([])
    end
  end

  describe "claim/4" do
    test "should return :ok and put into cache owner under {@by_value_key, @partition, key, value} key and value under {partition, @by_owner_key, key, owner} key if no {key, value} key exists",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert owner == get_owner_by_value(value, partition, key)
      assert value == get_value_by_owner(owner, partition, key)
    end

    test "should return :ok if {key, value} key exists and has owner as a value",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @nebulex_adapter.claim(key, value, owner, partition)

      assert owner == get_owner_by_value(value, partition, key)
      assert value == get_value_by_owner(owner, partition, key)
    end

    test "should return {:error, :already_exists} if {key, value} key exists but has a different than owner value",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      other_owner = Faker.UUID.v4()

      assert {:error, :already_exists} == @nebulex_adapter.claim(key, value, other_owner, partition)

      assert owner == get_owner_by_value(value, partition, key)
      assert value == get_value_by_owner(owner, partition, key)

      refute other_owner == get_owner_by_value(value, partition, key)
      assert nil == get_value_by_owner(other_owner, partition, key)
    end

    test "should release an old {key, value} key if the same owner claims a new value for the same key",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      new_value = Faker.Lorem.sentence()

      assert :ok == @nebulex_adapter.claim(key, new_value, owner, partition)

      assert nil == get_owner_by_value(value, partition, key)
      assert owner == get_owner_by_value(new_value, partition, key)
      assert new_value == get_value_by_owner(owner, partition, key)
    end
  end

  describe "claim/3" do
    setup %{
      key: key,
      value: value,
      owner: owner,
      partition: partition
    } do
      assert :ok = @nebulex_adapter.release(key, value, owner, partition)
    end

    test "should return :ok and create a cache record under {partition, @by_value_key, key, value} key",
         %{
           key: key,
           value: value,
           partition: partition
         } do
      assert :ok = @nebulex_adapter.claim(key, value, partition)
      assert value |> compose_by_value(partition, key) |> @nebulex_cache.has_key?()
    end

    test "should return {:error, :already_exists} if {key, value} key exists",
         %{
           key: key,
           value: value,
           partition: partition
         } do
      assert :ok = @nebulex_adapter.claim(key, value, partition)
      assert {:error, :already_exists} == @nebulex_adapter.claim(key, value, partition)
    end
  end

  describe "release/4" do
    test "should return :ok and delete {key, owner} and {key, value} if they exist",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @nebulex_adapter.release(key, value, owner, partition)

      assert nil == get_owner_by_value(value, partition, key)
      assert nil == get_value_by_owner(owner, partition, key)
    end

    test "should return :ok if no given value exists", %{partition: partition} do
      key = :other_field_name
      value = Faker.Lorem.sentence()
      owner = Faker.UUID.v4()

      assert nil == get_owner_by_value(value, partition, key)
      assert nil == get_value_by_owner(owner, partition, key)

      assert :ok == @nebulex_adapter.release(key, value, owner, partition)

      assert nil == get_owner_by_value(value, partition, key)
      assert nil == get_value_by_owner(owner, partition, key)
    end

    test "should return {:error, :claimed_by_another_owner} if claimed by another owner",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      other_owner = Faker.UUID.v4()

      assert {:error, :claimed_by_another_owner} == @nebulex_adapter.release(key, value, other_owner, partition)

      assert owner == get_owner_by_value(value, partition, key)
      assert value == get_value_by_owner(owner, partition, key)
    end
  end

  describe "release_by_owner/3" do
    test "should return :ok and delete {key, owner} and {key, value} if they are exists",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @nebulex_adapter.release_by_owner(key, owner, partition)

      assert nil == get_owner_by_value(value, partition, key)
      assert nil == get_value_by_owner(owner, partition, key)
    end

    test "should return :ok if no given value exists", %{partition: partition} do
      key = :other_field_name
      owner = Faker.UUID.v4()

      assert nil == get_value_by_owner(owner, partition, key)

      assert :ok == @nebulex_adapter.release_by_owner(key, owner, partition)

      assert nil == get_value_by_owner(owner, partition, key)
    end
  end

  describe "release_by_value/3" do
    test "should return :ok and delete {key, value} if they are exists",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @nebulex_adapter.release(key, value, owner, partition)

      assert :ok = @nebulex_adapter.claim(key, value, partition)

      assert :ok == @nebulex_adapter.release_by_value(key, value, partition)

      assert nil == get_owner_by_value(value, partition, key)
    end

    test "should return :ok and delete {key, owner} and {key, value} if they are exists and where claimed by claim/4",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @nebulex_adapter.release_by_value(key, value, partition)

      assert nil == get_owner_by_value(value, partition, key)
      assert nil == get_value_by_owner(owner, partition, key)
    end

    test "should return :ok if no given value claimed", %{partition: partition} do
      key = :other_field_name
      value = Faker.UUID.v4()

      assert nil == get_owner_by_value(value, partition, key)

      assert :ok == @nebulex_adapter.release_by_value(key, value, partition)
    end
  end

  defp get_owner_by_value(value, partition, key), do: value |> compose_by_value(partition, key) |> @nebulex_cache.get()
  defp get_value_by_owner(owner, partition, key), do: owner |> compose_by_owner(partition, key) |> @nebulex_cache.get()

  defp compose_by_owner(owner, partition, key), do: {partition, @by_owner_key, key, owner}
  defp compose_by_value(value, partition, key), do: {partition, @by_value_key, key, value}
end

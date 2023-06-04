defmodule Commanded.Middleware.Uniqueness.Adapter.CachexTest do
  @moduledoc false

  use ExUnit.Case, async: false

  require Cachex.Spec

  @cachex_adapter Commanded.Middleware.Uniqueness.Adapter.Cachex

  @by_value_key :bv
  @by_owner_key :bo

  setup_all do
    app_settings = Application.get_all_env(:commanded_uniqueness_middleware)

    case Cachex.get(@cachex_adapter, :anything) do
      {:error, :no_cache} ->
        Application.put_all_env(commanded_uniqueness_middleware: [adapter: @cachex_adapter, ttl: 1_000])
        {:ok, _cache_pid} = Cachex.start_link(@cachex_adapter, expiration: Cachex.Spec.expiration(default: 1_000))

      {:ok, _} ->
        Application.put_env(:commanded_uniqueness_middleware, :ttl, 1_000)
    end

    on_exit(fn ->
      Enum.each([:adapter, :ttl], &Application.delete_env(:commanded_uniqueness_middleware, &1))
      Application.put_all_env(commanded_uniqueness_middleware: app_settings)
    end)

    :ok
  end

  setup do
    on_exit(fn ->
      Cachex.clear(@cachex_adapter)
    end)

    key = :field_name
    value = Faker.Lorem.sentence()
    owner = Faker.UUID.v4()
    partition = Faker.String.base64()

    assert :ok == @cachex_adapter.claim(key, value, owner, partition)

    [key: key, value: value, owner: owner, partition: partition]
  end

  describe "child_spec/0" do
    test "should return a correct child spec" do
      assert @cachex_adapter.child_spec ==
               %{
                 id: @cachex_adapter,
                 start: {Cachex, :start, [@cachex_adapter, [expiration: Cachex.Spec.expiration(default: 1_000)]]}
               }
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
      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})
    end

    test "should return :ok if {key, value} key exists and has owner as a value",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @cachex_adapter.claim(key, value, owner, partition)

      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})
    end

    test "should return {:error, :already_exists} if {key, value} key exists but has a different than owner value",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      other = Faker.UUID.v4()

      assert {:error, :already_exists} ==
               @cachex_adapter.claim(key, value, other, partition)

      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})

      refute other == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, other})
    end

    test "should release an old {key, value} key if the same owner claims a new value for the same key",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      new_value = Faker.Lorem.sentence()

      assert :ok == @cachex_adapter.claim(key, new_value, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, new_value})
      assert new_value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})
    end
  end

  describe "claim/3" do
    setup %{
      key: key,
      value: value,
      owner: owner,
      partition: partition
    } do
      @cachex_adapter.release(key, value, owner, partition)
      @cachex_adapter.claim(key, value, partition)
    end

    test "should return :ok and create a cache record under {@by_value_key, @partition, key, value} key",
         %{
           key: key,
           value: value,
           partition: partition
         } do
      assert {:ok, true} ==
               Cachex.exists?(@cachex_adapter, {partition, @by_value_key, key, value})
    end

    test "should return {:error, :already_exists} if {key, value} key exists",
         %{
           key: key,
           value: value,
           partition: partition
         } do
      assert {:error, :already_exists} == @cachex_adapter.claim(key, value, partition)
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
      assert :ok == @cachex_adapter.release(key, value, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})
    end

    test "should return :ok if no given value exists", %{partition: partition} do
      key = :other_field_name
      value = Faker.Lorem.sentence()
      owner = Faker.UUID.v4()

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})

      assert :ok == @cachex_adapter.release(key, value, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})
    end

    test "should return {:error, :claimed_by_another_owner} if claimed with another owner",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      other = Faker.UUID.v4()

      assert {:error, :claimed_by_another_owner} ==
               @cachex_adapter.release(key, value, other, partition)

      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})
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
      assert :ok == @cachex_adapter.release_by_owner(key, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})
    end

    test "should return :ok if no given value exists", %{partition: partition} do
      key = :other_field_name
      owner = Faker.UUID.v4()

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})

      assert :ok == @cachex_adapter.release_by_owner(key, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})
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
      assert :ok == @cachex_adapter.release(key, value, owner, partition)

      assert :ok = @cachex_adapter.claim(key, value, partition)

      assert :ok == @cachex_adapter.release_by_value(key, value, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
    end

    test "should return :ok and delete {key, owner} and {key, value} if they are exists and where claimed by claim/4",
         %{
           key: key,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @cachex_adapter.release_by_value(key, value, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, key, owner})
    end

    test "should return :ok if no given value claimed", %{partition: partition} do
      key = :other_field_name
      value = Faker.UUID.v4()

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, key, value})

      assert :ok == @cachex_adapter.release_by_value(key, value, partition)
    end
  end
end

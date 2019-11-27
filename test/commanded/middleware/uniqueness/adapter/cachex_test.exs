defmodule Commanded.Middleware.Uniqueness.Adapter.CachexTest do
  use ExUnit.Case

  require Cachex.Spec

  @cachex_adapter Commanded.Middleware.Uniqueness.Adapter.Cachex

  @by_value_key :bv
  @by_owner_key :bo

  setup_all do
    app_settings = Application.get_all_env(:commanded_uniqueness_middleware)

    case Cachex.get(@cachex_adapter, :anything) do
      {:error, :no_cache} ->
        Application.put_all_env(
          commanded_uniqueness_middleware: [adapter: @cachex_adapter, ttl: 1_000]
        )

        {:ok, _} =
          Cachex.start_link(@cachex_adapter, expiration: Cachex.Spec.expiration(default: 1_000))

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

    id = :field_name
    value = Faker.Lorem.sentence()
    owner = UUID.uuid4()
    partition = Faker.String.base64()

    assert :ok == @cachex_adapter.claim(id, value, owner, partition)

    [id: id, value: value, owner: owner, partition: partition]
  end

  describe "child_spec/0" do
    test "should return a correct child spec" do
      assert @cachex_adapter.child_spec ==
               %{
                 id: @cachex_adapter,
                 start:
                   {Cachex, :start,
                    [@cachex_adapter, [expiration: Cachex.Spec.expiration(default: 1_000)]]}
               }
    end
  end

  describe "claim/4" do
    test "should return :ok and put into cache owner under {@by_value_key, @partition, id, value} key and value under {partition, @by_owner_key, id, owner} key if no {id, value} key exists",
         %{
           id: id,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})
    end

    test "should return :ok if {id, value} key exists and has owner as a value",
         %{
           id: id,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @cachex_adapter.claim(id, value, owner, partition)

      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})
    end

    test "should return {:error, :already_exists} if {id, value} key exists but has a different than owner value",
         %{
           id: id,
           value: value,
           owner: owner,
           partition: partition
         } do
      other = UUID.uuid4()

      assert {:error, :already_exists} ==
               @cachex_adapter.claim(id, value, other, partition)

      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})

      refute other == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, other})
    end

    test "should release an old {id, value} key if the same owner claims a new value for the same id",
         %{
           id: id,
           value: value,
           owner: owner,
           partition: partition
         } do
      new_value = Faker.Lorem.sentence()

      assert :ok == @cachex_adapter.claim(id, new_value, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, new_value})
      assert new_value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})
    end
  end

  describe "release/4" do
    test "should return :ok and delete {id, owner} and {id, value} if they exist",
         %{
           id: id,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @cachex_adapter.release(id, value, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})
    end

    test "should return :ok if no given value exists", %{partition: partition} do
      id = :other_field_name
      value = Faker.Lorem.sentence()
      owner = UUID.uuid4()

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})

      assert :ok == @cachex_adapter.release(id, value, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})
    end

    test "should return {:error, :claimed_by_another_owner} if claimed with another owner",
         %{
           id: id,
           value: value,
           owner: owner,
           partition: partition
         } do
      other = UUID.uuid4()

      assert {:error, :claimed_by_another_owner} ==
               @cachex_adapter.release(id, value, other, partition)

      assert owner == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert value == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})
    end
  end

  describe "release/3" do
    test "should return :ok and delete {id, owner} and {id, value} if they are exists",
         %{
           id: id,
           value: value,
           owner: owner,
           partition: partition
         } do
      assert :ok == @cachex_adapter.release(id, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_value_key, id, value})
      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})
    end

    test "should return :ok if no given value exists", %{partition: partition} do
      id = :other_field_name
      owner = UUID.uuid4()

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})

      assert :ok == @cachex_adapter.release(id, owner, partition)

      assert nil == Cachex.get!(@cachex_adapter, {partition, @by_owner_key, id, owner})
    end
  end
end

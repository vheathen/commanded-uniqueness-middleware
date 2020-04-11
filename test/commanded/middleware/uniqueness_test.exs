defmodule Commanded.Middleware.UniquenessTest do
  use ExUnit.Case, async: false
  doctest Commanded.Middleware.Uniqueness

  require Cachex.Spec

  alias Commanded.Middleware.Pipeline

  alias Commanded.Middleware.Uniqueness

  @cachex_adapter Commanded.Middleware.Uniqueness.Adapter.Cachex

  @by_value_key :bv

  setup_all do
    case Cachex.get(@cachex_adapter, :anything) do
      {:error, :no_cache} ->
        Application.put_env(:commanded_uniqueness_middleware, :adapter, @cachex_adapter)

        {:ok, _} =
          Cachex.start_link(@cachex_adapter, expiration: Cachex.Spec.expiration(default: 100))

      {:ok, _} ->
        true
    end

    :ok
  end

  setup do
    on_exit(fn ->
      Cachex.clear(@cachex_adapter)
    end)
  end

  describe "default_partition/0" do
    @describetag :unit

    test "should return current default partition" do
      assert Commanded.Middleware.Uniqueness == Uniqueness.default_partition()
    end
  end

  describe "Uniqueness middleware, TestCommandSimple should" do
    @describetag :unit

    test "continue if field value unique" do
      cmd = %TestCommandSimple{id: 1, name: "NewName"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      cmd = %TestCommandSimple{id: 2, name: "NewName2"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end

    test "continue if field value in in another case" do
      cmd = %TestCommandSimple{id: 1, name: "NewName"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandSimple{id: 2, name: "newnaME"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end

    test "should halt if field value not unique" do
      cmd = %TestCommandSimple{id: 1, name: "NewName"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandSimple{id: 2, name: "NewName"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response == {:error, :validation_failure, [{:name, "has already been taken"}]}
    end
  end

  describe "Uniqueness middleware, TestCommandSimpleLabel should" do
    @describetag :unit

    test "should halt if field value not unique with custom label" do
      cmd = %TestCommandSimpleLabel{id: 1, name: "NewName"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandSimpleLabel{id: 2, name: "NewName"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response ==
               {:error, :validation_failure, [{:another_label, "has already been taken"}]}
    end
  end

  describe "Uniqueness middleware, TestCommandExternalCheck should" do
    @describetag :unit

    test "should continue if :is_unique option function returns true" do
      cmd = %TestCommandExternalCheck{id: 1, name: "NewName", email: "one@example.com"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      cmd = %TestCommandExternalCheck{id: 2, name: "OtherName", email: "two@example.com"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end

    test "should halt if :is_unique option function returns false" do
      cmd = %TestCommandExternalCheck{id: 1, name: "NewName", email: "one@example.com"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert Cachex.get!(
               @cachex_adapter,
               {Commanded.Middleware.Uniqueness, @by_value_key, :name, "NewName"}
             ) == 1

      assert Cachex.get!(
               @cachex_adapter,
               {Commanded.Middleware.Uniqueness, @by_value_key, :email, "one@example.com"}
             ) == 1

      #
      cmd = %TestCommandExternalCheck{
        id: 2,
        name: "ExternallyTakenName",
        email: "two@example.com"
      }

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response ==
               {:error, :validation_failure, [{:name, "has already been taken"}]}

      assert Cachex.get!(
               @cachex_adapter,
               {Commanded.Middleware.Uniqueness, @by_value_key, :name, "ExternallyTakenName"}
             ) == nil

      assert Cachex.get!(
               @cachex_adapter,
               {Commanded.Middleware.Uniqueness, @by_value_key, :email, "two@example.com"}
             ) == nil
    end
  end

  describe "Uniqueness middleware, TestCommandSimpleCaseInsensitive should" do
    @describetag :unit

    test "should continue if field value unique" do
      cmd = %TestCommandSimpleCaseInsensitive{id: 1, name: "NewName"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      cmd = %TestCommandSimpleCaseInsensitive{id: 2, name: "NewName2"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end

    test "halt if field value not unique even if it's in another case" do
      cmd = %TestCommandSimpleCaseInsensitive{id: 1, name: "NewName"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandSimpleCaseInsensitive{id: 2, name: "newnaME"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response == {:error, :validation_failure, [{:name, "has already been taken"}]}
    end
  end

  describe "Uniqueness middleware, TestCommandMulti should" do
    @describetag :unit

    test "continue if field value unique" do
      cmd = %TestCommandMulti{id: 1, name: "NewName", email: "one@example.com"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMulti{id: 2, name: "newname", email: "another@example.com"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end

    test "halt if 'name' field value not unique" do
      cmd = %TestCommandMulti{id: 1, name: "NewName", email: "one@example.com"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMulti{id: 2, name: "NewName", email: "another@example.com"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response == {:error, :validation_failure, [{:name, "has already been taken"}]}
    end

    test "halt if 'email' field value not unique" do
      cmd = %TestCommandMulti{id: 1, name: "NewName", email: "one@example.com"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMulti{id: 2, name: "newname", email: "one@example.com"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response == {:error, :validation_failure, [{:email, "has already been taken"}]}
    end

    test "halt if 'email' field value not unique even in another case" do
      cmd = %TestCommandMulti{id: 1, name: "NewName", email: "one@example.com"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMulti{id: 2, name: "newname", email: "oNe@EXamPLE.com"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response == {:error, :validation_failure, [{:email, "has already been taken"}]}
    end

    test "halt if both fields value are not unique" do
      cmd = %TestCommandMulti{id: 1, name: "NewName", email: "one@example.com"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMulti{id: 2, name: "NewName", email: "oNe@EXamPLE.com"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response ==
               {:error, :validation_failure,
                [{:email, "has already been taken"}, {:name, "has already been taken"}]}
    end

    test "halt and release 'name' if the 'email' field value is not unique" do
      cmd = %TestCommandMulti{id: 1, name: "NewName", email: "one@example.com"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMulti{id: 2, name: "OtherName", email: "oNe@EXamPLE.com"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response ==
               {:error, :validation_failure, [{:email, "has already been taken"}]}

      cmd = %TestCommandSimple{id: 3, name: "OtherName"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end
  end

  describe "Uniqueness middleware, TestCommandMultiConcat should" do
    @describetag :unit

    test "continue if both fields values are unique" do
      cmd = %TestCommandMultiConcat{
        id: 1,
        name: "NewName",
        email: "one@example.com",
        description: "one"
      }

      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMultiConcat{
        id: 2,
        name: "newname",
        email: "another@example.com",
        description: "two"
      }

      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end

    test "continue if on of the fields value is unique" do
      cmd = %TestCommandMultiConcat{
        id: 1,
        name: "NewName",
        email: "one@example.com",
        description: "one"
      }

      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMultiConcat{
        id: 2,
        name: "newname",
        email: "one@example.com",
        description: "two"
      }

      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end

    test "halt if both fields value are not unique" do
      cmd = %TestCommandMultiConcat{
        id: 1,
        name: "NewName",
        email: "one@example.com",
        description: "one"
      }

      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMultiConcat{
        id: 2,
        name: "NewName",
        email: "one@example.com",
        description: "two"
      }

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response ==
               {:error, :validation_failure, [{[:name, :email], "not unique"}]}
    end

    test "halt if both fields value are not unique despite email case" do
      cmd = %TestCommandMultiConcat{
        id: 1,
        name: "NewName",
        email: "one@example.com",
        description: "one"
      }

      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMultiConcat{
        id: 2,
        name: "NewName",
        email: "oNe@EXamPLE.com",
        description: "two"
      }

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response ==
               {:error, :validation_failure, [{[:name, :email], "not unique"}]}
    end

    test "halt and release composit fields value if the 'description' field value is not unique" do
      cmd = %TestCommandMultiConcat{
        id: 1,
        name: "NewName",
        email: "one@example.com",
        description: "same description"
      }

      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandMultiConcat{
        id: 2,
        name: "OtherName",
        email: "other@example.com",
        description: "same description"
      }

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response ==
               {:error, :validation_failure, [{:description, "not unique"}]}

      #
      cmd = %TestCommandMultiConcat{
        id: 3,
        name: "OtherName",
        email: "other@example.com",
        description: "another description"
      }

      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end
  end

  describe "Uniqueness middleware: If :partition option set" do
    @describetag :unit

    setup do
      app_settings = Application.get_all_env(:commanded_uniqueness_middleware)

      Application.put_env(:commanded_uniqueness_middleware, :use_command_as_partition, true)

      on_exit(fn ->
        Application.delete_env(:commanded_uniqueness_middleware, :use_command_as_partition)
        Application.put_all_env(commanded_uniqueness_middleware: app_settings)
      end)
    end

    test "via general settings to :command then it should check against and put values to the command-related partitions" do
      cmd = %TestCommandSimple{id: 1, name: "NewName"}

      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      cmd = %TestCommandMulti{id: 2, name: "NewName", email: "some@email.com"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert Cachex.get!(
               @cachex_adapter,
               {TestCommandSimple, @by_value_key, :name, "NewName"}
             ) == 1

      assert Cachex.get!(
               @cachex_adapter,
               {TestCommandMulti, @by_value_key, :name, "NewName"}
             ) == 2
    end

    test "via general settings to anything but in local opts to the specific partition then it should check against and put values to the same partition" do
      cmd = %TestCommandPartition1{id: 1, name: "NewName"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandPartition2{id: 2, name: "NewName"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response == {:error, :validation_failure, [{:name, "has already been taken"}]}
    end
  end

  describe "Uniqueness middleware, TestCommandSimpleNoOwner with random owner should" do
    @describetag :unit

    test "continue if field value unique" do
      cmd = %TestCommandSimpleNoOwner{id: 1, name: "NewName"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      cmd = %TestCommandSimpleNoOwner{id: 2, name: "NewName2"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end

    test "continue if field value in in another case" do
      cmd = %TestCommandSimpleNoOwner{id: 1, name: "NewName"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandSimpleNoOwner{id: 2, name: "newnaME"}
      assert %Pipeline{halted: false} = Uniqueness.before_dispatch(%Pipeline{command: cmd})
    end

    test "should halt if field value not unique" do
      cmd = %TestCommandSimpleNoOwner{id: 1, name: "NewName"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandSimpleNoOwner{id: 2, name: "NewName"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response == {:error, :validation_failure, [{:name, "has already been taken"}]}
    end
  end

  describe "Uniqueness middleware, TestCommandSimpleNoOwnerBad should" do
    @describetag :unit

    test "raise error because of no_owner can only be false or true" do
      assert_raise ArgumentError, fn ->
        cmd = %TestCommandSimpleNoOwnerBad{id: 1, name: "NewName"}
        Uniqueness.before_dispatch(%Pipeline{command: cmd})
      end

      assert_raise ArgumentError, fn ->
        cmd = %TestCommandSimpleNoOwnerBad{id: 2, name: "NewName2"}
        Uniqueness.before_dispatch(%Pipeline{command: cmd})
      end
    end
  end

  describe "Uniqueness middleware, TestCommandSimpleLabelNoOwner should" do
    @describetag :unit

    test "should halt if field value not unique with custom label" do
      cmd = %TestCommandSimpleLabelNoOwner{id: 1, name: "NewName"}

      assert %Pipeline{halted: false, response: nil} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      #
      cmd = %TestCommandSimpleLabelNoOwner{id: 2, name: "NewName"}

      assert %Pipeline{halted: true, response: response} =
               Uniqueness.before_dispatch(%Pipeline{command: cmd})

      assert response ==
               {:error, :validation_failure, [{:another_label, "has already been taken"}]}
    end
  end
end

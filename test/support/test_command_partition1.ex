defmodule TestCommandPartition1 do
  @moduledoc false

  defstruct [
    :id,
    :name
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: TestCommandPartition1 do
  def unique(%TestCommandPartition1{id: id}),
    do: [
      {:name, "has already been taken", id, partition: "SomeCommonPartition"}
    ]
end

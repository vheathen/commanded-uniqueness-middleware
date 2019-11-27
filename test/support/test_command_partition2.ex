defmodule TestCommandPartition2 do
  defstruct [
    :id,
    :name
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: TestCommandPartition2 do
  def unique(%TestCommandPartition2{id: id}),
    do: [
      {:name, "has already been taken", id, partition: "SomeCommonPartition"}
    ]
end

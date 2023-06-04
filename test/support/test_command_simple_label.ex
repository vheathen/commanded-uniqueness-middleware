defmodule TestCommandSimpleLabel do
  @moduledoc false

  defstruct [
    :id,
    :name
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: TestCommandSimpleLabel do
  def unique(%TestCommandSimpleLabel{id: id}),
    do: [
      {:name, "has already been taken", id, label: :another_label}
    ]
end

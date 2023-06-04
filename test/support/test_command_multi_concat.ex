defmodule TestCommandMultiConcat do
  @moduledoc false

  defstruct [
    :id,
    :name,
    :email,
    :description
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: TestCommandMultiConcat do
  def unique(%TestCommandMultiConcat{id: id}),
    do: [
      {[:name, :email], "not unique", id, ignore_case: [:email]},
      {:description, "not unique", id}
    ]
end

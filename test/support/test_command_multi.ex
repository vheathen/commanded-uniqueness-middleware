defmodule TestCommandMulti do
  @moduledoc false
  
  defstruct [
    :id,
    :name,
    :email
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: TestCommandMulti do
  def unique(%TestCommandMulti{id: id}),
    do: [
      {:name, "has already been taken", id},
      {:email, "has already been taken", id, ignore_case: true}
    ]
end

defmodule TestCommandSimpleNoOwner do
  defstruct [
    :id,
    :name
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: TestCommandSimpleNoOwner do
  def unique(%TestCommandSimpleNoOwner{}),
    do: [
      {:name, "has already been taken", Faker.Random.Elixir.random_bytes(16), no_owner: true}
    ]
end

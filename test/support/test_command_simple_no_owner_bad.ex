defmodule TestCommandSimpleNoOwnerBad do
  @moduledoc false

  defstruct [
    :id,
    :name
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: TestCommandSimpleNoOwnerBad do
  def unique(%TestCommandSimpleNoOwnerBad{}),
    do: [
      {:name, "has already been taken", Faker.Random.Elixir.random_bytes(16), no_owner: :yes}
    ]
end

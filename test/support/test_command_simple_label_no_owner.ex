defmodule TestCommandSimpleLabelNoOwner do
  @moduledoc false

  defstruct [
    :id,
    :name
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: TestCommandSimpleLabelNoOwner do
  def unique(%TestCommandSimpleLabelNoOwner{}),
    do: [
      {:name, "has already been taken", Faker.random_bytes(16),
       label: :another_label, no_owner: true}
    ]
end

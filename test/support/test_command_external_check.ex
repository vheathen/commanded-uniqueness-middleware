defmodule TestCommandExternalCheck do
  defstruct [
    :id,
    :name,
    :email
  ]
end

defimpl Commanded.Middleware.Uniqueness.UniqueFields, for: TestCommandExternalCheck do
  def unique(%TestCommandExternalCheck{id: id}),
    do: [
      {:email, "has already been taken", id, ignore_case: true},
      {:name, "has already been taken", id, is_unique: &is_free/4}
    ]

  def is_free(_field, value, _owner, _opts), do: !String.starts_with?(value, "ExternallyTaken")
end

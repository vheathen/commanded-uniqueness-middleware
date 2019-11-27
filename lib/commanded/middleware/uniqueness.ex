defmodule Commanded.Middleware.Uniqueness do
  @behaviour Commanded.Middleware

  @moduledoc """
  Documentation for Commanded.Middleware.Uniqueness.
  """

  defprotocol UniqueFields do
    @fallback_to_any true
    @doc """
    Returns unique fields for the command as a list of
    tuples as: `{field_name :: atom() | list(atom), error_message :: String.t(), owner :: term, opts :: keyword()}`,
    where `opts` might contain none, one or multiple options:
    `ignore_case: true` or `ignore_case: [:email, :username]` for multi-fields entities - binary-based
    fields are downcased before comparison
    `:label` - use this atom as error label
    `:is_unique` - `(term, String.t(), term, keyword() -> boolean())`
    `:partition` - use to set custom partition name
    """
    def unique(command)
  end

  defimpl UniqueFields, for: Any do
    def unique(_command), do: []
  end

  alias Commanded.Middleware.Pipeline

  import Pipeline

  def before_dispatch(%Pipeline{command: command} = pipeline) do
    case ensure_uniqueness(command) do
      :ok ->
        pipeline

      {:error, errors} ->
        pipeline
        |> respond({:error, :validation_failure, errors})
        |> halt()
    end
  end

  def after_dispatch(pipeline), do: pipeline
  def after_failure(pipeline), do: pipeline

  defp ensure_uniqueness(command) do
    ensure_uniqueness(command, get_adapter())
  end

  defp ensure_uniqueness(_command, nil) do
    require Logger

    Logger.debug("No unique cache adapter defined in config! Assume the value is unique.",
      label: "#{__MODULE__}"
    )

    :ok
  end

  defp ensure_uniqueness(command, adapter) do
    command
    |> UniqueFields.unique()
    |> ensure_uniqueness(command, adapter, [], [])
  end

  defp ensure_uniqueness([record | rest], command, adapter, errors, to_release) do
    {_, error_message, _, _} = record = expand_record(record)
    label = get_label(record)

    {errors, to_release} =
      case claim(record, command, adapter) do
        {id, value, owner, partition} ->
          to_release = [{id, value, owner, partition} | to_release]

          {errors, to_release}

        _ ->
          errors = [{label, error_message} | errors]

          {errors, to_release}
      end

    ensure_uniqueness(rest, command, adapter, errors, to_release)
  end

  defp ensure_uniqueness([], _command, _adapter, [], _to_release), do: :ok
  defp ensure_uniqueness([], _command, _adapter, errors, []), do: {:error, errors}

  defp ensure_uniqueness([], command, adapter, errors, to_release) do
    Enum.each(to_release, &release(&1, adapter))

    ensure_uniqueness([], command, adapter, errors, [])
  end

  defp claim({fields, _, owner, opts}, command, adapter)
       when is_list(fields) do
    value =
      fields
      |> Enum.reduce([], fn field_name, acc ->
        ignore_case = Keyword.get(opts, :ignore_case)

        [get_field_value(command, field_name, ignore_case) | acc]
      end)

    key = Module.concat(fields)
    command = %{key => value}
    entity = {key, "", owner, opts}
    claim(entity, command, adapter)
  end

  defp claim({field_name, _, owner, opts}, command, adapter)
       when is_atom(field_name) do
    ignore_case? = Keyword.get(opts, :ignore_case)
    value = get_field_value(command, field_name, ignore_case?)
    partition = get_partition(opts, command)

    case adapter.claim(field_name, value, owner, partition) do
      :ok ->
        case external_check(field_name, value, owner, command, opts) do
          true -> {field_name, value, owner, partition}
          _ -> {:error, :external_check_failed}
        end

      error ->
        error
    end
  end

  defp release({id, value, owner, partition}, adapter),
    do: adapter.release(id, value, owner, partition)

  defp external_check(field_name, value, owner, command, opts) when is_list(opts),
    do: external_check(field_name, value, owner, command, get_external_checker(opts))

  defp external_check(field_name, value, owner, _command, {checker, opts})
       when is_function(checker, 4),
       do: checker.(field_name, value, owner, opts)

  defp external_check(_field_name, _value, _owner, _command, {nil, _}), do: true

  defp external_check(_field_name, _value, _owner, %{__struct__: module}, _opts),
    do:
      raise(
        "#{__MODULE__}: The ':is_unique' option for the #{module} command has incorrect value. It should be only a function with 4 arguments"
      )

  defp expand_record({one, two, three}), do: {one, two, three, []}
  defp expand_record(entity), do: entity

  defp get_field_value(command, field_name, ignore_case)

  defp get_field_value(command, field_name, ignore_case) when is_list(ignore_case),
    do: get_field_value(command, field_name, Enum.any?(ignore_case, &(&1 == field_name)))

  defp get_field_value(command, field_name, field_name),
    do: get_field_value(command, field_name, true)

  defp get_field_value(command, field_name, true),
    do: command |> get_field_value(field_name, false) |> downcase()

  defp get_field_value(command, field_name, _), do: Map.get(command, field_name)

  defp downcase(value) when is_binary(value), do: String.downcase(value)
  defp downcase(value), do: value

  defp get_label({entity, _, _, opts}), do: Keyword.get(opts, :label, entity)

  defp get_external_checker(opts), do: {Keyword.get(opts, :is_unique), opts}

  defp get_partition(opts, command), do: get_partition(opts, command, get_default_partition())

  defp get_partition(opts, %command{}, :command), do: Keyword.get(opts, :partition, command)
  defp get_partition(opts, _, _), do: Keyword.get(opts, :partition, __MODULE__)

  defp get_adapter, do: Application.get_env(:commanded_uniqueness_middleware, :adapter)

  defp get_default_partition,
    do: Application.get_env(:commanded_uniqueness_middleware, :default_partition)
end

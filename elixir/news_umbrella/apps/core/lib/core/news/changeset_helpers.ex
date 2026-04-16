defmodule Core.News.ChangesetHelpers do
  @moduledoc false

  import Ecto.Changeset

  @slug_regex ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/

  def trim_string_fields(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      update_change(acc, field, fn
        value when is_binary(value) -> String.trim(value)
        value -> value
      end)
    end)
  end

  def validate_slug(changeset, field, opts \\ []) do
    min = Keyword.get(opts, :min, 2)
    max = Keyword.get(opts, :max, 120)

    changeset
    |> validate_length(field, min: min, max: max)
    |> validate_format(field, @slug_regex,
      message: "must use lowercase letters, numbers and dashes only"
    )
  end
end

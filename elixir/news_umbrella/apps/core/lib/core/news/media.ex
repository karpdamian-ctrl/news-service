defmodule Core.News.Media do
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.News.ChangesetHelpers

  @types ~w(image video audio document)
  @path_regex ~r"^/uploads/news/[a-z0-9][a-z0-9-]*\.(jpg|jpeg|png|webp|gif)$"i
  @mime_regex ~r|^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$|i

  schema "media" do
    field(:type, :string)
    field(:path, :string)
    field(:mime_type, :string)
    field(:size_bytes, :integer)
    field(:alt_text, :string)
    field(:caption, :string)
    field(:uploaded_by, :string)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(media, attrs) do
    media
    |> cast(attrs, [:type, :path, :mime_type, :size_bytes, :alt_text, :caption, :uploaded_by])
    |> ChangesetHelpers.trim_string_fields([
      :type,
      :path,
      :mime_type,
      :alt_text,
      :caption,
      :uploaded_by
    ])
    |> validate_required([:type, :path])
    |> validate_inclusion(:type, @types)
    |> validate_length(:path, max: 255)
    |> validate_format(:path, @path_regex, message: "must point to /uploads/news/<file>")
    |> validate_length(:mime_type, max: 120)
    |> validate_format(:mime_type, @mime_regex)
    |> validate_number(:size_bytes,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 50_000_000
    )
    |> validate_length(:alt_text, max: 180)
    |> validate_length(:caption, max: 3_000)
    |> validate_length(:uploaded_by, min: 3, max: 120)
  end
end

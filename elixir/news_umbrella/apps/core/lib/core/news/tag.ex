defmodule Core.News.Tag do
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.News.ChangesetHelpers

  schema "tags" do
    field(:name, :string)
    field(:slug, :string)

    many_to_many(:articles, Core.News.Article,
      join_through: "article_tags",
      on_replace: :delete
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :slug])
    |> ChangesetHelpers.trim_string_fields([:name, :slug])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2, max: 50)
    |> ChangesetHelpers.validate_slug(:slug, max: 80)
    |> unique_constraint(:slug)
  end
end

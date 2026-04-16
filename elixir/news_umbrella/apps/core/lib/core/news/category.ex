defmodule Core.News.Category do
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.News.ChangesetHelpers

  schema "categories" do
    field(:name, :string)
    field(:slug, :string)
    field(:description, :string)

    belongs_to(:parent, __MODULE__)
    has_many(:children, __MODULE__, foreign_key: :parent_id)

    many_to_many(:articles, Core.News.Article,
      join_through: "article_categories",
      on_replace: :delete
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :description, :parent_id])
    |> ChangesetHelpers.trim_string_fields([:name, :slug, :description])
    |> validate_required([:name, :slug])
    |> validate_length(:name, min: 2, max: 80)
    |> ChangesetHelpers.validate_slug(:slug, max: 120)
    |> validate_length(:description, max: 1_000)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:parent_id)
  end
end

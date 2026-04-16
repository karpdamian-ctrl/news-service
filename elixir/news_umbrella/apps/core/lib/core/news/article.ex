defmodule Core.News.Article do
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.News.ChangesetHelpers

  @statuses ~w(draft review scheduled published archived)

  schema "articles" do
    field(:title, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:content, :string)
    field(:status, :string, default: "draft")
    field(:published_at, :utc_datetime)
    field(:is_breaking, :boolean, default: false)
    field(:view_count, :integer, default: 0)

    field(:author, :string)
    belongs_to(:featured_image, Core.News.Media)

    many_to_many(:categories, Core.News.Category,
      join_through: "article_categories",
      on_replace: :delete
    )

    many_to_many(:tags, Core.News.Tag,
      join_through: "article_tags",
      on_replace: :delete
    )

    has_many(:revisions, Core.News.ArticleRevision)

    timestamps(type: :utc_datetime)
  end

  def changeset(article, attrs) do
    article
    |> cast(attrs, [
      :title,
      :slug,
      :description,
      :content,
      :status,
      :published_at,
      :is_breaking,
      :view_count,
      :author,
      :featured_image_id
    ])
    |> ChangesetHelpers.trim_string_fields([
      :title,
      :slug,
      :description,
      :content,
      :status,
      :author
    ])
    |> validate_required([:title, :slug, :content, :status, :author])
    |> validate_length(:title, min: 5, max: 180)
    |> ChangesetHelpers.validate_slug(:slug, max: 200)
    |> validate_length(:description, max: 1_000)
    |> validate_length(:content, min: 20, max: 120_000)
    |> validate_length(:author, min: 3, max: 120)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:view_count,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 10_000_000
    )
    |> validate_published_at_when_published()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:featured_image_id)
  end

  defp validate_published_at_when_published(changeset) do
    status = get_field(changeset, :status)
    published_at = get_field(changeset, :published_at)

    if status == "published" and is_nil(published_at) do
      add_error(changeset, :published_at, "is required when status is published")
    else
      changeset
    end
  end
end

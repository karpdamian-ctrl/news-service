defmodule Core.News.ArticleRevision do
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.News.ChangesetHelpers

  schema "article_revisions" do
    field(:title, :string)
    field(:description, :string)
    field(:content, :string)
    field(:change_note, :string)

    field(:changed_by, :string)
    belongs_to(:article, Core.News.Article)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(revision, attrs) do
    revision
    |> cast(attrs, [:title, :description, :content, :change_note, :article_id, :changed_by])
    |> ChangesetHelpers.trim_string_fields([
      :title,
      :description,
      :content,
      :change_note,
      :changed_by
    ])
    |> validate_required([:title, :content, :article_id, :changed_by])
    |> validate_length(:title, min: 5, max: 180)
    |> validate_length(:description, max: 1_000)
    |> validate_length(:content, min: 20, max: 120_000)
    |> validate_length(:change_note, max: 500)
    |> validate_length(:changed_by, min: 3, max: 120)
    |> foreign_key_constraint(:article_id)
  end
end

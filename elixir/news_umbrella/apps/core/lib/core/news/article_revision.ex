defmodule Core.News.ArticleRevision do
  use Ecto.Schema
  import Ecto.Changeset
  alias Core.News.ChangesetHelpers

  schema "article_revisions" do
    field(:title, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:content, :string)
    field(:status, :string)
    field(:published_at, :utc_datetime)
    field(:is_breaking, :boolean, default: false)
    field(:view_count, :integer, default: 0)
    field(:author, :string)
    field(:featured_image_id, :integer)
    field(:category_ids, {:array, :integer}, default: [])
    field(:tag_ids, {:array, :integer}, default: [])
    field(:modified_at, :utc_datetime)
    field(:change_note, :string)

    field(:changed_by, :string)
    belongs_to(:article, Core.News.Article)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(revision, attrs) do
    revision
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
      :featured_image_id,
      :category_ids,
      :tag_ids,
      :modified_at,
      :change_note,
      :article_id,
      :changed_by
    ])
    |> ChangesetHelpers.trim_string_fields([
      :title,
      :slug,
      :description,
      :content,
      :status,
      :author,
      :change_note,
      :changed_by
    ])
    |> put_default_modified_at()
    |> validate_required([
      :title,
      :slug,
      :content,
      :status,
      :author,
      :article_id,
      :changed_by,
      :modified_at
    ])
    |> validate_length(:title, min: 5, max: 180)
    |> ChangesetHelpers.validate_slug(:slug, max: 200)
    |> validate_length(:description, max: 1_000)
    |> validate_length(:content, min: 20, max: 120_000)
    |> validate_inclusion(:status, ~w(draft review scheduled published archived))
    |> validate_length(:author, min: 3, max: 120)
    |> validate_number(:view_count,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 10_000_000
    )
    |> validate_assoc_ids(:category_ids)
    |> validate_assoc_ids(:tag_ids)
    |> validate_length(:change_note, max: 500)
    |> validate_length(:changed_by, min: 3, max: 120)
    |> foreign_key_constraint(:article_id)
    |> foreign_key_constraint(:featured_image_id)
  end

  defp put_default_modified_at(changeset) do
    case get_field(changeset, :modified_at) do
      nil -> put_change(changeset, :modified_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end

  defp validate_assoc_ids(changeset, field) do
    validate_change(changeset, field, fn ^field, values ->
      if is_list(values) and Enum.all?(values, &(is_integer(&1) and &1 > 0)) do
        []
      else
        [{field, "must contain valid positive integer ids"}]
      end
    end)
  end
end

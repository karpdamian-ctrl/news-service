defmodule Core.Repo.Migrations.ExpandArticleRevisionSnapshot do
  use Ecto.Migration

  def up do
    alter table(:article_revisions) do
      add(:slug, :string)
      add(:status, :string)
      add(:published_at, :utc_datetime)
      add(:is_breaking, :boolean, null: false, default: false)
      add(:view_count, :integer, null: false, default: 0)
      add(:author, :string)
      add(:featured_image_id, references(:media, on_delete: :nilify_all))
      add(:category_ids, {:array, :integer}, null: false, default: [])
      add(:tag_ids, {:array, :integer}, null: false, default: [])
      add(:modified_at, :utc_datetime)
    end

    execute("UPDATE article_revisions SET slug = '' WHERE slug IS NULL")
    execute("UPDATE article_revisions SET status = 'draft' WHERE status IS NULL")
    execute("UPDATE article_revisions SET author = changed_by WHERE author IS NULL")
    execute("UPDATE article_revisions SET modified_at = inserted_at WHERE modified_at IS NULL")

    alter table(:article_revisions) do
      modify(:slug, :string, null: false)
      modify(:status, :string, null: false)
      modify(:author, :string, null: false)
      modify(:modified_at, :utc_datetime, null: false)
    end

    create(index(:article_revisions, [:featured_image_id]))
    create(index(:article_revisions, [:status]))
    create(index(:article_revisions, [:slug]))
    create(index(:article_revisions, [:modified_at]))
  end

  def down do
    drop_if_exists(index(:article_revisions, [:modified_at]))
    drop_if_exists(index(:article_revisions, [:slug]))
    drop_if_exists(index(:article_revisions, [:status]))
    drop_if_exists(index(:article_revisions, [:featured_image_id]))

    alter table(:article_revisions) do
      remove(:modified_at)
      remove(:tag_ids)
      remove(:category_ids)
      remove(:featured_image_id)
      remove(:author)
      remove(:view_count)
      remove(:is_breaking)
      remove(:published_at)
      remove(:status)
      remove(:slug)
    end
  end
end

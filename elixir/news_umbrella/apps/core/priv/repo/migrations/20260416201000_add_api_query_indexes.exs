defmodule Core.Repo.Migrations.AddApiQueryIndexes do
  use Ecto.Migration

  def change do
    create_if_not_exists index(:categories, [:inserted_at])
    create_if_not_exists index(:categories, [:name])

    create_if_not_exists index(:tags, [:inserted_at])
    create_if_not_exists index(:tags, [:name])

    create_if_not_exists index(:media, [:inserted_at])
    create_if_not_exists index(:media, [:type])
    create_if_not_exists index(:media, [:mime_type])
    create_if_not_exists index(:media, [:uploaded_by])

    create_if_not_exists index(:articles, [:inserted_at])
    create_if_not_exists index(:articles, [:status])
    create_if_not_exists index(:articles, [:published_at])
    create_if_not_exists index(:articles, [:author])
    create_if_not_exists index(:articles, [:is_breaking])
    create_if_not_exists index(:articles, [:view_count])

    create_if_not_exists index(:article_revisions, [:inserted_at])
    create_if_not_exists index(:article_revisions, [:changed_by])
  end
end

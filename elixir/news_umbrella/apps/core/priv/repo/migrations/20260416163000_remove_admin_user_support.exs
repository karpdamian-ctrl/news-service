defmodule Core.Repo.Migrations.RemoveAdminUserSupport do
  use Ecto.Migration

  def up do
    drop_if_exists index(:articles, [:author_id])
    drop_if_exists index(:article_revisions, [:changed_by_id])
    drop_if_exists index(:media, [:uploaded_by_id])

    alter table(:articles) do
      add :author, :string
    end

    execute "UPDATE articles SET author = 'Unknown' WHERE author IS NULL"

    alter table(:articles) do
      modify :author, :string, null: false
      remove :author_id
    end

    alter table(:article_revisions) do
      add :changed_by, :string
    end

    execute "UPDATE article_revisions SET changed_by = 'System' WHERE changed_by IS NULL"

    alter table(:article_revisions) do
      modify :changed_by, :string, null: false
      remove :changed_by_id
    end

    alter table(:media) do
      add :uploaded_by, :string
      remove :uploaded_by_id
    end

    drop_if_exists table(:users)
  end

  def down do
    create table(:users) do
      add :email, :string, null: false
      add :roles, {:array, :string}, null: false, default: []
      add :password, :string, null: false
      add :first_name, :string
      add :last_name, :string
      add :display_name, :string, null: false
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    execute """
    INSERT INTO users (id, email, roles, password, display_name, is_active, inserted_at, updated_at)
    VALUES (
      1,
      'restored-admin@news.local',
      ARRAY['ROLE_ADMIN'],
      'restored',
      'Restored Admin',
      true,
      NOW(),
      NOW()
    )
    """
    execute "SELECT setval(pg_get_serial_sequence('users', 'id'), GREATEST((SELECT MAX(id) FROM users), 1))"

    alter table(:articles) do
      add :author_id, references(:users, on_delete: :restrict)
      remove :author
    end

    execute "UPDATE articles SET author_id = 1 WHERE author_id IS NULL"

    alter table(:articles) do
      modify :author_id, references(:users, on_delete: :restrict), null: false
    end

    create index(:articles, [:author_id])

    alter table(:article_revisions) do
      add :changed_by_id, references(:users, on_delete: :restrict)
      remove :changed_by
    end

    execute "UPDATE article_revisions SET changed_by_id = 1 WHERE changed_by_id IS NULL"

    alter table(:article_revisions) do
      modify :changed_by_id, references(:users, on_delete: :restrict), null: false
    end

    create index(:article_revisions, [:changed_by_id])

    alter table(:media) do
      add :uploaded_by_id, references(:users, on_delete: :nilify_all)
      remove :uploaded_by
    end

    create index(:media, [:uploaded_by_id])
  end
end

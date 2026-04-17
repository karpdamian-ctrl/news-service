defmodule Core.Repo.Migrations.RemoveAdminUserSupport do
  use Ecto.Migration

  # This migration used to run before base domain tables on fresh databases.
  # Keep it safe/no-op when tables are not present; effective conversion now
  # runs in 20260416193000_remove_admin_user_support_after_news_domain.exs.
  def up do
    if table_exists?("articles") do
      apply_adminless_schema_changes()
    end
  end

  def down do
    if table_exists?("articles") do
      rollback_adminless_schema_changes()
    end
  end

  defp apply_adminless_schema_changes do
    drop_if_exists index(:articles, [:author_id])
    drop_if_exists index(:article_revisions, [:changed_by_id])
    drop_if_exists index(:media, [:uploaded_by_id])

    if not column_exists?("articles", "author") do
      alter table(:articles) do
        add :author, :string
      end
    end

    if column_exists?("articles", "author") do
      execute "UPDATE articles SET author = 'Unknown' WHERE author IS NULL"

      alter table(:articles) do
        modify :author, :string, null: false
      end
    end

    if column_exists?("articles", "author_id") do
      alter table(:articles) do
        remove :author_id
      end
    end

    if table_exists?("article_revisions") and not column_exists?("article_revisions", "changed_by") do
      alter table(:article_revisions) do
        add :changed_by, :string
      end
    end

    if table_exists?("article_revisions") and column_exists?("article_revisions", "changed_by") do
      execute "UPDATE article_revisions SET changed_by = 'System' WHERE changed_by IS NULL"

      alter table(:article_revisions) do
        modify :changed_by, :string, null: false
      end
    end

    if table_exists?("article_revisions") and column_exists?("article_revisions", "changed_by_id") do
      alter table(:article_revisions) do
        remove :changed_by_id
      end
    end

    if table_exists?("media") and not column_exists?("media", "uploaded_by") do
      alter table(:media) do
        add :uploaded_by, :string
      end
    end

    if table_exists?("media") and column_exists?("media", "uploaded_by_id") do
      alter table(:media) do
        remove :uploaded_by_id
      end
    end

    if table_exists?("users") do
      drop_if_exists table(:users)
    end
  end

  defp rollback_adminless_schema_changes do
    unless table_exists?("users") do
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
    end

    execute """
    INSERT INTO users (id, email, roles, password, display_name, is_active, inserted_at, updated_at)
    VALUES (1, 'restored-admin@news.local', ARRAY['ROLE_ADMIN'], 'restored', 'Restored Admin', true, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING
    """

    if not column_exists?("articles", "author_id") do
      alter table(:articles) do
        add :author_id, references(:users, on_delete: :restrict)
      end
    end

    if column_exists?("articles", "author_id") do
      execute "UPDATE articles SET author_id = 1 WHERE author_id IS NULL"

      alter table(:articles) do
        modify :author_id, references(:users, on_delete: :restrict), null: false
      end

      create_if_not_exists index(:articles, [:author_id])
    end

    if column_exists?("articles", "author") do
      alter table(:articles) do
        remove :author
      end
    end

    if table_exists?("article_revisions") and not column_exists?("article_revisions", "changed_by_id") do
      alter table(:article_revisions) do
        add :changed_by_id, references(:users, on_delete: :restrict)
      end
    end

    if table_exists?("article_revisions") and column_exists?("article_revisions", "changed_by_id") do
      execute "UPDATE article_revisions SET changed_by_id = 1 WHERE changed_by_id IS NULL"

      alter table(:article_revisions) do
        modify :changed_by_id, references(:users, on_delete: :restrict), null: false
      end

      create_if_not_exists index(:article_revisions, [:changed_by_id])
    end

    if table_exists?("article_revisions") and column_exists?("article_revisions", "changed_by") do
      alter table(:article_revisions) do
        remove :changed_by
      end
    end

    if table_exists?("media") and not column_exists?("media", "uploaded_by_id") do
      alter table(:media) do
        add :uploaded_by_id, references(:users, on_delete: :nilify_all)
      end

      create_if_not_exists index(:media, [:uploaded_by_id])
    end

    if table_exists?("media") and column_exists?("media", "uploaded_by") do
      alter table(:media) do
        remove :uploaded_by
      end
    end
  end

  defp table_exists?(table_name) do
    sql = "SELECT to_regclass('public.' || $1) IS NOT NULL"
    %{rows: [[exists?]]} = repo().query!(sql, [table_name])
    exists? == true
  end

  defp column_exists?(table_name, column_name) do
    sql = """
    SELECT EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = $1
        AND column_name = $2
    )
    """

    %{rows: [[exists?]]} = repo().query!(sql, [table_name, column_name])
    exists? == true
  end
end

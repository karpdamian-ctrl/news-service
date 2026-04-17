defmodule Core.Repo.Migrations.RemoveAdminUserSupportAfterNewsDomain do
  use Ecto.Migration

  def up do
    if table_exists?("articles") do
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
  end

  def down, do: :ok

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

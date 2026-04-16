defmodule Core.Repo.Migrations.CreateNewsDomain do
  use Ecto.Migration

  def change do
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

    create table(:categories) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :parent_id, references(:categories, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:categories, [:slug])

    create table(:tags) do
      add :name, :string, null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:slug])

    create table(:media) do
      add :type, :string, null: false
      add :path, :string, null: false
      add :mime_type, :string
      add :size_bytes, :integer
      add :alt_text, :string
      add :caption, :text
      add :uploaded_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:media, [:uploaded_by_id])

    create table(:articles) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :content, :text, null: false
      add :status, :string, null: false
      add :published_at, :utc_datetime
      add :is_breaking, :boolean, null: false, default: false
      add :view_count, :integer, null: false, default: 0
      add :author_id, references(:users, on_delete: :restrict), null: false
      add :featured_image_id, references(:media, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:articles, [:slug])
    create index(:articles, [:author_id])
    create index(:articles, [:featured_image_id])

    create table(:article_categories, primary_key: false) do
      add :article_id, references(:articles, on_delete: :delete_all), null: false
      add :category_id, references(:categories, on_delete: :delete_all), null: false
    end

    create unique_index(:article_categories, [:article_id, :category_id])

    create table(:article_tags, primary_key: false) do
      add :article_id, references(:articles, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:article_tags, [:article_id, :tag_id])

    create table(:article_revisions) do
      add :title, :string, null: false
      add :description, :text
      add :content, :text, null: false
      add :change_note, :string
      add :article_id, references(:articles, on_delete: :delete_all), null: false
      add :changed_by_id, references(:users, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:article_revisions, [:article_id])
    create index(:article_revisions, [:changed_by_id])
  end
end

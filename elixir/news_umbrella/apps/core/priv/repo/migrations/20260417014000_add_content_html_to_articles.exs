defmodule Core.Repo.Migrations.AddContentHtmlToArticles do
  use Ecto.Migration

  def change do
    alter table(:articles) do
      add :content_html, :text
    end
  end
end

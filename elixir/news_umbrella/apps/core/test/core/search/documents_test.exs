defmodule Core.Search.DocumentsTest do
  use ExUnit.Case, async: true

  alias Core.Search.Documents

  test "returns all configured resources" do
    assert Documents.resources() == [:article_revisions, :articles, :categories, :media, :tags]
  end

  test "returns definition for valid resource" do
    definition = Documents.definition!(:articles)

    assert definition.endpoint == "/api/v1/articles"
    assert definition.index == "articles_v1"
    assert match?({Core.News, :list_articles}, definition.source)
    assert is_map(definition.settings)
    assert is_map(definition.mappings)
  end

  test "raises for unknown resource" do
    assert_raise ArgumentError, ~r/unknown elasticsearch resource/, fn ->
      Documents.definition!(:unknown)
    end
  end
end

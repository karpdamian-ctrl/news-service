defmodule Core.ContentRenderer.MarkdownProcessorTest do
  use Core.DataCase, async: false

  alias Core.ContentRenderer.MarkdownProcessor
  alias Core.News

  test "process_article renders markdown and stores html in article" do
    {:ok, category} = create_category("renderer-category")
    {:ok, tag} = create_tag("renderer-tag")

    {:ok, article} =
      News.create_article(%{
        title: "Markdown article",
        slug: "markdown-article",
        description: "desc",
        content: "# Heading\n\nThis is **bold** content with enough length.",
        status: "draft",
        author: "Renderer Author",
        category_ids: [category.id],
        tag_ids: [tag.id]
      })

    assert :ok = MarkdownProcessor.process_article(article.id)

    updated = News.get_article!(article.id)
    assert is_binary(updated.content_html)
    assert updated.content_html =~ "<h1>"
    assert updated.content_html =~ "Heading"
    assert updated.content_html =~ "<strong>"
  end

  test "process_payload supports article_id as integer or string" do
    {:ok, category} = create_category("renderer-payload-category")
    {:ok, tag} = create_tag("renderer-payload-tag")

    {:ok, article} =
      News.create_article(%{
        title: "Payload markdown article",
        slug: "payload-markdown-article",
        description: "desc",
        content: "## Subtitle\n\nMarkdown body long enough for validation.",
        status: "draft",
        author: "Payload Author",
        category_ids: [category.id],
        tag_ids: [tag.id]
      })

    assert :ok = MarkdownProcessor.process_payload(Jason.encode!(%{article_id: article.id}))
    assert :ok = MarkdownProcessor.process_payload(Jason.encode!(%{article_id: Integer.to_string(article.id)}))
  end

  test "process_payload validates malformed messages" do
    assert {:error, :invalid_payload} = MarkdownProcessor.process_payload("not-json")
    assert {:error, :invalid_article_id} = MarkdownProcessor.process_payload(Jason.encode!(%{article_id: "abc"}))
    assert {:error, :article_not_found} = MarkdownProcessor.process_payload(Jason.encode!(%{article_id: 999_999}))
  end

  defp create_category(slug_suffix) do
    News.create_category(%{
      name: "Category #{slug_suffix}",
      slug: "category-#{slug_suffix}",
      description: "Category description"
    })
  end

  defp create_tag(slug_suffix) do
    News.create_tag(%{
      name: "Tag #{slug_suffix}",
      slug: "tag-#{slug_suffix}"
    })
  end
end

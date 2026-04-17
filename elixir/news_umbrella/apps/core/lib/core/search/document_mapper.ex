defmodule Core.Search.DocumentMapper do
  @moduledoc false

  alias Core.News.{Article, ArticleRevision, Category, Media, Tag}

  @spec to_document(atom(), struct()) :: map()
  def to_document(:categories, %Category{} = item) do
    %{
      id: item.id,
      name: item.name,
      slug: item.slug,
      description: item.description,
      inserted_at: datetime_to_iso(item.inserted_at),
      updated_at: datetime_to_iso(item.updated_at)
    }
  end

  def to_document(:tags, %Tag{} = item) do
    %{
      id: item.id,
      name: item.name,
      slug: item.slug,
      inserted_at: datetime_to_iso(item.inserted_at),
      updated_at: datetime_to_iso(item.updated_at)
    }
  end

  def to_document(:media, %Media{} = item) do
    %{
      id: item.id,
      type: item.type,
      path: item.path,
      mime_type: item.mime_type,
      size_bytes: item.size_bytes,
      alt_text: item.alt_text,
      caption: item.caption,
      uploaded_by: item.uploaded_by,
      inserted_at: datetime_to_iso(item.inserted_at)
    }
  end

  def to_document(:articles, %Article{} = item) do
    categories = item.categories || []
    tags = item.tags || []

    %{
      id: item.id,
      title: item.title,
      slug: item.slug,
      description: item.description,
      content: item.content,
      content_html: item.content_html,
      status: item.status,
      published_at: datetime_to_iso(item.published_at),
      is_breaking: item.is_breaking,
      view_count: item.view_count,
      author: item.author,
      featured_image_id: item.featured_image_id,
      category_ids: Enum.map(categories, & &1.id),
      category_names: Enum.map(categories, & &1.name),
      category_refs: Enum.map(categories, &"#{&1.id}|#{&1.slug}|#{&1.name}"),
      tag_ids: Enum.map(tags, & &1.id),
      tag_names: Enum.map(tags, & &1.name),
      tag_refs: Enum.map(tags, &"#{&1.id}|#{&1.slug}|#{&1.name}"),
      inserted_at: datetime_to_iso(item.inserted_at),
      updated_at: datetime_to_iso(item.updated_at)
    }
  end

  def to_document(:article_revisions, %ArticleRevision{} = item) do
    %{
      id: item.id,
      article_id: item.article_id,
      title: item.title,
      slug: item.slug,
      description: item.description,
      content: item.content,
      status: item.status,
      published_at: datetime_to_iso(item.published_at),
      is_breaking: item.is_breaking,
      view_count: item.view_count,
      author: item.author,
      featured_image_id: item.featured_image_id,
      category_ids: item.category_ids || [],
      tag_ids: item.tag_ids || [],
      modified_at: datetime_to_iso(item.modified_at),
      change_note: item.change_note,
      changed_by: item.changed_by,
      inserted_at: datetime_to_iso(item.inserted_at)
    }
  end

  def to_document(resource, item) do
    raise ArgumentError,
          "unsupported mapper resource #{inspect(resource)} for item #{inspect(item.__struct__)}"
  end

  defp datetime_to_iso(nil), do: nil
  defp datetime_to_iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp datetime_to_iso(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp datetime_to_iso(value), do: value
end

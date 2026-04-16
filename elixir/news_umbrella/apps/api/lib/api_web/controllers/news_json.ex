defmodule ApiWeb.NewsJSON do
  alias Core.News.{Article, ArticleRevision, Category, Media, Tag}

  def categories(data), do: %{data: Enum.map(data, &category/1)}
  def tags(data), do: %{data: Enum.map(data, &tag/1)}
  def media_list(data), do: %{data: Enum.map(data, &media/1)}
  def articles(data), do: %{data: Enum.map(data, &article/1)}
  def article_revisions(data), do: %{data: Enum.map(data, &article_revision/1)}

  def category(%Category{} = item) do
    %{
      id: item.id,
      name: item.name,
      slug: item.slug,
      description: item.description,
      parent_id: item.parent_id,
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end

  def tag(%Tag{} = item) do
    %{
      id: item.id,
      name: item.name,
      slug: item.slug,
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end

  def media(%Media{} = item) do
    %{
      id: item.id,
      type: item.type,
      path: item.path,
      mime_type: item.mime_type,
      size_bytes: item.size_bytes,
      alt_text: item.alt_text,
      caption: item.caption,
      uploaded_by: item.uploaded_by,
      inserted_at: item.inserted_at
    }
  end

  def article(%Article{} = item) do
    %{
      id: item.id,
      title: item.title,
      slug: item.slug,
      description: item.description,
      content: item.content,
      status: item.status,
      published_at: item.published_at,
      is_breaking: item.is_breaking,
      view_count: item.view_count,
      author: item.author,
      featured_image_id: item.featured_image_id,
      category_ids: Enum.map(item.categories || [], & &1.id),
      tag_ids: Enum.map(item.tags || [], & &1.id),
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end

  def article_revision(%ArticleRevision{} = item) do
    %{
      id: item.id,
      title: item.title,
      slug: item.slug,
      description: item.description,
      content: item.content,
      status: item.status,
      published_at: item.published_at,
      is_breaking: item.is_breaking,
      view_count: item.view_count,
      author: item.author,
      featured_image_id: item.featured_image_id,
      category_ids: item.category_ids || [],
      tag_ids: item.tag_ids || [],
      modified_at: item.modified_at,
      change_note: item.change_note,
      article_id: item.article_id,
      changed_by: item.changed_by,
      inserted_at: item.inserted_at
    }
  end
end

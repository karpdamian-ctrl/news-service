defmodule Core.News do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Core.Repo
  alias Ecto.Changeset
  alias Ecto.Multi

  alias Core.News.{Article, ArticleRevision, Category, Media, Tag}
  alias Core.News.Query

  @article_preloads [:featured_image, :categories, :tags]

  # Categories
  def list_categories(params \\ %{}) do
    Query.list(Category, params,
      sortable: [:id, :name, :slug, :inserted_at, :updated_at],
      filterable: [:name, :slug],
      search_fields: [:name, :slug, :description],
      default_sort: :inserted_at,
      default_order: :desc
    )
  end

  def get_category(id), do: Repo.get(Category, id)
  def get_category!(id), do: Repo.get!(Category, id)

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
    |> tap_ok(fn category ->
      publish({:upsert, :categories, category})
    end)
  end

  def update_category(%Category{} = category, attrs) do
    impacted_article_ids = article_ids_for_category(category.id)

    category
    |> Category.changeset(attrs)
    |> Repo.update()
    |> tap_ok(fn updated_category ->
      publish({:upsert, :categories, updated_category})
      publish({:reindex_articles, impacted_article_ids})
    end)
  end

  def delete_category(%Category{} = category) do
    impacted_article_ids = article_ids_for_category(category.id)

    Repo.delete(category)
    |> tap_ok(fn _ ->
      publish({:delete, :categories, category.id})
      publish({:reindex_articles, impacted_article_ids})
    end)
  end

  # Tags
  def list_tags(params \\ %{}) do
    Query.list(Tag, params,
      sortable: [:id, :name, :slug, :inserted_at, :updated_at],
      filterable: [:name, :slug],
      search_fields: [:name, :slug],
      default_sort: :inserted_at,
      default_order: :desc
    )
  end

  def get_tag(id), do: Repo.get(Tag, id)
  def get_tag!(id), do: Repo.get!(Tag, id)

  def create_tag(attrs) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
    |> tap_ok(fn tag ->
      publish({:upsert, :tags, tag})
    end)
  end

  def update_tag(%Tag{} = tag, attrs) do
    impacted_article_ids = article_ids_for_tag(tag.id)

    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
    |> tap_ok(fn updated_tag ->
      publish({:upsert, :tags, updated_tag})
      publish({:reindex_articles, impacted_article_ids})
    end)
  end

  def delete_tag(%Tag{} = tag) do
    impacted_article_ids = article_ids_for_tag(tag.id)

    Repo.delete(tag)
    |> tap_ok(fn _ ->
      publish({:delete, :tags, tag.id})
      publish({:reindex_articles, impacted_article_ids})
    end)
  end

  # Media
  def list_media(params \\ %{}) do
    Query.list(Media, params,
      sortable: [:id, :type, :path, :mime_type, :size_bytes, :uploaded_by, :inserted_at],
      filterable: [:type, :mime_type, :uploaded_by],
      search_fields: [:type, :path, :mime_type, :alt_text, :caption, :uploaded_by],
      default_sort: :inserted_at,
      default_order: :desc
    )
  end

  def get_media(id), do: Repo.get(Media, id)
  def get_media!(id), do: Repo.get!(Media, id)

  def create_media(attrs) do
    %Media{}
    |> Media.changeset(attrs)
    |> Repo.insert()
    |> tap_ok(fn media ->
      publish({:upsert, :media, media})
    end)
  end

  def update_media(%Media{} = media, attrs) do
    media
    |> Media.changeset(attrs)
    |> Repo.update()
    |> tap_ok(fn updated_media ->
      publish({:upsert, :media, updated_media})
    end)
  end

  def delete_media(%Media{} = media) do
    impacted_article_ids = article_ids_for_featured_media(media.id)
    impacted_revision_ids = article_revision_ids_for_featured_media(media.id)

    Repo.delete(media)
    |> tap_ok(fn _ ->
      publish({:delete, :media, media.id})
      publish({:reindex_articles, impacted_article_ids})
      publish({:reindex_article_revisions, impacted_revision_ids})
    end)
  end

  # Articles
  def list_articles(params \\ %{}) do
    Query.list(Article, params,
      sortable: [
        :id,
        :title,
        :slug,
        :status,
        :author,
        :published_at,
        :view_count,
        :inserted_at,
        :updated_at
      ],
      filterable: [:title, :slug, :status, :author, :is_breaking],
      search_fields: [:title, :slug, :description, :content, :author],
      default_sort: :inserted_at,
      default_order: :desc,
      preload: @article_preloads
    )
  end

  def get_article(id), do: Repo.get(Article, id) |> maybe_preload(@article_preloads)
  def get_article!(id), do: Repo.get!(Article, id) |> Repo.preload(@article_preloads)

  def create_article(attrs) do
    %Article{}
    |> Article.changeset(attrs)
    |> put_article_assocs(attrs)
    |> Repo.insert()
    |> maybe_preload_article()
    |> tap_ok(fn article ->
      publish({:upsert, :articles, article})
    end)
  end

  def update_article(%Article{} = article, attrs) do
    article = Repo.preload(article, [:categories, :tags])

    with {:ok, changed_by} <- required_changed_by(attrs) do
      revision_attrs = build_revision_attrs(article, attrs, changed_by)

      Multi.new()
      |> Multi.insert(:revision, ArticleRevision.changeset(%ArticleRevision{}, revision_attrs))
      |> Multi.update(:article, article |> Article.changeset(attrs) |> put_article_assocs(attrs))
      |> Repo.transaction()
      |> case do
        {:ok, %{article: updated_article, revision: revision}} ->
          updated_article = Repo.preload(updated_article, @article_preloads)
          publish({:upsert, :article_revisions, revision})
          publish({:upsert, :articles, updated_article})
          {:ok, updated_article}

        {:error, :article, article_changeset, _changes_so_far} ->
          {:error, article_changeset}

        {:error, :revision, revision_changeset, _changes_so_far} ->
          {:error, revision_changeset}
      end
    else
      {:error, :required} ->
        {:error, changed_by_error_changeset(article, "is required")}

      {:error, :too_short} ->
        {:error, changed_by_error_changeset(article, "should be at least 3 character(s)")}
    end
  end

  def delete_article(%Article{} = article) do
    revision_ids = article_revision_ids_for_article(article.id)

    Repo.delete(article)
    |> tap_ok(fn _ ->
      publish({:delete, :articles, article.id})
      publish({:reindex_article_revisions, revision_ids})
    end)
  end

  # Revisions
  def list_article_revisions(params \\ %{}) do
    Query.list(ArticleRevision, params,
      sortable: [
        :id,
        :title,
        :slug,
        :status,
        :article_id,
        :changed_by,
        :modified_at,
        :inserted_at
      ],
      filterable: [:title, :slug, :status, :article_id, :author, :changed_by],
      search_fields: [:title, :slug, :description, :content, :author, :change_note, :changed_by],
      default_sort: :modified_at,
      default_order: :desc,
      preload: [:article]
    )
  end

  def get_article_revision(id), do: Repo.get(ArticleRevision, id) |> maybe_preload([:article])
  def get_article_revision!(id), do: Repo.get!(ArticleRevision, id) |> Repo.preload([:article])

  def create_article_revision(attrs) do
    %ArticleRevision{}
    |> ArticleRevision.changeset(attrs)
    |> Repo.insert()
    |> tap_ok(fn revision ->
      publish({:upsert, :article_revisions, revision})
    end)
  end

  def update_article_revision(%ArticleRevision{} = revision, attrs),
    do:
      revision
      |> ArticleRevision.changeset(attrs)
      |> Repo.update()
      |> tap_ok(fn updated_revision ->
        publish({:upsert, :article_revisions, updated_revision})
      end)

  def delete_article_revision(%ArticleRevision{} = revision) do
    Repo.delete(revision)
    |> tap_ok(fn _ ->
      publish({:delete, :article_revisions, revision.id})
    end)
  end

  defp put_article_assocs(changeset, attrs) do
    changeset
    |> maybe_put_categories(parse_assoc_ids(attrs, :category_ids, "category_ids"))
    |> maybe_put_tags(parse_assoc_ids(attrs, :tag_ids, "tag_ids"))
  end

  defp maybe_put_categories(changeset, :absent) do
    Changeset.add_error(changeset, :category_ids, "can't be blank")
  end

  defp maybe_put_categories(changeset, {:error, :invalid}) do
    Changeset.add_error(changeset, :category_ids, "must contain valid positive integer ids")
  end

  defp maybe_put_categories(changeset, {:ok, []}) do
    Changeset.add_error(changeset, :category_ids, "can't be blank")
  end

  defp maybe_put_categories(changeset, {:ok, ids}) do
    categories = from(c in Category, where: c.id in ^ids) |> Repo.all()

    if length(categories) == length(ids) do
      Changeset.put_assoc(changeset, :categories, categories)
    else
      Changeset.add_error(changeset, :category_ids, "contains unknown ids")
    end
  end

  defp maybe_put_tags(changeset, :absent) do
    Changeset.add_error(changeset, :tag_ids, "can't be blank")
  end

  defp maybe_put_tags(changeset, {:error, :invalid}) do
    Changeset.add_error(changeset, :tag_ids, "must contain valid positive integer ids")
  end

  defp maybe_put_tags(changeset, {:ok, []}) do
    Changeset.add_error(changeset, :tag_ids, "can't be blank")
  end

  defp maybe_put_tags(changeset, {:ok, ids}) do
    tags = from(t in Tag, where: t.id in ^ids) |> Repo.all()

    if length(tags) == length(ids) do
      Changeset.put_assoc(changeset, :tags, tags)
    else
      Changeset.add_error(changeset, :tag_ids, "contains unknown ids")
    end
  end

  defp maybe_preload_article({:ok, article}), do: {:ok, Repo.preload(article, @article_preloads)}
  defp maybe_preload_article(error), do: error
  defp maybe_preload(nil, _preloads), do: nil
  defp maybe_preload(struct, preloads), do: Repo.preload(struct, preloads)

  defp parse_assoc_ids(attrs, atom_key, string_key) do
    case Map.get(attrs, atom_key) || Map.get(attrs, string_key) do
      nil ->
        :absent

      values when is_list(values) ->
        with {:ok, ints} <- cast_positive_integer_list(values) do
          {:ok, Enum.uniq(ints)}
        end

      value ->
        with {:ok, int} <- cast_positive_integer(value) do
          {:ok, [int]}
        end
    end
  end

  defp cast_positive_integer_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case cast_positive_integer(value) do
        {:ok, int} -> {:cont, {:ok, [int | acc]}}
        {:error, :invalid} -> {:halt, {:error, :invalid}}
      end
    end)
    |> case do
      {:ok, ints} -> {:ok, Enum.reverse(ints)}
      {:error, :invalid} -> {:error, :invalid}
    end
  end

  defp cast_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp cast_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:error, :invalid}
    end
  end

  defp cast_positive_integer(_), do: {:error, :invalid}

  defp build_revision_attrs(%Article{} = article, attrs, changed_by) do
    modified_at = DateTime.utc_now() |> DateTime.truncate(:second)

    %{
      article_id: article.id,
      title: article.title,
      slug: article.slug,
      description: article.description,
      content: article.content,
      status: article.status,
      published_at: article.published_at,
      is_breaking: article.is_breaking,
      view_count: article.view_count,
      author: article.author,
      featured_image_id: article.featured_image_id,
      category_ids: assoc_ids_from_preload(article.categories),
      tag_ids: assoc_ids_from_preload(article.tags),
      modified_at: modified_at,
      change_note: revision_change_note(attrs),
      changed_by: changed_by
    }
  end

  defp revision_change_note(attrs) do
    value = Map.get(attrs, "change_note") || Map.get(attrs, :change_note)

    value
    |> case do
      nil -> ""
      raw -> raw |> to_string() |> String.trim()
    end
    |> case do
      "" -> "Automatic snapshot before article update"
      note -> note
    end
  end

  defp assoc_ids_from_preload(list) when is_list(list), do: Enum.map(list, & &1.id)
  defp assoc_ids_from_preload(_), do: []

  defp required_changed_by(attrs) do
    value = Map.get(attrs, "changed_by") || Map.get(attrs, :changed_by)

    value
    |> case do
      nil -> ""
      raw -> raw |> to_string() |> String.trim()
    end
    |> case do
      "" -> {:error, :required}
      trimmed when byte_size(trimmed) < 3 -> {:error, :too_short}
      trimmed -> {:ok, trimmed}
    end
  end

  defp changed_by_error_changeset(%Article{} = article, message) do
    article
    |> Changeset.change()
    |> Changeset.add_error(:changed_by, message)
  end

  defp article_ids_for_category(category_id) do
    from(ac in "article_categories", where: ac.category_id == ^category_id, select: ac.article_id)
    |> Repo.all()
  end

  defp article_ids_for_tag(tag_id) do
    from(at in "article_tags", where: at.tag_id == ^tag_id, select: at.article_id)
    |> Repo.all()
  end

  defp article_ids_for_featured_media(media_id) do
    from(a in Article, where: a.featured_image_id == ^media_id, select: a.id)
    |> Repo.all()
  end

  defp article_revision_ids_for_featured_media(media_id) do
    from(r in ArticleRevision, where: r.featured_image_id == ^media_id, select: r.id)
    |> Repo.all()
  end

  defp article_revision_ids_for_article(article_id) do
    from(r in ArticleRevision, where: r.article_id == ^article_id, select: r.id)
    |> Repo.all()
  end

  defp publish(event) do
    publisher = Application.get_env(:core, :search_events_module, Core.Search.Events)
    publisher.publish(event)
  end

  defp tap_ok({:ok, value}, fun) when is_function(fun, 1) do
    fun.(value)
    {:ok, value}
  end

  defp tap_ok(other, _fun), do: other
end

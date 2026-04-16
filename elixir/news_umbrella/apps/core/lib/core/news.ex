defmodule Core.News do
  @moduledoc false

  import Ecto.Query, warn: false
  alias Core.Repo
  alias Ecto.Changeset

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

  def create_category(attrs), do: %Category{} |> Category.changeset(attrs) |> Repo.insert()

  def update_category(%Category{} = category, attrs),
    do: category |> Category.changeset(attrs) |> Repo.update()

  def delete_category(%Category{} = category), do: Repo.delete(category)

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

  def create_tag(attrs), do: %Tag{} |> Tag.changeset(attrs) |> Repo.insert()

  def update_tag(%Tag{} = tag, attrs), do: tag |> Tag.changeset(attrs) |> Repo.update()

  def delete_tag(%Tag{} = tag), do: Repo.delete(tag)

  # Media
  def list_media(params \\ %{}) do
    Query.list(Media, params,
      sortable: [:id, :type, :path, :size_bytes, :inserted_at],
      filterable: [:type, :mime_type, :uploaded_by],
      search_fields: [:type, :path, :mime_type, :alt_text, :caption, :uploaded_by],
      default_sort: :inserted_at,
      default_order: :desc
    )
  end

  def get_media(id), do: Repo.get(Media, id)
  def get_media!(id), do: Repo.get!(Media, id)

  def create_media(attrs), do: %Media{} |> Media.changeset(attrs) |> Repo.insert()

  def update_media(%Media{} = media, attrs), do: media |> Media.changeset(attrs) |> Repo.update()

  def delete_media(%Media{} = media), do: Repo.delete(media)

  # Articles
  def list_articles(params \\ %{}) do
    Query.list(Article, params,
      sortable: [
        :id,
        :title,
        :slug,
        :status,
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
  end

  def update_article(%Article{} = article, attrs) do
    article
    |> Repo.preload([:categories, :tags])
    |> Article.changeset(attrs)
    |> put_article_assocs(attrs)
    |> Repo.update()
    |> maybe_preload_article()
  end

  def delete_article(%Article{} = article), do: Repo.delete(article)

  # Revisions
  def list_article_revisions(params \\ %{}) do
    Query.list(ArticleRevision, params,
      sortable: [:id, :title, :article_id, :changed_by, :inserted_at],
      filterable: [:title, :article_id, :changed_by],
      search_fields: [:title, :description, :content, :change_note, :changed_by],
      default_sort: :inserted_at,
      default_order: :desc,
      preload: [:article]
    )
  end

  def get_article_revision(id), do: Repo.get(ArticleRevision, id) |> maybe_preload([:article])
  def get_article_revision!(id), do: Repo.get!(ArticleRevision, id) |> Repo.preload([:article])

  def create_article_revision(attrs),
    do: %ArticleRevision{} |> ArticleRevision.changeset(attrs) |> Repo.insert()

  def update_article_revision(%ArticleRevision{} = revision, attrs),
    do: revision |> ArticleRevision.changeset(attrs) |> Repo.update()

  def delete_article_revision(%ArticleRevision{} = revision), do: Repo.delete(revision)

  defp put_article_assocs(changeset, attrs) do
    changeset
    |> maybe_put_categories(parse_assoc_ids(attrs, :category_ids, "category_ids"))
    |> maybe_put_tags(parse_assoc_ids(attrs, :tag_ids, "tag_ids"))
  end

  defp maybe_put_categories(changeset, :absent), do: changeset

  defp maybe_put_categories(changeset, {:error, :invalid}) do
    Changeset.add_error(changeset, :category_ids, "must contain valid positive integer ids")
  end

  defp maybe_put_categories(changeset, {:ok, ids}) do
    categories = from(c in Category, where: c.id in ^ids) |> Repo.all()

    if length(categories) == length(ids) do
      Changeset.put_assoc(changeset, :categories, categories)
    else
      Changeset.add_error(changeset, :category_ids, "contains unknown ids")
    end
  end

  defp maybe_put_tags(changeset, :absent), do: changeset

  defp maybe_put_tags(changeset, {:error, :invalid}) do
    Changeset.add_error(changeset, :tag_ids, "must contain valid positive integer ids")
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
end

defmodule Core.ContentRenderer.MarkdownProcessor do
  @moduledoc false

  alias Core.News

  def process_payload(payload) when is_binary(payload) do
    case Jason.decode(payload) do
      {:ok, %{"article_id" => raw_article_id}} ->
        with {:ok, article_id} <- cast_positive_integer(raw_article_id) do
          process_article(article_id)
        end

      _ ->
        {:error, :invalid_payload}
    end
  end

  def process_payload(_), do: {:error, :invalid_payload}

  def process_article(article_id) when is_integer(article_id) and article_id > 0 do
    case News.get_article(article_id) do
      nil ->
        {:error, :article_not_found}

      article ->
        with {:ok, content_html} <- render_markdown(article.content),
             {:ok, _updated_article} <- News.set_article_content_html(article_id, content_html) do
          :ok
        end
    end
  end

  def process_article(_), do: {:error, :invalid_article_id}

  def render_markdown(markdown) when is_binary(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _warnings} when is_binary(html) ->
        {:ok, html}

      {:error, html, _errors} when is_binary(html) ->
        {:ok, html}

      other ->
        {:error, {:markdown_render_failed, other}}
    end
  end

  def render_markdown(_), do: {:error, :invalid_markdown}

  defp cast_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp cast_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:error, :invalid_article_id}
    end
  end

  defp cast_positive_integer(_), do: {:error, :invalid_article_id}
end

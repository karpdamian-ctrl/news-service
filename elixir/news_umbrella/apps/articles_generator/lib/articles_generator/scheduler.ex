defmodule ArticlesGenerator.Scheduler do
  @moduledoc false

  use GenServer
  require Logger

  alias Core.News

  @default_tick_interval_ms 30_000
  @default_next_generation_key "articles_generator:next_generation_at"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_state) do
    state = %{
      tick_interval_ms:
        Application.get_env(:articles_generator, :tick_interval_ms, @default_tick_interval_ms),
      next_generation_key:
        Application.get_env(
          :articles_generator,
          :next_generation_key,
          @default_next_generation_key
        )
    }

    send(self(), :tick)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    now = System.system_time(:second)
    _ = maybe_generate_article(now, state)
    Process.send_after(self(), :tick, state.tick_interval_ms)
    {:noreply, state}
  end

  defp maybe_generate_article(now, state) do
    with {:ok, next_generation_at} <- read_next_generation_at(state.next_generation_key) do
      if now >= next_generation_at do
        _ = generate_article()
        _ = schedule_next_generation(now, state.next_generation_key)
      end

      :ok
    else
      :missing ->
        schedule_next_generation(now, state.next_generation_key)

      {:error, reason} ->
        Logger.warning("ARTICLE_GENERATOR_REDIS_ERROR #{inspect(reason)}")
    end
  end

  defp read_next_generation_at(key) do
    case Redix.command(ArticlesGenerator.Redis, ["GET", key]) do
      {:ok, nil} ->
        :missing

      {:ok, value} when is_binary(value) ->
        case Integer.parse(value) do
          {timestamp, ""} -> {:ok, timestamp}
          _ -> :missing
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp schedule_next_generation(now, key) do
    delay_seconds = ArticlesGenerator.next_delay_seconds()
    next_at = now + delay_seconds
    delay_minutes = div(delay_seconds, 60)
    delay_remainder_seconds = rem(delay_seconds, 60)

    case Redix.command(ArticlesGenerator.Redis, ["SET", key, Integer.to_string(next_at)]) do
      {:ok, "OK"} ->
        Logger.info(
          "ARTICLE_GENERATOR_NEXT #{inspect(%{next_generation_at: next_at, in: "#{delay_minutes}m #{delay_remainder_seconds}s"})}"
        )

        :ok

      {:error, reason} ->
        Logger.warning("ARTICLE_GENERATOR_REDIS_ERROR #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp generate_article do
    with {:ok, categories} <- random_categories(),
         {:ok, tags} <- random_tags() do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      suffix = random_suffix()
      story = build_story(now)
      title = story.title
      author = random_author()
      is_breaking = Enum.random([true, false, false, false])
      featured_image_id = random_featured_image_id()

      category_names = Enum.map(categories, & &1.name)
      tag_names = Enum.map(tags, & &1.name)

      attrs = %{
        title: title,
        slug: build_slug(title, suffix),
        description: generated_description(story),
        content: generated_markdown(story, now, category_names, tag_names),
        status: "published",
        published_at: now,
        is_breaking: is_breaking,
        view_count: Enum.random(1..1000),
        author: author,
        featured_image_id: featured_image_id,
        category_ids: Enum.map(categories, & &1.id),
        tag_ids: Enum.map(tags, & &1.id)
      }

      case News.create_article(attrs) do
        {:ok, article} ->
          Logger.info(
            "ARTICLE_GENERATOR_CREATED #{inspect(%{article_id: article.id, slug: article.slug})}"
          )

          :ok

        {:error, changeset} ->
          Logger.warning("ARTICLE_GENERATOR_CREATE_FAILED #{inspect(changeset.errors)}")
          {:error, :create_failed}
      end
    else
      {:error, :missing_categories} ->
        Logger.warning("ARTICLE_GENERATOR_SKIPPED missing categories")
        :ok

      {:error, :missing_tags} ->
        Logger.warning("ARTICLE_GENERATOR_SKIPPED missing tags")
        :ok
    end
  end

  defp random_categories do
    case News.list_categories(%{
           "page" => "1",
           "per_page" => "100",
           "sort" => "id",
           "order" => "asc"
         }) do
      {:ok, %{entries: []}} -> {:error, :missing_categories}
      {:ok, %{entries: entries}} -> {:ok, pick_random_subset(entries, 3)}
      {:error, _reason} -> {:error, :missing_categories}
    end
  end

  defp random_tags do
    case News.list_tags(%{"page" => "1", "per_page" => "100", "sort" => "id", "order" => "asc"}) do
      {:ok, %{entries: []}} -> {:error, :missing_tags}
      {:ok, %{entries: entries}} -> {:ok, pick_random_subset(entries, 4)}
      {:error, _reason} -> {:error, :missing_tags}
    end
  end

  defp random_featured_image_id do
    case News.list_media(%{"page" => "1", "per_page" => "100", "sort" => "id", "order" => "asc"}) do
      {:ok, %{entries: []}} ->
        nil

      {:ok, %{entries: entries}} ->
        entries
        |> Enum.filter(&(&1.type == "image"))
        |> case do
          [] -> nil
          images -> Enum.random(images).id
        end

      _ ->
        nil
    end
  end

  defp pick_random_subset(entries, max_items) when is_list(entries) and max_items >= 1 do
    max_count = min(length(entries), max_items)
    count = Enum.random(1..max_count)
    Enum.take_random(entries, count)
  end

  defp random_suffix do
    :crypto.strong_rand_bytes(3)
    |> Base.encode16(case: :lower)
  end

  defp generated_markdown(story, published_at, category_names, tag_names) do
    categories_line = Enum.join(category_names, ", ")
    tags_line = Enum.join(tag_names, ", ")

    """
    # #{story.title}

    _Opublikowano automatycznie: #{DateTime.to_iso8601(published_at)}_

    **Lead:** #{story.lead}

    ## Najważniejsze informacje

    - Wskaźnik bazowy: **#{story.metric_value}%**.
    - Zmiana względem poprzedniego okresu: **#{story.delta}%**.
    - Obszar: **#{story.location}**.
    - Kategorie: **#{categories_line}**.
    - Tagi przewodnie: **#{tags_line}**.

    ## Co się wydarzyło?

    #{story.paragraph_1}

    #{story.paragraph_2}

    ## Głos ekspertów

    > "#{story.quote}"

    ## Co dalej?

    Redakcja będzie monitorować ten temat i aktualizować dane, gdy pojawią się
    kolejne komunikaty z rynku oraz instytucji branżowych.
    """
  end

  defp build_story(now) do
    topic = Enum.random(["rynek pracy", "segment AI", "sieci 5G", "e-commerce", "energetyka"])
    action = Enum.random(["przyspiesza", "hamuje", "stabilizuje się", "zaskakuje analityków"])
    location = Enum.random(["Warszawa", "Berlin", "Praga", "Madryt", "Amsterdam"])

    audience =
      Enum.random(["firm", "samorządów", "startupów", "operatorów", "redakcji", "inwestorów"])

    metric_value = Enum.random(38..92)
    delta = Enum.random(-14..19)
    signed_delta = if(delta >= 0, do: "+#{delta}", else: Integer.to_string(delta))
    today = Date.to_iso8601(DateTime.to_date(now))
    trend = if(delta >= 0, do: "wzrost", else: "spadek")
    quarter = Enum.random(["I kwartał", "II kwartał", "III kwartał", "IV kwartał"])

    urgency =
      Enum.random(["w najbliższych dniach", "w ciągu tygodnia", "w perspektywie miesiąca"])

    signal = Enum.random(["popyt", "presja kosztowa", "tempo wdrożeń", "nastroje konsumentów"])

    context = %{
      topic: topic,
      action: action,
      location: location,
      audience: audience,
      metric_value: metric_value,
      delta: signed_delta,
      trend: trend,
      today: today,
      quarter: quarter,
      urgency: urgency,
      signal: signal
    }

    title =
      build_title(context)

    %{
      title: title,
      lead: build_lead(context),
      metric_value: metric_value,
      delta: signed_delta,
      location: location,
      paragraph_1: build_paragraph_1(context),
      paragraph_2: build_paragraph_2(context),
      quote: build_quote(context)
    }
  end

  defp generated_description(story) do
    template =
      Enum.random([
        "Nowe dane: %s. Wskaźnik %s%%, zmiana %s%% i możliwe konsekwencje dla rynku.",
        "Analiza dnia: %s. Odczyt %s%% oraz dynamika %s%% pokazują, gdzie może pójść rynek.",
        "Szybkie podsumowanie: %s. Wynik %s%% i ruch o %s%% wpływają na decyzje operacyjne."
      ])

    :io_lib.format(template, [story.title, story.metric_value, story.delta])
    |> IO.iodata_to_binary()
  end

  defp build_title(context) do
    [
      "Raport dnia: #{String.capitalize(context.topic)} #{context.action} w #{context.location}",
      "#{String.capitalize(context.topic)} w #{context.location}: rynek notuje #{context.trend}",
      "#{context.location} pod lupą: #{String.capitalize(context.topic)} #{context.action}",
      "#{context.quarter}: #{String.capitalize(context.topic)} zmienia kierunek w #{context.location}",
      "#{String.capitalize(context.signal)} napędza #{context.topic} - nowe dane z #{context.location}",
      "#{String.capitalize(context.topic)} i #{context.audience}: co pokazuje odczyt #{context.metric_value}%?"
    ]
    |> Enum.random()
  end

  defp build_lead(context) do
    [
      "Nowe dane za #{context.today} pokazują, że #{context.topic} #{context.action}, co wpływa na decyzje #{context.audience}.",
      "W #{context.location} obserwujemy #{context.trend} w obszarze #{context.topic}; zespoły #{context.audience} przygotowują korekty planów.",
      "#{context.quarter} przynosi sygnał dla #{context.audience}: #{context.topic} #{context.action}, a rynek reaguje szybciej niż miesiąc temu.",
      "Analitycy wskazują, że #{context.topic} w #{context.location} może wyznaczać kierunek dla #{context.audience} #{context.urgency}.",
      "Po serii nowych odczytów temat #{context.topic} wraca na pierwszy plan - szczególnie tam, gdzie kluczowy jest #{context.signal}."
    ]
    |> Enum.random()
  end

  defp build_paragraph_1(context) do
    [
      "W najnowszym zestawieniu odnotowano wynik na poziomie #{context.metric_value}%, a eksperci wskazują na rosnącą rolę lokalnych inwestycji i zmian regulacyjnych.",
      "Aktualny odczyt wynosi #{context.metric_value}%, co według komentatorów jest efektem zmian po stronie kosztów, logistyki i polityki zakupowej.",
      "Rynek w #{context.location} zamknął tydzień z wynikiem #{context.metric_value}%. Najmocniej widoczny był wpływ czynnika: #{context.signal}.",
      "Dane sektorowe wskazują poziom #{context.metric_value}% i potwierdzają, że #{context.topic} przestał być niszowym tematem dla pojedynczych zespołów.",
      "Wskaźnik bazowy zatrzymał się na #{context.metric_value}%, a to oznacza, że organizacje częściej przechodzą od testów do wdrożeń."
    ]
    |> Enum.random()
  end

  defp build_paragraph_2(context) do
    [
      "Zdaniem obserwatorów rynku, jeśli trend utrzyma się w kolejnych tygodniach, część #{context.audience} może przyspieszyć swoje plany operacyjne.",
      "Zmiana o #{context.delta}% sugeruje, że #{context.audience} będą ostrożniej planować budżety, ale jednocześnie szybciej uruchamiać projekty o wysokim ROI.",
      "Eksperci podkreślają, że kolejne decyzje zapadną #{context.urgency}, bo obecna dynamika wymusza szybsze porównywanie scenariuszy.",
      "Według analityków, utrzymanie obecnego tempa może przełożyć się na wyraźną zmianę priorytetów po stronie #{context.audience}.",
      "Jeśli bieżący kierunek się utrzyma, to w następnym okresie wzrośnie presja na mierzenie efektu biznesowego i czasu wdrożeń."
    ]
    |> Enum.random()
  end

  defp build_quote(context) do
    [
      "Widzimy wyraźny sygnał, że uczestnicy rynku szybciej reagują na zmiany i szukają przewagi przez szybsze decyzje.",
      "To nie jest jednorazowy skok. Ten odczyt pokazuje, że #{context.topic} przesuwa się z etapu eksperymentów do egzekucji.",
      "Najciekawsze jest to, że dynamika #{context.delta}% nie odstrasza rynku - raczej porządkuje priorytety inwestycyjne.",
      "Jeżeli ten trend utrzyma się do końca #{context.quarter}, część organizacji przeprojektuje procesy wcześniej niż planowano.",
      "Dla zarządów kluczowy jest dziś nie sam wskaźnik, ale tempo, w jakim decyzje przekładają się na wynik operacyjny."
    ]
    |> Enum.random()
  end

  defp random_author do
    Enum.random([
      "Marta Lewandowska",
      "Piotr Mazur",
      "Natalia Sobczak",
      "Kamil Zielinski",
      "Aleksandra Wrobel"
    ])
  end

  defp build_slug(title, suffix) do
    base =
      title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")

    "#{base}-#{suffix}"
  end
end

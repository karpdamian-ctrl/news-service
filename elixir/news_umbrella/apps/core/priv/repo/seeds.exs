alias Core.News
alias Core.ContentRenderer.MarkdownProcessor
alias Core.News.{Article, ArticleRevision, Category, Media, Tag}
alias Core.Repo

now = DateTime.utc_now() |> DateTime.truncate(:second)

authors = [
  "Anna Kowalska",
  "Marek Nowak",
  "Julia Zielinska",
  "Piotr Wisniewski",
  "Karolina Wrobel",
  "Tomasz Kaczmarek"
]

category_attrs = [
  %{name: "Technology", slug: "technology", description: "Newsy technologiczne i startupowe."},
  %{name: "Business", slug: "business", description: "Gospodarka, rynek i firmy."},
  %{name: "World", slug: "world", description: "Wydarzenia miedzynarodowe."},
  %{name: "Science", slug: "science", description: "Nauka, badania i odkrycia."},
  %{name: "Culture", slug: "culture", description: "Kultura, sztuka i media."},
  %{name: "Sports", slug: "sports", description: "Sport i wydarzenia ligowe."}
]

tag_attrs = [
  %{name: "AI", slug: "ai"},
  %{name: "Cloud", slug: "cloud"},
  %{name: "Cybersecurity", slug: "cybersecurity"},
  %{name: "Economy", slug: "economy"},
  %{name: "Startups", slug: "startups"},
  %{name: "Research", slug: "research"},
  %{name: "Policy", slug: "policy"},
  %{name: "Markets", slug: "markets"},
  %{name: "Green", slug: "green"},
  %{name: "Media", slug: "media"}
]

headlines = [
  "Nowa fala narzedzi AI zmienia prace redakcji",
  "Rynek chmury rosnie mimo ostroznych budzetow",
  "Europejskie startupy przyspieszaja ekspansje",
  "Nowe regulacje cyberbezpieczenstwa dla firm",
  "Laboratoria pokazaly postepy w energetyce",
  "Wydawcy testuja modele subskrypcyjne premium",
  "Sektor fintech stawia na automatyzacje operacji",
  "Globalne rynki reaguja na dane o inflacji",
  "Nowe satelity poprawia jakosc danych pogodowych",
  "Platformy streamingowe walcza o uwage widzow",
  "Uczelnie zaciesniaja wspolprace z przemyslem",
  "Rosnie znaczenie lokalnych mediow cyfrowych",
  "Branza e-commerce inwestuje w logistyke",
  "Dane otwarte przyspieszaja innowacje w miastach",
  "Firmy wdrazaja polityki zero trust",
  "Biotech notuje rekordowe finansowanie rund",
  "Kultura cyfrowa napedza nowe formaty tresci",
  "Dzialy produktowe upraszczaja roadmapy",
  "Transformacja energetyczna przyciaga kapital",
  "Nowe ligi esportowe przyciagaja sponsorow"
]

statuses = ["published", "draft", "review", "scheduled", "published"]

media_filenames = [
  "city-morning-briefing.jpg",
  "editorial-team-desk.jpg",
  "market-trends-screen.jpg",
  "satellite-weather-map.jpg",
  "streaming-studio-light.jpg",
  "startup-office-meeting.jpg",
  "sports-arena-lights.jpg",
  "science-lab-research.jpg"
]

article_image_section = fn idx ->
  primary = Enum.at(media_filenames, rem(idx - 1, length(media_filenames)))
  secondary = Enum.at(media_filenames, rem(idx + 2, length(media_filenames)))

  cond do
    rem(idx, 4) == 0 ->
      """
      ## Material wizualny

      ![Kontekst artykulu](/uploads/news/#{primary})

      ![Dodatkowa ilustracja](/uploads/news/#{secondary})
      """

    rem(idx, 3) == 0 ->
      """
      ## Material wizualny

      ![Kontekst artykulu](/uploads/news/#{primary})
      """

    true ->
      ""
  end
end

article_body = fn title, idx ->
  """
  # #{title}

  ## TL;DR

  W tym materiale podsumowujemy najwazniejsze sygnaly z rynku oraz wplyw zmian na zespoly produktowe i redakcyjne. Tekst jest przygotowany w formacie markdown, aby latwo bylo go renderowac w aplikacji i API.

  ## Kontekst

  Ostatnie tygodnie przyniosly wyrazne przyspieszenie po stronie wdrozen technologicznych. Organizacje lacza podejscie iteracyjne z lepszym pomiarem efektow, dzieki czemu szybciej odrzucaja hipotezy, ktore nie dowoza oczekiwanej wartosci.

  ## Co zmienia sie operacyjnie

  - zespoly skracaja czas od pomyslu do publikacji,
  - rosnace znaczenie maja metryki jakosci i utrzymania,
  - coraz czesciej decyzje podejmowane sa na podstawie danych dziennych,
  - narzedzia analityczne sa integrowane bezposrednio z workflow.

  ## Wnioski redakcyjne

  Redakcje coraz czesciej pracuja na wspolnym zestawie standardow, aby zachowac spojnosc tresci i tempo publikacji. To oznacza wiecej pracy nad szablonami, ale mniej kosztownych poprawek na koncu procesu.

  ## Cytat eksperta

  > Dobrze przygotowany proces publikacji jest tak samo wazny jak sam temat artykulu.

  #{article_image_section.(idx)}

  ## Co dalej

  W kolejnych dniach bedziemy monitorowac wskazniki adopcji i porownywac wyniki miedzy segmentami. Wersja raportu ##{idx} zostanie rozszerzona o dane kwartalne oraz benchmarki regionalne.
  """
end

description_intro = [
  "Raport redakcyjny o tym, jak zmienia sie temat",
  "Praktyczne podsumowanie decyzji wokol zagadnienia",
  "Krotka analiza trendow i konsekwencji dla obszaru",
  "Komentarz oparty o dane i obserwacje dla tematu",
  "Przeglad najwazniejszych sygnalow dotyczacych watku"
]

description_angle = [
  "pokazuje roznice miedzy deklaracjami a wdrozeniem.",
  "wskazuje, gdzie zespoly najszybciej zyskuja przewage.",
  "porzadkuje ryzyka operacyjne i biznesowe.",
  "tlumaczy, co wplywa na tempo publikacji i decyzji.",
  "wyjasnia, jak laczyc jakosc tresci z wydajnoscia procesu."
]

description_metric = [
  "W materiale zestawiamy KPI, koszty i scenariusze na kolejne tygodnie.",
  "Dodajemy kontekst rynkowy, porownanie podejsc i priorytety wdrozeniowe.",
  "Uwzgledniamy perspektywe odbiorcy, redakcji i zespolu produktowego.",
  "Opisujemy punkty zapalne oraz elementy, ktore najszybciej poprawiaja wynik.",
  "Porownujemy kilka wariantow dzialania i ich wplyw na stabilnosc procesu."
]

description_closure = [
  "Tekst sluzy jako baza do dalszej iteracji i decyzji roadmapowych.",
  "To wersja robocza do szybkiego wdrozenia i dalszych testow.",
  "Material przygotowano pod kolejne aktualizacje i monitoring efektow.",
  "Wniosek: najwiecej zysku daja male kroki wykonywane regularnie.",
  "Artykul domyka etap analizy i otwiera liste kolejnych eksperymentow."
]

pick_variant = fn variants, seed ->
  Enum.at(variants, rem(seed, length(variants)))
end

topic_from_title = fn title ->
  title
  |> String.split(~r/\s+/, trim: true)
  |> Enum.take(4)
  |> Enum.join(" ")
end

article_description = fn title, idx, status ->
  seed = :erlang.phash2("#{title}-#{idx}", 50_000)
  topic = topic_from_title.(title)

  intro = pick_variant.(description_intro, seed)
  angle = pick_variant.(description_angle, seed + 7)
  metric = pick_variant.(description_metric, seed + 13)
  closure = pick_variant.(description_closure, seed + 19)

  status_label =
    case status do
      "published" -> "Material opublikowany i zweryfikowany przez redakcje."
      "draft" -> "Wersja robocza przygotowana do kolejnej iteracji."
      "review" -> "Artykul oczekuje na finalna akceptacje redakcyjna."
      "scheduled" -> "Publikacja zaplanowana w kalendarzu wydawniczym."
      _ -> "Material archiwalny."
    end

  "#{intro} \"#{topic}\" #{angle} #{metric} #{closure} #{status_label} [id:desc-#{idx}-#{seed}]"
end

slugify = fn value ->
  value
  |> String.downcase()
  |> String.replace(~r/[^a-z0-9\s-]/u, "")
  |> String.replace(~r/\s+/, "-")
  |> String.replace(~r/-+/, "-")
  |> String.trim("-")
end

Repo.delete_all(ArticleRevision)
Repo.delete_all("article_categories")
Repo.delete_all("article_tags")
Repo.delete_all(Article)
Repo.delete_all(Media)
Repo.delete_all(Tag)
Repo.delete_all(Category)

categories =
  Enum.map(category_attrs, fn attrs ->
    {:ok, category} = News.create_category(attrs)
    category
  end)

tags =
  Enum.map(tag_attrs, fn attrs ->
    {:ok, tag} = News.create_tag(attrs)
    tag
  end)

media_assets =
  media_filenames
  |> Enum.with_index(1)
  |> Enum.map(fn {filename, idx} ->
    {:ok, media} =
      News.create_media(%{
        type: "image",
        path: "/uploads/news/#{filename}",
        mime_type: "image/jpeg",
        size_bytes: 140_000 + idx * 11_000,
        alt_text: "Ilustracja do materialu #{idx}",
        caption: "Autorska grafika redakcyjna ##{idx}",
        uploaded_by: Enum.at(authors, rem(idx, length(authors)))
      })

    media
  end)

articles =
  headlines
  |> Enum.with_index(1)
  |> Enum.map(fn {title, idx} ->
    slug = slugify.(title) <> "-#{idx}"
    status = Enum.at(statuses, rem(idx, length(statuses)))
    author = Enum.at(authors, rem(idx, length(authors)))

    published_at =
      if status == "published" do
        DateTime.add(now, -idx * 86_400, :second)
      else
        nil
      end

    featured_image = Enum.at(media_assets, rem(idx, length(media_assets)))

    category_ids = [
      Enum.at(categories, rem(idx, length(categories))).id,
      Enum.at(categories, rem(idx + 2, length(categories))).id
    ]

    tag_ids = [
      Enum.at(tags, rem(idx, length(tags))).id,
      Enum.at(tags, rem(idx + 3, length(tags))).id,
      Enum.at(tags, rem(idx + 5, length(tags))).id
    ]

    if category_ids == [] or tag_ids == [] do
      raise "Seed invariant broken: every article must have at least one category and one tag"
    end

    {:ok, article} =
      News.create_article(%{
        title: title,
        slug: slug,
        description: article_description.(title, idx, status),
        content: article_body.(title, idx),
        status: status,
        author: author,
        published_at: published_at,
        is_breaking: rem(idx, 7) == 0,
        view_count: 180 + idx * 37,
        featured_image_id: featured_image.id,
        category_ids: category_ids,
        tag_ids: tag_ids
      })

    article
  end)

rendered_html_count =
  Enum.reduce(articles, 0, fn article, acc ->
    case MarkdownProcessor.process_article(article.id) do
      :ok -> acc + 1
      _ -> acc
    end
  end)

IO.puts(
  "Seed completed: #{length(categories)} categories, #{length(tags)} tags, #{length(media_assets)} media, #{length(articles)} articles, #{rendered_html_count} html renders."
)

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["apps/", "config/", "mix.exs"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: [
        {Credo.Check.Readability.MaxLineLength, max_length: 120}
      ]
    }
  ]
}

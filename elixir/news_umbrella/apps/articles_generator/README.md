# ArticlesGenerator

Subapka odpowiedzialna za automatyczne generowanie artykułów.

- harmonogram publikacji trzymany w Redis (`articles_generator:next_generation_at`)
- interwał losowany między 3 a 6 minut
- publikacja realizowana przez `GenServer` (`ArticlesGenerator.Scheduler`)

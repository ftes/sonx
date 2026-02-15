# Sonx

Elixir port of [ChordSheetJS](https://github.com/martijnversluis/ChordSheetJS) (v14) for parsing and formatting chord sheets. The JS reference source is pinned as a git submodule at `ChordSheetJS/`.

## Commands

- `mix check` — runs compile (warnings-as-errors), test, credo --strict, dialyzer
- `mix test` — 295 tests
- `mix format` — uses Quokka plugin
- `mix credo --strict` — zero issues expected

## Architecture

```
Input String → Parser → %Song{} (IR) → Formatter → Output String
```

All parsers produce a `Sonx.ChordSheet.Song` struct. All formatters consume one.

### Module layout

- `Sonx` — public API facade (`parse/3`, `format/3`, `transpose/2`, `change_key/2`, `use_accidental/2`)
- `Sonx.ChordSheet.*` — IR structs: `Song`, `Line`, `ChordLyricsPair`, `Tag`, `Comment`, `Ternary`, `Literal`, `SoftLineBreak`, `Paragraph`, `Metadata`, `Tags`
- `Sonx.Key` — key representation, transposition, accidental handling, notation conversion
- `Sonx.Chord` — chord (root key + bass key + suffix), delegates to Key for operations
- `Sonx.Scales` — chromatic scale lookup tables (grade ↔ note mappings)
- `Sonx.Parser.*` — `ChordProParser`, `ChordsOverWordsParser`, `UltimateGuitarParser`, `ChordParser`
- `Sonx.Formatter.*` — `TextFormatter`, `ChordProFormatter`, `ChordsOverWordsFormatter`, `HtmlDivFormatter`, `HtmlTableFormatter`, `Html` (shared)
- `Sonx.SongBuilder` — builds Song structs during parsing
- `Sonx.Serializer` — Song ↔ map/JSON
- `Sonx.Renderable` — protocol for renderable items
- `Sonx.Evaluatable` — protocol for evaluatable ternary expressions

### Key design decisions

- **TypedStruct** for all structs
- **NimbleParsec** for ChordPro and ChordsOverWords parsers (mirrors JS Peggy grammars)
- **Protocols** (`Renderable`, `Evaluatable`) for item polymorphism instead of JS duck typing
- **Behaviours** (`Sonx.Parser`, `Sonx.Formatter`) as lightweight contracts
- **`Key.accidental` is nullable** (`nil` = no accidental, matching JS `null`). Do NOT use `:natural` as a default — that was a bug we fixed. The `Scales.grade_to_note` fallback order is: `accidental → :natural → preferred_accidental → :sharp`
- **Public option names** follow JS snake_cased: `:unicode_accidentals`, `:normalize_chords`, `:normalize_chord_suffix`, `:show_minor`, `:evaluate`, `:css_classes`

## Conventions

- Boolean local variables use `?` suffix: `use_unicode?`, `minor?`, `normalize?`
- Boolean struct fields do NOT use `?` suffix (Elixir convention): `minor`, `is_negated`, `optional`
- No `is_` prefix on functions — use `minor?/1` not `is_minor?/1`
- Prefer `nil` over sentinel atoms for "no value". Use `||` to coalesce only when left side can be `nil`
- `mix format` with Quokka handles alias ordering, `Enum.map_join`, etc.

## JS reference

The ChordSheetJS source is at `ChordSheetJS/` (git submodule). Key files for cross-referencing:

| Sonx module | JS reference |
|---|---|
| `Key` | `src/key.ts` |
| `Chord` | `src/chord.ts` |
| `Scales` | `src/scales.ts`, `data/scales.ts` |
| `ChordProParser` | `src/parser/chord_pro/grammar.pegjs` |
| `ChordsOverWordsParser` | `src/parser/chords_over_words/grammar.pegjs` |
| `UltimateGuitarParser` | `src/parser/ultimate_guitar_parser.ts` |
| `ChordParser` | `src/parser/chord/base_grammar.pegjs` |
| `SongBuilder` | `src/song_builder.ts` |
| `TextFormatter` | `src/formatter/text_formatter.ts` |
| `ChordProFormatter` | `src/formatter/chord_pro_formatter.ts` |
| `Html*Formatter` | `src/formatter/templates/html_*_formatter.ts` |
| `Tags` | `src/chord_sheet/tag.ts`, `data/sections.ts` |
| `Song` | `src/chord_sheet/song.ts` |
| `grade_to_note` | `src/utilities.ts` → `determineGrade` / `gradeToKey` |

## Known pitfalls when porting from JS

- JS `null` should map to Elixir `nil`, NOT to an atom like `:natural` or `:none`. Using a non-nil atom makes `||` fallbacks dead code since atoms are truthy.
- JS `NONE` constants (e.g. `line.type = NONE`) are genuine enum values and correctly map to atoms like `:none`.
- JS `useUnicodeModifier` is a deprecated name — we use `:unicode_accidentals` (the "accidental" terminology is the modern JS convention).

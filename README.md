# Sonx

Elixir library for parsing and formatting chord sheets.
An Elixir rewrite of [ChordSheetJS](https://github.com/martijnversluis/ChordSheetJS) (v14).

[![Run in Livebook](https://livebook.dev/badge/v1/blue.svg)](https://livebook.dev/run?url=https%3A%2F%2Fgithub.com%2Fftes%2Fsonx%2Fblob%2Fmain%2Fnotebooks%2Fdemo.livemd)

## Supported formats

**Input (parsers):**

| Format | Atom | Example |
|--------|------|---------|
| [ChordPro](https://www.chordpro.org/) | `:chord_pro` | `{title: My Song}\n[Am]Hello` |
| Chords over words | `:chords_over_words` | `Am\nHello` |
| Ultimate Guitar | `:ultimate_guitar` | `[Verse]\nAm\nHello` |

**Output (formatters):**

| Format | Atom |
|--------|------|
| Plain text | `:text` |
| ChordPro | `:chord_pro` |
| Chords over words | `:chords_over_words` |
| HTML (div-based) | `:html_div` |
| HTML (table-based) | `:html_table` |

## Installation

Add `sonx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sonx, "~> 0.1"}
  ]
end
```

## Quick start

Parse a ChordPro string, inspect metadata, and format as plain text:

```elixir
{:ok, song} = Sonx.parse(:chord_pro, "{title: My Song}\n{key: C}\n[Am]Hello [G]world")

Sonx.title(song)
# => "My Song"

Sonx.get_chords(song)
# => ["Am", "G"]

Sonx.format(:text, song)
# => "My Song\n\nAm    G\nHello world"
```

### Transposing and changing key

```elixir
transposed = Sonx.transpose(song, 3)
Sonx.get_chords(transposed)
# => ["Cm", "A#"]

changed = Sonx.change_key(song, "G")
Sonx.get_chords(changed)
# => ["Em", "D"]
```

### Switching accidentals

```elixir
{:ok, song} = Sonx.parse(:chord_pro, "[C#]Hello")
flat = Sonx.use_accidental(song, :flat)
Sonx.get_chords(flat)
# => ["Db"]
```

### Serialization

Songs can be serialized to JSON and back:

```elixir
json = Sonx.to_json(song)
{:ok, restored} = Sonx.from_json(json)
```

## Architecture

```
Input String → Parser → %Song{} → Formatter → Output String
```

All parsers produce a `Sonx.ChordSheet.Song` struct (the intermediate representation).
All formatters consume one. This makes it easy to mix and match any input format
with any output format, and to apply transformations (transpose, key change) in between.

See the `Sonx` module documentation for the full API reference.

## License

GPL-3.0-or-later. See [LICENSE.md](https://github.com/ftes/sonx/blob/main/LICENSE.md).

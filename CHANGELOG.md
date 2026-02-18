# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]
### Added
- `Sonx.chord_diagrams/2` — generates format-specific chord diagram markup for injection into raw text (e.g. passthrough mode in sonx_book). Supports `:latex_songs` (list of chord names) and `:typst` (keyword options).

### Changed
- Formatter option `:chord_diagrams` now accepts a keyword list of formatter-specific options (e.g., `chord_diagrams: [n: 6]` for Typst `sized-chordlib`). `true` still works.
- Typst formatter: `sized-chordlib` no longer hardcodes `width: 300pt` — omitted by default, letting conchord use its own default
- LaTeX formatter: chord diagrams now use barre notation (parentheses) for barre chords like F, rendering a full bar line instead of individual dots

## [0.1.6] 2026-02-18
### Added
- Formatter option `:chord_diagrams` — opt-in guitar chord diagrams for LaTeX (`\gtab`) and Typst (`sized-chordlib`) formatters
- `Sonx.ChordDiagrams` module — chord name to fret position lookup for common guitar chords

## [0.1.5] 2026-02-18
### Fixed
- Formatter: LaTeX songs — auto-close open sections (`\endverse`/`\endchorus`) before a new section or `\endsong`, fixing errors when input (e.g. from Typst parser) lacks explicit end-of-section tags

## [0.1.4] 2026-02-17
### Added
- Parser: LaTeX songs package (`:latex_songs`) — `\beginsong`/`\endsong` format for the [songs](http://songs.sourceforge.net/) LaTeX package
- Parser: Typst/conchord (`:typst`) — `[Chord] lyrics` inline syntax for the [conchord](https://typst.app/universe/package/conchord/) Typst package
- Formatter: Typst/conchord (`:typst`) — generates Typst files with `chordify` show rule

## [0.1.3] 2026-02-15
### Added
- `Html*Formatter.css_string/0` for default HTML formatter styles

## [0.1.2] 2026-02-15
### Added
- Formatter: UltimateGuitar (`:ultimate_guitar`) — chords-over-words with `[Section]` headers
- Formatter: LaTeX songs package (`:latex_songs`) — `\beginsong`/`\endsong` format for the [songs](http://songs.sourceforge.net/) LaTeX package

## [0.1.1] 2026-02-15
### Fixed
- Small output format issues


## [0.1.0] 2026-02-15
### Added
- Initial release
- Parsers: ChordPro, ChordsOverWords, UltimateGuitar
- Formatters: Text, ChordPro, ChordsOverWords, HtmlDiv, HtmlTable
- Chord operations: transpose, change key, switch accidentals
- JSON serialization

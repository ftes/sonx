defmodule Sonx.ChordSheet.Tags do
  @moduledoc """
  Tag name constants, aliases, and classification functions.
  """

  # Meta directives
  @title "title"
  @subtitle "subtitle"
  @artist "artist"
  @album "album"
  @year "year"
  @composer "composer"
  @lyricist "lyricist"
  @key "key"
  @_key "_key"
  @capo "capo"
  @chord_style "chord_style"
  @tempo "tempo"
  @time "time"
  @arranger "arranger"
  @copyright "copyright"
  @duration "duration"
  @sorttitle "sorttitle"

  # Section directives
  @start_of_chorus "start_of_chorus"
  @end_of_chorus "end_of_chorus"
  @start_of_verse "start_of_verse"
  @end_of_verse "end_of_verse"
  @start_of_bridge "start_of_bridge"
  @end_of_bridge "end_of_bridge"
  @start_of_tab "start_of_tab"
  @end_of_tab "end_of_tab"
  @start_of_grid "start_of_grid"
  @end_of_grid "end_of_grid"
  @start_of_part "start_of_part"
  @end_of_part "end_of_part"
  @start_of_abc "start_of_abc"
  @end_of_abc "end_of_abc"
  @start_of_ly "start_of_ly"
  @end_of_ly "end_of_ly"

  # Other directives
  @comment "comment"
  @chorus "chorus"
  @new_key "new_key"
  @transpose "transpose"

  # Font directives
  @chordfont "chordfont"
  @chordsize "chordsize"
  @chordcolour "chordcolour"
  @textfont "textfont"
  @textsize "textsize"
  @textcolour "textcolour"
  # titlefont, titlesize, titlecolour are defined in the ChordPro spec
  # but not used in tag classification — available as string literals if needed

  @meta_tags [
    @title,
    @subtitle,
    @artist,
    @album,
    @year,
    @composer,
    @lyricist,
    @key,
    @capo,
    @chord_style,
    @tempo,
    @time,
    @arranger,
    @copyright,
    @duration,
    @sorttitle
  ]

  @read_only_tags [@_key]

  @inline_font_tags [
    @chordfont,
    @chordsize,
    @chordcolour,
    @textfont,
    @textsize,
    @textcolour
  ]

  @directives_with_renderable_label [
    @chorus,
    @start_of_abc,
    @start_of_bridge,
    @start_of_chorus,
    @start_of_grid,
    @start_of_ly,
    @start_of_tab,
    @start_of_verse,
    @start_of_part
  ]

  @section_start_tags [
    @start_of_chorus,
    @start_of_verse,
    @start_of_bridge,
    @start_of_tab,
    @start_of_grid,
    @start_of_part,
    @start_of_abc,
    @start_of_ly
  ]

  @section_end_tags [
    @end_of_chorus,
    @end_of_verse,
    @end_of_bridge,
    @end_of_tab,
    @end_of_grid,
    @end_of_part,
    @end_of_abc,
    @end_of_ly
  ]

  @aliases %{
    "t" => @title,
    "st" => @subtitle,
    "c" => @comment,
    "soc" => @start_of_chorus,
    "eoc" => @end_of_chorus,
    "sov" => @start_of_verse,
    "eov" => @end_of_verse,
    "sob" => @start_of_bridge,
    "eob" => @end_of_bridge,
    "sot" => @start_of_tab,
    "eot" => @end_of_tab,
    "sog" => @start_of_grid,
    "eog" => @end_of_grid,
    "sop" => @start_of_part,
    "eop" => @end_of_part,
    "p" => @start_of_part,
    "ep" => @end_of_part,
    "nk" => @new_key,
    "cf" => @chordfont,
    "cs" => @chordsize,
    "tf" => @textfont,
    "ts" => @textsize
  }

  @section_type_map %{
    @start_of_chorus => :chorus,
    @end_of_chorus => :chorus,
    @start_of_verse => :verse,
    @end_of_verse => :verse,
    @start_of_bridge => :bridge,
    @end_of_bridge => :bridge,
    @start_of_tab => :tab,
    @end_of_tab => :tab,
    @start_of_grid => :grid,
    @end_of_grid => :grid,
    @start_of_part => :part,
    @end_of_part => :part,
    @start_of_abc => :abc,
    @end_of_abc => :abc,
    @start_of_ly => :ly,
    @end_of_ly => :ly
  }

  @custom_meta_regex ~r/^x_(.+)$/

  # Public accessors for constants
  def title, do: @title
  def subtitle, do: @subtitle
  def artist, do: @artist
  def album, do: @album
  def year, do: @year
  def composer, do: @composer
  def lyricist, do: @lyricist
  def key, do: @key
  def computed_key, do: @_key
  def capo, do: @capo
  def chord_style, do: @chord_style
  def tempo, do: @tempo
  def time, do: @time
  def arranger, do: @arranger
  def copyright, do: @copyright
  def duration, do: @duration
  def sorttitle, do: @sorttitle
  def comment, do: @comment
  def chorus, do: @chorus
  def new_key, do: @new_key
  def transpose_tag, do: @transpose

  def start_of_chorus, do: @start_of_chorus
  def end_of_chorus, do: @end_of_chorus
  def start_of_verse, do: @start_of_verse
  def end_of_verse, do: @end_of_verse
  def start_of_bridge, do: @start_of_bridge
  def end_of_bridge, do: @end_of_bridge
  def start_of_tab, do: @start_of_tab
  def end_of_tab, do: @end_of_tab
  def start_of_grid, do: @start_of_grid
  def end_of_grid, do: @end_of_grid
  def start_of_part, do: @start_of_part
  def end_of_part, do: @end_of_part

  @doc "Returns the list of meta tag names."
  @spec meta_tags() :: [String.t()]
  def meta_tags, do: @meta_tags

  @doc "Resolves a tag alias to its canonical name."
  @spec resolve_alias(String.t()) :: String.t()
  def resolve_alias(name) do
    trimmed = String.trim(name)
    Map.get(@aliases, trimmed, trimmed)
  end

  @doc "Returns true if this tag name is a meta tag."
  @spec meta_tag?(String.t()) :: boolean()
  def meta_tag?(name) do
    name in @meta_tags or Regex.match?(@custom_meta_regex, name)
  end

  @doc "Returns true if this tag name is read-only."
  @spec read_only_tag?(String.t()) :: boolean()
  def read_only_tag?(name), do: name in @read_only_tags

  @doc "Returns true if this tag name is a section start directive."
  @spec section_start?(String.t()) :: boolean()
  def section_start?(name), do: name in @section_start_tags

  @doc "Returns true if this tag name is a section end directive."
  @spec section_end?(String.t()) :: boolean()
  def section_end?(name), do: name in @section_end_tags

  @doc "Returns true if this tag name is a section delimiter (start or end)."
  @spec section_delimiter?(String.t()) :: boolean()
  def section_delimiter?(name), do: section_start?(name) or section_end?(name)

  @doc "Returns the section type atom for a section tag, or nil."
  @spec section_type(String.t()) :: atom() | nil
  def section_type(name), do: Map.get(@section_type_map, name)

  @doc "Returns true if this tag name is an inline font tag."
  @spec inline_font_tag?(String.t()) :: boolean()
  def inline_font_tag?(name), do: name in @inline_font_tags

  @doc "Returns true if this tag name is a comment."
  @spec comment?(String.t()) :: boolean()
  def comment?(name), do: name == @comment

  @doc "Returns true if this tag name has a renderable label."
  @spec has_renderable_label_directive?(String.t()) :: boolean()
  def has_renderable_label_directive?(name), do: name in @directives_with_renderable_label
end

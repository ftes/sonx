defmodule Sonx.ChordSheet.Tag do
  @moduledoc """
  Represents a tag/directive in a chord sheet.
  See https://www.chordpro.org/chordpro/chordpro-directives/
  """

  use TypedStruct

  alias Sonx.ChordSheet.Tags

  typedstruct do
    field(:name, String.t(), enforce: true)
    field(:original_name, String.t(), enforce: true)
    field(:value, String.t(), default: "")
    field(:attributes, %{String.t() => String.t()}, default: %{})
    field(:selector, String.t() | nil, default: nil)
    field(:is_negated, boolean(), default: false)
  end

  @doc "Creates a new Tag, resolving aliases."
  @spec new(String.t(), String.t() | nil, keyword()) :: t()
  def new(name, value \\ nil, opts \\ []) do
    resolved_name = Tags.resolve_alias(name)

    %__MODULE__{
      name: resolved_name,
      original_name: String.trim(name),
      value: value || "",
      attributes: Keyword.get(opts, :attributes, %{}),
      selector: Keyword.get(opts, :selector),
      is_negated: Keyword.get(opts, :is_negated, false)
    }
  end

  @doc "Returns the label for this tag (attribute label or value)."
  @spec label(t()) :: String.t()
  def label(%__MODULE__{attributes: attrs, value: value}) do
    case Map.get(attrs, "label", "") do
      "" -> value || ""
      label_attr -> label_attr
    end
  end

  @doc "Returns true if the tag has a non-empty value."
  @spec has_value?(t()) :: boolean()
  def has_value?(%__MODULE__{value: ""}), do: false
  def has_value?(%__MODULE__{value: nil}), do: false
  def has_value?(%__MODULE__{}), do: true

  @doc "Returns true if the tag has attributes."
  @spec has_attributes?(t()) :: boolean()
  def has_attributes?(%__MODULE__{attributes: attrs}), do: map_size(attrs) > 0

  @doc "Returns true if the tag has a non-empty label."
  @spec has_label?(t()) :: boolean()
  def has_label?(tag), do: label(tag) != ""

  @doc "Returns true if this is a meta tag."
  @spec meta_tag?(t()) :: boolean()
  def meta_tag?(%__MODULE__{name: name}), do: Tags.meta_tag?(name)

  @doc "Returns true if this is a comment tag."
  @spec comment?(t()) :: boolean()
  def comment?(%__MODULE__{name: name}), do: Tags.comment?(name)

  @doc "Returns true if this is a section start tag."
  @spec section_start?(t()) :: boolean()
  def section_start?(%__MODULE__{name: name}), do: Tags.section_start?(name)

  @doc "Returns true if this is a section end tag."
  @spec section_end?(t()) :: boolean()
  def section_end?(%__MODULE__{name: name}), do: Tags.section_end?(name)

  @doc "Returns true if this is a section delimiter (start or end)."
  @spec section_delimiter?(t()) :: boolean()
  def section_delimiter?(tag), do: section_start?(tag) or section_end?(tag)

  @doc "Returns the section type for this tag, or nil."
  @spec section_type(t()) :: atom() | nil
  def section_type(%__MODULE__{name: name}), do: Tags.section_type(name)

  @doc "Returns true if this tag should be rendered."
  @spec renderable?(t()) :: boolean()
  def renderable?(tag) do
    comment?(tag) or has_renderable_label?(tag)
  end

  @doc "Returns true if this tag has a renderable label."
  @spec has_renderable_label?(t()) :: boolean()
  def has_renderable_label?(tag) do
    (Tags.has_renderable_label_directive?(tag.name) or section_start?(tag)) and
      has_label?(tag)
  end

  @doc "Returns a new tag with the given value."
  @spec set(t(), keyword()) :: t()
  def set(%__MODULE__{} = tag, attrs) do
    %__MODULE__{
      name: tag.name,
      original_name: tag.original_name,
      value: Keyword.get(attrs, :value, tag.value),
      attributes: Keyword.get(attrs, :attributes, tag.attributes),
      selector: tag.selector,
      is_negated: tag.is_negated
    }
  end

  @spec clone(t()) :: t()
  def clone(%__MODULE__{} = tag) do
    %__MODULE__{
      name: tag.name,
      original_name: tag.original_name,
      value: tag.value,
      attributes: tag.attributes,
      selector: tag.selector,
      is_negated: tag.is_negated
    }
  end
end

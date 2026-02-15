defmodule Sonx.ChordSheet do
  @moduledoc """
  Shared types for chord sheet items.
  """

  alias Sonx.ChordSheet.{
    ChordLyricsPair,
    Comment,
    Literal,
    SoftLineBreak,
    Tag,
    Ternary
  }

  @type item() ::
          ChordLyricsPair.t()
          | Tag.t()
          | Comment.t()
          | Ternary.t()
          | Literal.t()
          | SoftLineBreak.t()

  @type evaluatable() :: Ternary.t() | Literal.t()
end

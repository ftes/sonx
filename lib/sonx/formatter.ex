defmodule Sonx.Formatter do
  @moduledoc """
  Behaviour for chord sheet formatters.
  """

  alias Sonx.ChordSheet.Song

  @callback format(Song.t(), keyword()) :: String.t()
end

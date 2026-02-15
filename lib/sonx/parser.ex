defmodule Sonx.Parser do
  @moduledoc """
  Behaviour for chord sheet parsers.
  """

  alias Sonx.ChordSheet.Song

  @callback parse(String.t(), keyword()) :: {:ok, Song.t()} | {:error, term()}
end

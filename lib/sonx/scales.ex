defmodule Sonx.Scales do
  @moduledoc """
  Scale lookup tables mapping between keys/notes and chromatic grades (0..11).

  Two main maps:
  - `key_to_grade/0` — given a chord type, mode, accidental, and note string, returns the grade
  - `grade_to_key/0` — given a chord type, mode, accidental, and grade, returns the note string
  """

  @type chord_type() :: :symbol | :solfege | :numeric | :numeral
  @type mode() :: :major | :minor
  @type accidental_key() :: :natural | :sharp | :flat

  @doc "Returns the key-to-grade lookup map."
  @spec key_to_grade() :: %{
          chord_type() => %{
            mode() => %{
              accidental_key() => %{String.t() => non_neg_integer()}
            }
          }
        }
  def key_to_grade do
    %{
      symbol: %{
        major: %{
          natural: %{"C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11},
          sharp: %{"B" => 0, "C" => 1, "D" => 3, "E" => 5, "F" => 6, "G" => 8, "A" => 10},
          flat: %{"D" => 1, "E" => 3, "F" => 4, "G" => 6, "A" => 8, "B" => 10, "C" => 11}
        },
        minor: %{
          natural: %{"C" => 0, "D" => 2, "E" => 4, "F" => 5, "G" => 7, "A" => 9, "B" => 11},
          sharp: %{"B" => 0, "C" => 1, "D" => 3, "E" => 5, "F" => 6, "G" => 8, "A" => 10},
          flat: %{"D" => 1, "E" => 3, "F" => 4, "G" => 6, "A" => 8, "B" => 10, "C" => 11}
        }
      },
      solfege: %{
        major: %{
          natural: %{
            "Do" => 0,
            "Re" => 2,
            "Mi" => 4,
            "Fa" => 5,
            "Sol" => 7,
            "La" => 9,
            "Si" => 11
          },
          sharp: %{
            "Si" => 0,
            "Do" => 1,
            "Re" => 3,
            "Mi" => 5,
            "Fa" => 6,
            "Sol" => 8,
            "La" => 10
          },
          flat: %{
            "Re" => 1,
            "Mi" => 3,
            "Fa" => 4,
            "Sol" => 6,
            "La" => 8,
            "Si" => 10,
            "Do" => 11
          }
        },
        minor: %{
          natural: %{
            "Do" => 0,
            "Re" => 2,
            "Mi" => 4,
            "Fa" => 5,
            "Sol" => 7,
            "La" => 9,
            "Si" => 11
          },
          sharp: %{
            "Si" => 0,
            "Do" => 1,
            "Re" => 3,
            "Mi" => 5,
            "Fa" => 6,
            "Sol" => 8,
            "La" => 10
          },
          flat: %{
            "Re" => 1,
            "Mi" => 3,
            "Fa" => 4,
            "Sol" => 6,
            "La" => 8,
            "Si" => 10,
            "Do" => 11
          }
        }
      },
      numeric: %{
        major: %{
          natural: %{"1" => 0, "2" => 2, "3" => 4, "4" => 5, "5" => 7, "6" => 9, "7" => 11},
          sharp: %{"7" => 0, "1" => 1, "2" => 3, "3" => 5, "4" => 6, "5" => 8, "6" => 10},
          flat: %{"2" => 1, "3" => 3, "4" => 4, "5" => 6, "6" => 8, "7" => 10, "1" => 11}
        },
        minor: %{
          natural: %{"1" => 0, "2" => 2, "3" => 3, "4" => 5, "5" => 7, "6" => 8, "7" => 10},
          sharp: %{"1" => 1, "2" => 3, "3" => 4, "4" => 6, "5" => 8, "6" => 9, "7" => 11},
          flat: %{"2" => 1, "3" => 2, "4" => 4, "5" => 6, "6" => 7, "7" => 9, "1" => 11}
        }
      },
      numeral: %{
        major: %{
          natural: %{"I" => 0, "II" => 2, "III" => 4, "IV" => 5, "V" => 7, "VI" => 9, "VII" => 11},
          sharp: %{
            "VII" => 0,
            "I" => 1,
            "II" => 3,
            "III" => 5,
            "IV" => 6,
            "V" => 8,
            "VI" => 10
          },
          flat: %{
            "II" => 1,
            "III" => 3,
            "IV" => 4,
            "V" => 6,
            "VI" => 8,
            "VII" => 10,
            "I" => 11
          }
        },
        minor: %{
          natural: %{"I" => 0, "II" => 2, "III" => 3, "IV" => 5, "V" => 7, "VI" => 8, "VII" => 10},
          sharp: %{
            "I" => 1,
            "II" => 3,
            "III" => 4,
            "IV" => 6,
            "V" => 8,
            "VI" => 9,
            "VII" => 11
          },
          flat: %{
            "II" => 1,
            "III" => 2,
            "IV" => 4,
            "V" => 6,
            "VI" => 7,
            "VII" => 9,
            "I" => 11
          }
        }
      }
    }
  end

  @doc "Returns the grade-to-key lookup map."
  @spec grade_to_key() :: %{
          chord_type() => %{
            mode() => %{
              accidental_key() => %{non_neg_integer() => String.t()}
            }
          }
        }
  def grade_to_key do
    %{
      symbol: %{
        major: %{
          natural: %{0 => "C", 2 => "D", 4 => "E", 5 => "F", 7 => "G", 9 => "A", 11 => "B"},
          sharp: %{0 => "B#", 1 => "C#", 3 => "D#", 5 => "E#", 6 => "F#", 8 => "G#", 10 => "A#"},
          flat: %{1 => "Db", 3 => "Eb", 4 => "Fb", 6 => "Gb", 8 => "Ab", 10 => "Bb", 11 => "Cb"}
        },
        minor: %{
          natural: %{0 => "C", 2 => "D", 4 => "E", 5 => "F", 7 => "G", 9 => "A", 11 => "B"},
          sharp: %{0 => "B#", 1 => "C#", 3 => "D#", 5 => "E#", 6 => "F#", 8 => "G#", 10 => "A#"},
          flat: %{1 => "Db", 3 => "Eb", 4 => "Fb", 6 => "Gb", 8 => "Ab", 10 => "Bb", 11 => "Cb"}
        }
      },
      solfege: %{
        major: %{
          natural: %{
            0 => "Do",
            2 => "Re",
            4 => "Mi",
            5 => "Fa",
            7 => "Sol",
            9 => "La",
            11 => "Si"
          },
          sharp: %{
            0 => "Si#",
            1 => "Do#",
            3 => "Re#",
            5 => "Mi#",
            6 => "Fa#",
            8 => "Sol#",
            10 => "La#"
          },
          flat: %{
            1 => "Reb",
            3 => "Mib",
            4 => "Fab",
            6 => "Solb",
            8 => "Lab",
            10 => "Sib",
            11 => "Dob"
          }
        },
        minor: %{
          natural: %{
            0 => "Do",
            2 => "Re",
            4 => "Mi",
            5 => "Fa",
            7 => "Sol",
            9 => "La",
            11 => "Si"
          },
          sharp: %{
            0 => "Si#",
            1 => "Do#",
            3 => "Re#",
            5 => "Mi#",
            6 => "Fa#",
            8 => "Sol#",
            10 => "La#"
          },
          flat: %{
            1 => "Reb",
            3 => "Mib",
            4 => "Fab",
            6 => "Solb",
            8 => "Lab",
            10 => "Sib",
            11 => "Dob"
          }
        }
      },
      numeric: %{
        major: %{
          natural: %{0 => "1", 2 => "2", 4 => "3", 5 => "4", 7 => "5", 9 => "6", 11 => "7"},
          sharp: %{0 => "#7", 1 => "#1", 3 => "#2", 5 => "#3", 6 => "#4", 8 => "#5", 10 => "#6"},
          flat: %{1 => "b2", 3 => "b3", 4 => "b4", 6 => "b5", 8 => "b6", 10 => "b7", 11 => "b1"}
        },
        minor: %{
          natural: %{0 => "1", 2 => "2", 3 => "3", 5 => "4", 7 => "5", 8 => "6", 10 => "7"},
          sharp: %{1 => "#1", 3 => "#2", 4 => "#3", 6 => "#4", 8 => "#5", 9 => "#6", 11 => "#7"},
          flat: %{1 => "b2", 2 => "b3", 4 => "b4", 6 => "b5", 7 => "b6", 9 => "b7", 11 => "b1"}
        }
      },
      numeral: %{
        major: %{
          natural: %{0 => "I", 2 => "II", 4 => "III", 5 => "IV", 7 => "V", 9 => "VI", 11 => "VII"},
          sharp: %{
            0 => "#VII",
            1 => "#I",
            3 => "#II",
            5 => "#III",
            6 => "#IV",
            8 => "#V",
            10 => "#VI"
          },
          flat: %{
            1 => "bII",
            3 => "bIII",
            4 => "bIV",
            6 => "bV",
            8 => "bVI",
            10 => "bVII",
            11 => "bI"
          }
        },
        minor: %{
          natural: %{0 => "I", 2 => "II", 3 => "III", 5 => "IV", 7 => "V", 8 => "VI", 10 => "VII"},
          sharp: %{
            1 => "#I",
            3 => "#II",
            4 => "#III",
            6 => "#IV",
            8 => "#V",
            9 => "#VI",
            11 => "#VII"
          },
          flat: %{
            1 => "bII",
            2 => "bIII",
            4 => "bIV",
            6 => "bV",
            7 => "bVI",
            9 => "bVII",
            11 => "bI"
          }
        }
      }
    }
  end

  @roman_numerals ~w(I II III IV V VI VII)

  @doc "Returns the list of roman numerals I through VII."
  @spec roman_numerals() :: [String.t()]
  def roman_numerals, do: @roman_numerals

  @doc "Looks up the grade for the given chord type, mode, accidental, and note string."
  @spec to_grade(chord_type(), mode(), accidental_key(), String.t()) :: non_neg_integer() | nil
  def to_grade(type, mode, accidental, note) do
    key_to_grade()
    |> get_in([type, mode, accidental, note])
  end

  @doc "Looks up the note string for the given chord type, mode, accidental, and grade."
  @spec to_note(chord_type(), mode(), accidental_key(), non_neg_integer()) :: String.t() | nil
  def to_note(type, mode, accidental, grade) do
    grade_to_key()
    |> get_in([type, mode, accidental, grade])
  end

  @doc """
  Resolves a grade to a note string, using the JS fallback order:
  accidental → natural → preferred_accidental → sharp.
  """
  @spec grade_to_note(chord_type(), non_neg_integer(), accidental_key() | nil, accidental_key() | nil, boolean()) ::
          String.t()
  def grade_to_note(type, grade, accidental, preferred_accidental, minor?) do
    mode = if minor?, do: :minor, else: :major
    grades_map = grade_to_key()[type][mode]

    fallback_order =
      [accidental, :natural, preferred_accidental, :sharp]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    Enum.find_value(fallback_order, fn acc ->
      Map.get(grades_map[acc] || %{}, grade)
    end)
  end
end

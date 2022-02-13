defmodule WordleSolver do
  use Application

  defp process_data(data) do
    data
    |> String.split("\n")
    |> Enum.map(fn x ->
      spl = String.split(x, " ")
      %{Enum.at(spl, 0) => elem(Float.parse(Enum.at(spl, 1)), 0)}
    end)
    |> Enum.reduce(%{}, &Map.merge(&1, &2))
  end

  defp fetch_data do
    short =
      File.read!("data/short_freqs.txt")
      |> process_data

    long =
      File.read!("data/long_freqs.txt")
      |> process_data

    {short, long}
  end

  defp merge_guess_result(letters, guess_result, guess) do
    guess_result
    |> String.upcase()
    |> String.trim()
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(letters, fn {status, idx}, acc ->
      letter = String.at(guess, idx)

      case status do
        "N" ->
          cond do
            Map.has_key?(acc, letter) ->
              case Map.get(acc, letter) do
                :none ->
                  acc

                %{at: x, not_at: y} ->
                  Map.put(acc, letter, %{at: x, not_at: Enum.uniq([idx | y])})
              end

            true ->
              Map.put(acc, letter, :none)
          end

        "Y" ->
          cond do
            Map.has_key?(acc, letter) ->
              %{at: x, not_at: y} = Map.get(acc, letter)
              Map.put(acc, letter, %{at: x, not_at: Enum.uniq([idx | y])})

            true ->
              Map.put(acc, letter, %{at: [], not_at: [idx]})
          end

        "G" ->
          cond do
            Map.has_key?(acc, letter) ->
              %{at: x, not_at: y} = Map.get(acc, letter)
              Map.put(acc, letter, %{at: Enum.uniq([idx | x]), not_at: y})

            true ->
              Map.put(acc, letter, %{at: [idx], not_at: []})
          end
      end
    end)
  end

  defp filter_data(data, letters) do
    keys =
      data
      |> Map.keys()
      |> Enum.filter(fn w ->
        Enum.all?(Map.keys(letters), fn l ->
          case letters[l] do
            :none ->
              not String.contains?(w, l)

            %{at: a, not_at: na} ->
              Enum.all?(a, fn x ->
                String.at(w, x) == l
              end) and
                Enum.all?(na, fn x ->
                  String.at(w, x) != l
                end) and
                String.contains?(w, l)
          end
        end)
      end)

    Map.take(data, keys)
  end

  defp next_guess(data) do
    {_, word} =
      data
      |> Map.keys()
      |> Enum.reduce({0, nil}, fn x, {freq, word} ->
        cond do
          data[x] > freq -> {data[x], x}
          true -> {freq, word}
        end
      end)

    {word, Map.delete(data, word)}
  end

  defp run_rec(data, letters, guess) do
    guess_result = IO.gets("Enter your guess result: ")

    cleaned_result =
      guess_result
      |> String.trim()

    cond do
      String.upcase(cleaned_result) |> String.contains?("Q") ->
        :ok

      not String.match?(cleaned_result, ~r/([nygNYG])\w+/) ->
        run_rec(data, letters, guess)

      true ->
        new_letters = merge_guess_result(letters, guess_result, guess)

        {new_guess, new_data} =
          data
          |> filter_data(new_letters)
          |> next_guess

        IO.puts("Input: " <> new_guess)

        run_rec(new_data, new_letters, new_guess)
    end
  end

  def run do
    {short, long} = fetch_data()
    IO.puts("Input your guess results as N: Grey, Y: Yellow, G: Green.")
    IO.puts("Input Q to quit")
    IO.puts("An example input would be:")
    IO.puts("NNYGN")
    IO.puts("Input: crane")
    run_rec(Map.merge(short, long), %{}, "crane")
  end

  def start(_type, _args) do
    run()
  end
end

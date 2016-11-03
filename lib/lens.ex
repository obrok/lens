defmodule Lens do
  use Lens.Macros

  @opaque t :: function

  @doc """
  Returns a lens that does not focus on any part of the data.

      iex> Lens.to_list([:anything], Lens.empty)
      []
  """
  @spec empty :: t
  deflens empty do
    fn data, _fun -> {[], data} end
  end

  @doc """
  Returns a lens that focuses on the whole data.

      iex> Lens.to_list(:data, Lens.root)
      [:data]
      iex> Lens.map(:data, Lens.root, fn :data -> :other_data end)
      :other_data
  """
  @spec root :: t
  deflens root do
    fn data, fun ->
      {res, updated} = fun.(data)
      {[res], updated}
    end
  end

  deflens match(matcher_fun) do
    fn data, fun ->
      get_and_map(data, matcher_fun.(data), fun)
    end
  end

  deflens at(index) do
    fn data, fun ->
      {res, updated} = fun.(get_at_index(data, index))
      {[res], set_at_index(data, index, updated)}
    end
  end

  @doc """
  Creates a lens that assumes the data is a map and focuses on the value under `key`.

      iex> Lens.to_list(%{foo: 1, bar: 2}, Lens.key(:foo))
      [1]
      iex> Lens.map(%{foo: 1, bar: 2}, Lens.key(:foo), fn x -> x + 10 end)
      %{foo: 11, bar: 2}

  If the key doesn't exist in the map a nil will be returned or passed to the update function.

      iex> Lens.to_list(%{}, Lens.key(:foo))
      [nil]
      iex> Lens.map(%{}, Lens.key(:foo), fn nil -> 3 end)
      %{foo: 3}
  """
  @spec key(any) :: t
  deflens key(key) do
    fn data, fun ->
      {res, updated} = fun.(Map.get(data, key))
      {[res], Map.put(data, key, updated)}
    end
  end

  deflens keys(keys) do
    fn data, fun ->
      {res, changed} = Enum.reduce(keys, {[], data}, fn key, {results, data} ->
        {res, changed} = fun.(Map.get(data, key))
        {[res | results], Map.put(data, key, changed)}
      end)

      {Enum.reverse(res), changed}
    end
  end

  deflens all, do: filter(fn _ -> true end)

  deflens seq(lens1, lens2) do
    fn data, fun ->
      {res, changed} = get_and_map(data, lens1, fn item ->
        get_and_map(item, lens2, fun)
      end)
      {Enum.concat(res), changed}
    end
  end

  deflens seq_both(lens1, lens2), do: Lens.both(Lens.seq(lens1, lens2), lens1)

  deflens recur(lens), do: &do_recur(lens, &1, &2)

  deflens both(lens1, lens2) do
    fn data, fun ->
      {res1, changed1} = get_and_map(data, lens1, fun)
      {res2, changed2} = get_and_map(changed1, lens2, fun)
      {res1 ++ res2, changed2}
    end
  end

  deflens filter(filter_fun) do
    fn data, fun ->
      {res, updated} = Enum.reduce(data, {[], []}, fn item, {res, updated} ->
        if filter_fun.(item) do
          {res_item, updated_item} = fun.(item)
          {[res_item | res], [updated_item | updated]}
        else
          {res, [item | updated]}
        end
      end)
      {Enum.reverse(res), Enum.reverse(updated)}
    end
  end

  deflens satisfy(lens, filter_fun) do
    fn data, fun ->
      {res, changed} = get_and_map(data, lens, fn item ->
        if filter_fun.(item) do
          {res, changed} = fun.(item)
          {[res], changed}
        else
          {[], item}
        end
      end)
      {Enum.concat(res), changed}
    end
  end

  def to_list(data, lens) do
    {list, _} = get_and_map(data, lens, &{&1, &1})
    list
  end

  def each(data, lens, fun) do
    {_, _} = get_and_map(data, lens, &{nil, fun.(&1)})
  end

  def map(data, lens, fun) do
    {_, changed} = get_and_map(data, lens, &{nil, fun.(&1)})
    changed
  end

  def get_and_map(data, lens, fun) do
    lens.(data, fun)
  end

  defp do_recur(lens, data, fun) do
    {res, changed} = get_and_map(data, lens, fn item ->
      {results, changed1} = do_recur(lens, item, fun)
      {res_parent, changed2} = fun.(changed1)
      {[res_parent | results], changed2}
    end)

    {Enum.concat(res), changed}
  end

  defp get_at_index(data, index) when is_tuple(data), do: elem(data, index)
  defp get_at_index(data, index), do: Enum.at(data, index)

  defp set_at_index(data, index, value) when is_tuple(data), do: put_elem(data, index, value)
  defp set_at_index(data, index, value) when is_list(data) do
    List.update_at(data, index, fn _ -> value end)
  end

end

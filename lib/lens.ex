defmodule Lens do
  use Lens.Macros

  @opaque t :: (:get, any, function -> list(any)) | (:get_and_update, any, function -> {list(any), any})

  @doc ~S"""
  Returns a lens that does not focus on any part of the data.

      iex> Lens.empty |> Lens.get(:anything)
      []
      iex> Lens.empty |> Lens.map(1, &(&1 + 1))
      1
  """
  @spec empty :: t
  deflens_raw empty do
    fn data, _fun -> {[], data} end
  end

  @doc ~S"""
  Returns a lens that focuses on the whole data.

      iex> Lens.to_list(Lens.root, :data)
      [:data]
      iex> Lens.map(Lens.root, :data, fn :data -> :other_data end)
      :other_data
  """
  @spec root :: t
  deflens_raw root do
    fn data, fun ->
      {res, updated} = fun.(data)
      {[res], updated}
    end
  end

  @doc ~S"""
  Select the lens to use based on a matcher function

      iex> selector = fn
      ...>   {:a, _} -> Lens.at(1)
      ...>   {:b, _, _} -> Lens.at(2)
      ...> end
      iex> Lens.match(selector) |> Lens.get({:b, 2, 3})
      3
  """
  @spec match((any -> t)) :: t
  deflens_raw match(matcher_fun) do
    fn data, fun ->
      get_and_map(matcher_fun.(data), data, fun)
    end
  end

  @doc ~S"""
  Returns a lens that focuses on the n-th element of a list or tuple.

      iex> Lens.at(2) |> Lens.get({:a, :b, :c})
      :c
      iex> Lens.at(1) |> Lens.map([:a, :b, :c], fn :b -> :d end)
      [:a, :d, :c]
  """
  @spec at(Integer) :: t
  deflens_raw at(index) do
    fn data, fun ->
      {res, updated} = fun.(get_at_index(data, index))
      {[res], set_at_index(data, index, updated)}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on the value under `key`.

      iex> Lens.to_list(Lens.key(:foo), %{foo: 1, bar: 2})
      [1]
      iex> Lens.map(Lens.key(:foo), %{foo: 1, bar: 2}, fn x -> x + 10 end)
      %{foo: 11, bar: 2}

  If the key doesn't exist in the map a nil will be returned or passed to the update function.

      iex> Lens.to_list(Lens.key(:foo), %{})
      [nil]
      iex> Lens.map(Lens.key(:foo), %{}, fn nil -> 3 end)
      %{foo: 3}
  """
  @spec key(any) :: t
  deflens_raw key(key) do
    fn data, fun ->
      {res, updated} = fun.(get_at_key(data, key))
      {[res], set_at_key(data, key, updated)}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on the value under the given key. If the key does not exist an error will be raised.

      iex> Lens.key!(:a) |> Lens.get(%{a: 1, b: 2})
      1
      iex> Lens.key!(:a) |> Lens.get([a: 1, b: 2])
      1
      iex> Lens.key!(:c) |> Lens.get(%{a: 1, b: 2})
      ** (KeyError) key :c not found in: %{a: 1, b: 2}
  """
  @spec key!(any) :: t
  deflens_raw key!(key) do
    fn data, fun ->
      {res, updated} = fun.(fetch_at_key!(data, key))
      {[res], set_at_key(data, key, updated)}
    end
  end

  @doc ~S"""
  Returns a lens that focuses on the values of all the keys.

      iex> Lens.keys([:a, :c]) |> Lens.get(%{a: 1, b: 2, c: 3})
      [1, 3]
      iex> Lens.keys([:a, :c]) |> Lens.map([a: 1, b: 2, c: 3], &(&1 + 1))
      [a: 2, b: 2, c: 4]
  """
  @spec keys(nonempty_list(any)) :: t
  deflens keys(keys), do:
    keys |> Enum.map(&Lens.key/1) |> Enum.reverse |> Enum.reduce(Lens.empty, &Lens.both/2)

  @doc ~S"""
  Returns a lens that focuses on the values of all the keys. If any of the keys does not exist, an error is raised.

      iex> Lens.keys!([:a, :c]) |> Lens.get(%{a: 1, b: 2, c: 3})
      [1, 3]
      iex> Lens.keys!([:a, :c]) |> Lens.map([a: 1, b: 2, c: 3], &(&1 + 1))
      [a: 2, b: 2, c: 4]
      iex> Lens.keys!([:a, :c]) |> Lens.get(%{a: 1, b: 2})
      ** (KeyError) key :c not found in: %{a: 1, b: 2}
  """
  @spec keys!(nonempty_list(any)) :: t
  deflens keys!(keys), do:
    keys |> Enum.map(&Lens.key!/1) |> Enum.reverse |> Enum.reduce(Lens.empty, &Lens.both/2)

  @doc ~S"""
  Returns a lens that focuses on all the values in an enumerable.

      iex> Lens.all |> Lens.get([1, 2, 3])
      [1, 2, 3]
  """
  @spec all :: t
  deflens all, do: filter(fn _ -> true end)

  @doc ~S"""
  Compose a pair of lens by applying the second to the result of the first

      iex> Lens.seq(Lens.key(:a), Lens.key(:b)) |> Lens.get(%{a: %{b: 3}})
      3

  Piping lenses has the exact same effect:

      iex> Lens.key(:a) |> Lens.key(:b) |> Lens.get(%{a: %{b: 3}})
      3
  """
  @spec seq(t, t) :: t
  deflens_raw seq(lens1, lens2) do
    fn data, fun ->
      {res, changed} = get_and_map(lens1, data, fn item ->
        get_and_map(lens2, item, fun)
      end)
      {Enum.concat(res), changed}
    end
  end

  @doc ~S"""
  Combine the composition of both lens with the first one.

      iex> Lens.seq_both(Lens.key(:a), Lens.key(:b)) |> Lens.get(%{a: %{b: :c}})
      [:c, %{b: :c}]
  """
  @spec seq_both(t, t) :: t
  deflens seq_both(lens1, lens2), do: Lens.both(Lens.seq(lens1, lens2), lens1)

  @doc ~S"""
  Make a lens recursive

      iex> data = %{
      ...>    items: [
      ...>      %{v: 1, items: []},
      ...>      %{v: 2, items: [
      ...>        %{v: 3, items: []}
      ...>      ]}
      ...> ]}
      iex> lens = Lens.recur(Lens.key(:items) |> Lens.all) |> Lens.key(:v)
      iex> Lens.get(lens, data)
      [1, 2, 3]
  """
  @spec recur(t) :: t
  deflens_raw recur(lens), do: &do_recur(lens, &1, &2)

  @doc ~S"""
  Returns a lens that focuses on what both the lenses focus on.

      iex> Lens.both(Lens.key(:a), Lens.key(:b) |> Lens.at(1)) |> Lens.get(%{a: 1, b: [2, 3]})
      [1, 3]
  """
  @spec both(t, t) :: t
  deflens_raw both(lens1, lens2) do
    fn data, fun ->
      {res1, changed1} = get_and_map(lens1, data, fun)
      {res2, changed2} = get_and_map(lens2, changed1, fun)
      {res1 ++ res2, changed2}
    end
  end

  @doc ~S"""
  Returns lens that focuses on all the elements of an enumerable that satisfy the given condition.

      iex> Lens.filter(&Integer.is_odd/1) |> Lens.get([1, 2, 3, 4])
      [1, 3]
      iex> Lens.filter(&Integer.is_odd/1) |> Lens.map([1, 2, 3, 4], &(&1 + 1))
      [2, 2, 4, 4]
  """
  @spec filter((any -> boolean)) :: t
  deflens_raw filter(filter_fun) do
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

  @doc ~S"""
  Returns a lens that focuses on a subset of elements focused on by the given lens that satisfy the given condition.

      iex> Lens.keys([:a, :b]) |> Lens.satisfy(&Integer.is_odd/1) |> Lens.get(%{a: 1, b: 2})
      1
  """
  @spec satisfy(t, (any -> boolean)) :: t
  deflens_raw satisfy(lens, filter_fun) do
    fn data, fun ->
      {res, changed} = get_and_map(lens, data, fn item ->
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

  @doc ~S"""
  Returns a list of values that the lens focuses on in the given data.

      iex> Lens.keys([:a, :c]) |> Lens.to_list(%{a: 1, b: 2, c: 3})
      [1, 3]
  """
  @spec to_list(t, any) :: list(any)
  def to_list(lens, data), do: get_in(data, [lens])

  @doc ~S"""
  Performs a side effect for each values this lens focuses on in the given data.

      iex> data = %{a: 1, b: 2, c: 3}
      iex> fun = fn -> Lens.keys([:a, :c]) |> Lens.each(data, &IO.inspect/1) end
      iex> import ExUnit.CaptureIO
      iex> capture_io(fun)
      "1\n3\n"
  """
  @spec each(t, any, (any -> any)) :: :ok
  def each(lens, data, fun), do: to_list(lens, data) |> Enum.each(fun)

  @doc ~S"""
  Returns an updated version of the data by applying the given function to each value the lens focuses on and building
  a data structure of the same shape with the updated values in place of the original ones.

      iex> data = [1, 2, 3, 4]
      iex> Lens.filter(&Integer.is_odd/1) |> Lens.map(data, fn v -> v + 10 end)
      [11, 2, 13, 4]
  """
  @spec map(t, any, (any -> any)) :: any
  def map(lens, data, fun), do: update_in(data, [lens], fun)

  @doc ~S"""
  Returns an updated version of the data and a transformed value from each location the lens focuses on. The
  transformation function must return a tuple `{value_to_return, value_to_update}`.

      iex> data = %{a: 1, b: 2, c: 3}
      iex> Lens.keys([:a, :b, :c])
      ...> |> Lens.satisfy(&Integer.is_odd/1)
      ...> |> Lens.get_and_map(data, fn v -> {v + 1, v + 10} end)
      {[2, 4], %{a: 11, b: 2, c: 13}}
  """
  @spec get_and_map(t, any, (any -> {any, any})) :: {list(any), any}
  def get_and_map(lens, data, fun), do: get_and_update_in(data, [lens], fun)

  @doc ~S"""
  Executes `to_list` and returns the first item if the list has only one item otherwise the full list.
  """
  @spec get(t, any) :: any
  def get(lens, data), do: to_list(lens, data) |> fn [x] -> x; x -> x end.()

  defp do_recur(lens, data, fun) do
    {res, changed} = get_and_map(lens, data, fn item ->
      {results, changed1} = do_recur(lens, item, fun)
      {res_parent, changed2} = fun.(changed1)
      {[res_parent | results], changed2}
    end)

    {Enum.concat(res), changed}
  end

  defp get_at_key(data, key) when is_map(data), do: Map.get(data, key)
  defp get_at_key(data, key), do: Access.get(data, key)

  defp set_at_key(data, key, value) when is_map(data), do: Map.put(data, key, value)
  defp set_at_key(data, key, value) do
    {_, updated} = Access.get_and_update(data, key, fn _ -> {nil, value} end)
    updated
  end

  defp fetch_at_key!(data, key) when is_map(data), do: Map.fetch!(data, key)
  defp fetch_at_key!(data, key) do
    case Access.fetch(data, key) do
      :error -> raise(KeyError, key: key, term: data)
      {:ok, value} -> value
    end
  end

  defp get_at_index(data, index) when is_tuple(data), do: elem(data, index)
  defp get_at_index(data, index), do: Enum.at(data, index)

  defp set_at_index(data, index, value) when is_tuple(data), do: put_elem(data, index, value)
  defp set_at_index(data, index, value) when is_list(data) do
    List.update_at(data, index, fn _ -> value end)
  end
end

defmodule Lens do
  def empty do
    fn data, _fun -> {[], data} end
  end

  def match(matcher_fun) do
    fn data, fun ->
      get_and_map(data, matcher_fun.(data), fun)
    end
  end

  def at(index) do
    fn data, fun ->
      {res, updated} = fun.(elem(data, index))
      {[res], put_elem(data, index, updated)}
    end
  end

  def key(key) do
    fn data, fun ->
      {res, updated} = fun.(data[key])
      {[res], Map.put(data, key, updated)}
    end
  end

  def keys(keys) do
    fn data, fun ->
      {res, changed} = Enum.reduce(keys, {[], data}, fn key, {results, data} ->
        {res, changed} = fun.(data[key])
        {[res | results], Map.put(data, key, changed)}
      end)

      {Enum.reverse(res), changed}
    end
  end

  def all, do: filter(fn _ -> true end)

  def seq(lens1, lens2) do
    fn data, fun ->
      {res, changed} = get_and_map(data, lens1, fn item ->
        get_and_map(item, lens2, fun)
      end)
      {Enum.concat(res), changed}
    end
  end

  def seq_both(lens1, lens2), do: Lens.both(Lens.seq(lens1, lens2), lens1)

  def recur(lens), do: &do_recur(lens, &1, &2)

  def both(lens1, lens2) do
    fn data, fun ->
      {res1, changed1} = get_and_map(data, lens1, fun)
      {res2, changed2} = get_and_map(changed1, lens2, fun)
      {res1 ++ res2, changed2}
    end
  end

  def filter(filter_fun) do
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

  def satisfy(lens, filter_fun) do
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
end

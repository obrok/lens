defmodule LensTest do
  use ExUnit.Case
  require Integer
  import Lens.Macros
  doctest Lens

  defmodule TestStruct do
    defstruct [:a, :b, :c]
  end

  describe "key" do
    test "to_list", do: assert(Lens.to_list(Lens.key(:a), %{a: :b}) == [:b])

    test "to_list on keyword", do: assert(Lens.to_list(Lens.key(:a), a: :b) == [:b])

    test "each" do
      this = self()
      Lens.each(Lens.key(:a), %{a: :b}, fn x -> send(this, x) end)
      assert_receive :b
    end

    test "map", do: assert(Lens.map(Lens.key(:a), %{a: :b}, fn :b -> :c end) == %{a: :c})
    test "map on keyword", do: assert(Lens.map(Lens.key(:a), [a: :b], fn :b -> :c end) == [a: :c])

    test "get_and_map" do
      assert Lens.get_and_map(Lens.key(:a), %{a: :b}, fn :b -> {:c, :d} end) == {[:c], %{a: :d}}
      assert Lens.get_and_map(Lens.key(:a), %TestStruct{a: 1}, fn x -> {x, x + 1} end) == {[1], %TestStruct{a: 2}}
    end
  end

  describe "keys" do
    test "get_and_map" do
      assert Lens.get_and_map(Lens.keys([:a, :e]), %{a: :b, c: :d, e: :f}, fn x -> {x, :x} end) ==
               {[:b, :f], %{a: :x, c: :d, e: :x}}

      assert Lens.get_and_map(Lens.keys([:a, :c]), %TestStruct{a: 1, b: 2, c: 3}, fn x -> {x, x + 1} end) ==
               {[1, 3], %TestStruct{a: 2, b: 2, c: 4}}
    end
  end

  describe "all" do
    test "to_list", do: assert(Lens.to_list(Lens.all(), [:a, :b, :c]) == [:a, :b, :c])

    test "each" do
      this = self()
      Lens.each(Lens.all(), [:a, :b, :c], fn x -> send(this, x) end)
      assert_receive :a
      assert_receive :b
      assert_receive :c
    end

    test "map",
      do:
        assert(
          Lens.map(Lens.all(), [:a, :b, :c], fn
            :a -> 1
            :b -> 2
            :c -> 3
          end) == [1, 2, 3]
        )

    test "get_and_map" do
      assert Lens.get_and_map(Lens.all(), [:a, :b, :c], fn x -> {x, :d} end) == {[:a, :b, :c], [:d, :d, :d]}
    end
  end

  describe "seq" do
    test "to_list", do: assert(Lens.to_list(Lens.seq(Lens.key(:a), Lens.key(:b)), %{a: %{b: :c}}) == [:c])

    test "each" do
      this = self()
      Lens.each(Lens.seq(Lens.key(:a), Lens.key(:b)), %{a: %{b: :c}}, fn x -> send(this, x) end)
      assert_receive :c
    end

    test "map",
      do: assert(Lens.map(Lens.seq(Lens.key(:a), Lens.key(:b)), %{a: %{b: :c}}, fn :c -> :d end) == %{a: %{b: :d}})

    test "get_and_map" do
      assert Lens.get_and_map(Lens.seq(Lens.key(:a), Lens.key(:b)), %{a: %{b: :c}}, fn :c -> {:d, :e} end) ==
               {[:d], %{a: %{b: :e}}}
    end
  end

  describe "seq_both" do
    test "get_and_map" do
      assert Lens.get_and_map(Lens.seq_both(Lens.key(:a), Lens.key(:b)), %{a: %{b: :c}}, fn
               :c -> {2, :d}
               %{b: :d} -> {1, %{b: :e}}
             end) == {[2, 1], %{a: %{b: :e}}}
    end
  end

  describe "both" do
    test "get_and_map" do
      assert Lens.get_and_map(Lens.both(Lens.key(:a), Lens.seq(Lens.key(:b), Lens.all())), %{a: 1, b: [2, 3]}, fn x ->
               {x, x + 1}
             end) == {[1, 2, 3], %{a: 2, b: [3, 4]}}
    end
  end

  describe "filter" do
    test "get_and_map" do
      lens =
        Lens.both(Lens.keys([:a, :b]), Lens.seq(Lens.key(:c), Lens.all()))
        |> Lens.filter(&Integer.is_odd/1)

      assert Lens.get_and_map(lens, %{a: 1, b: 2, c: [3, 4]}, fn x -> {x, x + 1} end) ==
               {[1, 3], %{a: 2, b: 2, c: [4, 4]}}
    end

    test "usage with deflens" do
      assert Lens.get_and_map(Lens.all() |> test_filter(), [1, 2, 3, 4], fn x -> {x, x + 1} end) ==
               {[1, 3], [2, 2, 4, 4]}
    end

    deflensp test_filter() do
      Lens.filter(&Integer.is_odd/1)
    end
  end

  describe "recur" do
    test "get_and_map" do
      data = %{
        data: 1,
        items: [
          %{data: 2, items: []},
          %{
            data: 3,
            items: [
              %{data: 4, items: []}
            ]
          }
        ]
      }

      lens = Lens.recur(Lens.key(:items) |> Lens.all()) |> Lens.key(:data)

      assert Lens.get_and_map(lens, data, fn x -> {x, x + 1} end) ==
               {[2, 4, 3],
                %{
                  data: 1,
                  items: [
                    %{data: 3, items: []},
                    %{
                      data: 4,
                      items: [
                        %{data: 5, items: []}
                      ]
                    }
                  ]
                }}
    end
  end

  describe "at" do
    test "access on tuple" do
      assert Lens.get_and_map(Lens.at(1), {1, 2, 3}, fn x -> {x, x + 1} end) == {[2], {1, 3, 3}}
    end

    test "access on list" do
      assert Lens.get_and_map(Lens.at(1), [1, 2, 3], fn x -> {x, x + 1} end) == {[2], [1, 3, 3]}
    end
  end

  describe "match" do
    test "get_and_map" do
      lens =
        Lens.seq(
          Lens.all(),
          Lens.match(fn
            {:a, _} -> Lens.at(1)
            {:b, _, _} -> Lens.at(2)
          end)
        )

      assert Lens.get_and_map(lens, [{:a, 1}, {:b, 2, 3}], fn x -> {x, x + 1} end) == {[1, 3], [{:a, 2}, {:b, 2, 4}]}
    end
  end

  describe "empty" do
    test "get_and_map" do
      assert Lens.get_and_map(Lens.empty(), {:arbitrary, :data}, fn -> raise "never_called" end) ==
               {[], {:arbitrary, :data}}
    end
  end

  describe "composition with |>" do
    test "get_and_map" do
      lens1 = Lens.key(:a) |> Lens.seq(Lens.all()) |> Lens.seq(Lens.key(:b))
      lens2 = Lens.key(:a) |> Lens.all() |> Lens.key(:b)
      data = %{a: [%{b: 1}, %{b: 2}]}
      fun = fn x -> {x, x + 1} end

      assert Lens.get_and_map(lens1, data, fun) == Lens.get_and_map(lens2, data, fun)
    end
  end

  describe "root" do
    test "get_and_map" do
      assert Lens.get_and_map(Lens.root(), 1, fn x -> {x, x + 1} end) == {[1], 2}
    end
  end

  describe "lens as access key" do
    test "Kernel.get_in" do
      value =
        %{a: 1, b: 2, c: 3}
        |> get_in([Lens.keys([:a, :c])])
        |> Enum.map(&to_string/1)

      assert value == ["1", "3"]
    end

    test "Kernel.update_in" do
      value =
        %{a: 1, b: 2, c: 3}
        |> update_in([Lens.keys([:a, :c])], fn x -> x * 4 end)

      assert value == %{a: 4, b: 2, c: 12}
    end
  end
end

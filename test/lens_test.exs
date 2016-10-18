defmodule LensTest do
  use ExUnit.Case
  doctest Lens

  describe "key" do
    test "to_list", do: assert Lens.to_list(%{a: :b}, Lens.key(:a)) == [:b]

    test "each" do
      this = self
      Lens.each(%{a: :b}, Lens.key(:a), fn x -> send(this, x) end)
      assert_receive :b
    end

    test "map", do: assert Lens.map(%{a: :b}, Lens.key(:a), fn :b -> :c end) == %{a: :c}

    test "get_and_map" do
      assert Lens.get_and_map(%{a: :b}, Lens.key(:a), fn :b -> {:c, :d} end) == {[:c], %{a: :d}}
    end
  end

  describe "all" do
    test "to_list", do: assert Lens.to_list([:a, :b, :c], Lens.all) == [:a, :b, :c]

    test "each" do
      this = self
      Lens.each([:a, :b, :c], Lens.all, fn x -> send(this, x) end)
      assert_receive :a
      assert_receive :b
      assert_receive :c
    end

    test "map", do: assert Lens.map([:a, :b, :c], Lens.all, fn :a -> 1; :b -> 2; :c -> 3 end) == [1, 2, 3]

    test "get_and_map" do
      assert Lens.get_and_map([:a, :b, :c], Lens.all, fn x -> {x, :d} end) == {[:a, :b, :c], [:d, :d, :d]}
    end
  end

  describe "seq" do
    test "to_list", do: assert Lens.to_list(%{a: %{b: :c}}, Lens.seq(Lens.key(:a), Lens.key(:b))) == [:c]

    test "each" do
      this = self
      Lens.each(%{a: %{b: :c}}, Lens.seq(Lens.key(:a), Lens.key(:b)), fn x -> send(this, x) end)
      assert_receive :c
    end

    test "map", do: assert Lens.map(%{a: %{b: :c}}, Lens.seq(Lens.key(:a), Lens.key(:b)), fn :c -> :d end) == %{a: %{b: :d}}

    test "get_and_map" do
      assert Lens.get_and_map(%{a: %{b: :c}}, Lens.seq(Lens.key(:a), Lens.key(:b)), fn :c -> {:d, :e} end) == {[:d], %{a: %{b: :e}}}
    end
  end
end

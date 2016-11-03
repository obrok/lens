# Lens

[![Build Status](https://travis-ci.org/obrok/lens.png?branch=master)](https://travis-ci.org/obrok/lens)

A utility for working with nested data structures. Implements functional lenses that are Functors (mappable),
Traversable, and Foldable.

## Example

Lens allows you to separate which parts of a complex data structure need to be processed from the actual
processing. Take the following:

```elixir
data = %{
  main_widget: %{size: 200.5, subwidgets: [%{size: 120, subwidgets: [%{size: 200, subwidgets: []}]}]},
  other_widgets: [
    %{size: 16.5, subwidgets: [%{size: 120, subwidgets: []}]},
    %{size: 160.5, subwidgets: []},
    %{size: 121.9, subwidgets: []},
  ]
}
```

Let's say we're interested in the sizes of all widgets (be they the main widget or other widgets) that are larger than 100.
We can construct a `Lens` object that describes these locations in the datastructure the following way:

```elixir
lens = Lens.both(
  Lens.key(:main_widget),
  Lens.seq(Lens.key(:other_widgets), Lens.all)
)
|> Lens.seq_both(
  Lens.recur(Lens.seq(Lens.key(:subwidgets), Lens.all))
)
|> Lens.seq(Lens.key(:size))
|> Lens.satisfy(&(&1 > 100))
```

Given that we can:

* Extract all the relevant data

```elixir
iex> Lens.to_list(data, lens)
[200.5, 160.5, 121.9, 120, 200, 120]
```

* Update the described locations in the data structure

```elixir
iex> Lens.map(data, lens, &round/1)
%{main_widget: %{size: 201,
    subwidgets: [%{size: 120, subwidgets: [%{size: 200, subwidgets: []}]}]},
  other_widgets: [%{size: 16.5, subwidgets: [%{size: 120, subwidgets: []}]},
   %{size: 161, subwidgets: []}, %{size: 122, subwidgets: []}]}
```

* Simultaneously update and return something from every location in the data

```elixir
iex> Lens.get_and_map(data, lens, fn size -> {size, round(size)} end)
{[200.5, 160.5, 121.9, 120, 200, 120],
 %{main_widget: %{size: 201,
     subwidgets: [%{size: 120, subwidgets: [%{size: 200, subwidgets: []}]}]},
   other_widgets: [%{size: 16.5, subwidgets: [%{size: 120, subwidgets: []}]},
    %{size: 161, subwidgets: []}, %{size: 122, subwidgets: []}]}}
```

## Installation

[Available in Hex](https://hex.pm/packages/lens), the package can be installed as:

  1. Add lens to your list of dependencies in `mix.exs`:

        def deps do
          [{:lens, "~> 0.0.1"}]
        end

defmodule Lens.Macros do
  defmacro __using__(_) do
    quote do
      require Lens.Macros
      import Lens.Macros
    end
  end

  @doc ~S"""
  A convenience to define a lens that can be piped into with `|>`.

      deflens some_lens(foo, bar), do: some_lens_combination(foo, bar)

  Is equivalent to:

      def some_lens(foo, bar), do: some_lens_combination(foo, bar)
      def some_lens(previous, foo, bar), do: Lens.seq(previous, some_lens_combination(foo, bar))
  """
  defmacro deflens(header = {name, _, args}, do: body) do
    args =
      case args do
        nil -> []
        _ -> args
      end

    quote do
      def unquote(header), do: unquote(body)

      @doc false
      def unquote(name)(previous, unquote_splicing(args)) do
        Lens.seq(previous, unquote(name)(unquote_splicing(args)))
      end
    end
  end

  @doc ~S"""
  Same as `deflens` but creates private functions instead.
  """
  defmacro deflensp(header = {name, _, args}, do: body) do
    args =
      case args do
        nil -> []
        _ -> args
      end

    quote do
      defp unquote(header), do: unquote(body)

      @doc false
      defp unquote(name)(previous, unquote_splicing(args)) do
        Lens.seq(previous, unquote(name)(unquote_splicing(args)))
      end
    end
  end

  @doc false
  defmacro deflens_raw(header = {name, _, args}, do: body) do
    args =
      case args do
        nil -> []
        _ -> args
      end

    quote do
      def unquote(header) do
        lens = unquote(body)

        fn
          :get, data, next ->
            {list, _} = lens.(data, &{&1, &1})
            next.(list)

          :get_and_update, data, mapper ->
            lens.(data, mapper)
        end
      end

      @doc false
      def unquote(name)(previous, unquote_splicing(args)) do
        Lens.seq(previous, unquote(name)(unquote_splicing(args)))
      end
    end
  end
end

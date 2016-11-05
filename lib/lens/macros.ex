defmodule Lens.Macros do
  defmacro __using__(_) do
    quote do
      require Lens.Macros
      import Lens.Macros
    end
  end

  defmacro deflens(header = {name, _, args}, do: body) do
    args = case args do
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

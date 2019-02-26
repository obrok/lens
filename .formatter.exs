locals_without_parens = [deflens: :*, deflensp: :*]

[
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 120,
  locals_without_parens: [{:deflens_raw, :*} | locals_without_parens],
  export: [locals_without_parens: locals_without_parens]
]

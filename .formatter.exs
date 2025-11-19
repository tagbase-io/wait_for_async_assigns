[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [
    locals_without_parens: [
      wait_for_async_assigns: 1,
      wait_for_async_assigns: 2
    ]
  ]
]

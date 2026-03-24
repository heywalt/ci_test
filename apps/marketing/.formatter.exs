[
  heex_line_length: 120,
  import_deps: [:phoenix],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"],
  plugins: [Phoenix.LiveView.HTMLFormatter]
]

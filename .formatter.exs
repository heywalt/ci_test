[
  subdirectories: ["apps/*"],
  import_deps: [
    :typed_struct,
    :ecto,
    :ecto_sql,
    :phoenix,
    :commanded,
    :commanded_ecto_projections
  ],
  inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
]

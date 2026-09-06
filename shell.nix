{ mkShell, beamPackages }:
mkShell {
  packages = [ beamPackages.elixir ];
}

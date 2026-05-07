{
  hm = {
    inputs,
    system,
    ...
  }: {
    home.packages = [inputs.hermes-agent.packages.${system}.default];
  };
}

{den, ...}: {
  den.aspects.lavpc.includes = with den.aspects; [
    hardware-lavpc
    guix
    system-astral
    service-ollama
  ];
}

{den, ...}: {
  den.aspects.lavpc.includes = with den.aspects; [
    hardware-lavpc
    celler-cache-client
    lavpc-remote-builder
    guix
    system-astral
    service-ollama
    desktop
  ];
}

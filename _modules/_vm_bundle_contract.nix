{
  shared_directory_target = "/mnt/vm-bundle";

  activation_script = ''
    ln -sfnT /mnt/vm-bundle /run/vm-bundle

    if [ ! -d /run/vm-bundle ]; then
      echo "error: VM bundle mount not ready: /run/vm-bundle" >&2
      exit 1
    fi

    if [ ! -f /run/vm-bundle/age/key.txt ]; then
      echo "error: required VM bundle file missing: /run/vm-bundle/age/key.txt" >&2
      exit 1
    fi

    install -d -m 700 /root/.age
    install -m 600 /run/vm-bundle/age/key.txt /root/.age/key.txt

    if [ -f /run/vm-bundle/ssh/id_ed25519 ]; then
      install -d -m 700 /root/.ssh
      install -m 600 /run/vm-bundle/ssh/id_ed25519 /root/.ssh/id_ed25519
    else
      rm -f /root/.ssh/id_ed25519
    fi
  '';
}

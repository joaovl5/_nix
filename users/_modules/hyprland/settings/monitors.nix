_: {
  # this is lavpc-only, make conditional by hosts later
  monitor = let
    main = "DP-4";
    side = "HDMI-A-2";
  in [
    "${main},3840x2160@240.08,1080x396,1.333333"
    "${side},1920x1080@100.0,0x240,1.0"
    "${side},transform,1" # vertical
  ];
}

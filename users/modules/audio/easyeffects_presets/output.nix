{
  # credits: https://github.com/droidwayin/GentleDynamics

  /*
  does some stuff
  */
  "Gentle Dynamics" = {
    output = {
      blocklist = [
      ];
      "filter#0" = {
        balance = 0;
        bypass = false;
        equal-mode = "FIR";
        frequency = 18;
        gain = 0;
        input-gain = 0;
        mode = "BWC (BT)";
        output-gain = 0;
        quality = 0.8999999761581421;
        slope = "x6";
        type = "High-pass";
        width = 4;
      };
      "level_meter#0" = {
        bypass = false;
      };
      "limiter#0" = {
        alr = false;
        alr-attack = 3;
        alr-knee = 0;
        alr-release = 50;
        attack = 0.25;
        bypass = false;
        dithering = "24bit";
        external-sidechain = false;
        gain-boost = false;
        input-gain = 0;
        lookahead = 8;
        mode = "Herm Thin";
        output-gain = -0.6;
        oversampling = "Full x8(3L)";
        release = 16;
        sidechain-preamp = 0;
        stereo-link = 100;
        threshold = -2.000000238418579;
      };
      "multiband_compressor#0" = {
        band0 = {
          attack-threshold = -40;
          attack-time = 100;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Upward";
          compressor-enable = true;
          external-sidechain = false;
          knee = 0;
          makeup = 0;
          mute = false;
          ratio = 1.149999976158142;
          release-threshold = -100;
          release-time = 300;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 100;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 18;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          stereo-split-source = "Left/Right";
        };
        band1 = {
          attack-threshold = -20;
          attack-time = 60;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -12;
          makeup = 0;
          mute = false;
          ratio = 1.850000023841858;
          release-threshold = -100;
          release-time = 200;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 200;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 100;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 100;
          stereo-split-source = "Left/Right";
        };
        band2 = {
          attack-threshold = -18;
          attack-time = 40;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -8;
          makeup = 0;
          mute = false;
          ratio = 1.649999976158142;
          release-threshold = -100;
          release-time = 160;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 400;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 200;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 200;
          stereo-split-source = "Left/Right";
        };
        band3 = {
          attack-threshold = -16;
          attack-time = 30;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -6;
          makeup = 0;
          mute = false;
          ratio = 1.5499999523162842;
          release-threshold = -100;
          release-time = 140;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 800;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 400;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 400;
          stereo-split-source = "Left/Right";
        };
        band4 = {
          attack-threshold = -15;
          attack-time = 25;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -3.999999761581421;
          makeup = 0;
          mute = false;
          ratio = 1.4500000476837158;
          release-threshold = -100;
          release-time = 120;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 1600;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 800;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 800;
          stereo-split-source = "Left/Right";
        };
        band5 = {
          attack-threshold = -14;
          attack-time = 20;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -3;
          makeup = 0;
          mute = false;
          ratio = 1.350000023841858;
          release-threshold = -100;
          release-time = 100;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 3200;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 1600;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 1600;
          stereo-split-source = "Left/Right";
        };
        band6 = {
          attack-threshold = -28;
          attack-time = 10;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Upward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -3.999999761581421;
          makeup = 0;
          mute = false;
          ratio = 1.059999942779541;
          release-threshold = -100;
          release-time = 80;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 8000;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 3200;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 3200;
          stereo-split-source = "Left/Right";
        };
        band7 = {
          attack-threshold = -34;
          attack-time = 5;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Upward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = 0;
          makeup = 0;
          mute = false;
          ratio = 1.0399999618530273;
          release-threshold = -100;
          release-time = 60;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 20000;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 8000;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 8000;
          stereo-split-source = "Left/Right";
        };
        bypass = false;
        compressor-mode = "Modern";
        dry = -100;
        envelope-boost = "None";
        input-gain = 0;
        output-gain = 0;
        stereo-split = false;
        wet = 0;
      };
      plugins_order = [
        "filter#0"
        "multiband_compressor#0"
        "limiter#0"
        "level_meter#0"
      ];
    };
  };
  "Gentle Dynamics - Feather Loudness (music)" = {
    output = {
      blocklist = [
      ];
      "compressor#0" = {
        attack = 30;
        boost-amount = 1.499999761581421;
        boost-threshold = -60;
        bypass = false;
        dry = 0;
        hpf-frequency = 200;
        hpf-mode = "24 dB/oct";
        input-gain = 0;
        knee = -6;
        lpf-frequency = 6000;
        lpf-mode = "24 dB/oct";
        makeup = 2;
        mode = "Downward";
        output-gain = -1;
        ratio = 1.5;
        release = 180;
        release-threshold = -25;
        sidechain = {
          lookahead = 0;
          mode = "RMS";
          preamp = 0;
          reactivity = 30;
          source = "Middle";
          stereo-split-source = "Left/Right";
          type = "Feed-forward";
        };
        stereo-split = false;
        threshold = -14;
        wet = -25;
      };
      "filter#0" = {
        balance = 0;
        bypass = false;
        equal-mode = "IIR";
        frequency = 18;
        gain = 0;
        input-gain = 0;
        mode = "APO (DR)";
        output-gain = 0;
        quality = 0.8999999761581421;
        slope = "x4";
        type = "High-pass";
        width = 4;
      };
      "level_meter#0" = {
        bypass = false;
      };
      "limiter#0" = {
        alr = false;
        alr-attack = 3;
        alr-knee = 0;
        alr-release = 50;
        attack = 1;
        bypass = false;
        dithering = "24bit";
        external-sidechain = false;
        gain-boost = false;
        input-gain = 0;
        lookahead = 8;
        mode = "Herm Thin";
        output-gain = 0;
        oversampling = "Full x8(3L)";
        release = 20;
        sidechain-preamp = 0;
        stereo-link = 100;
        threshold = -2.8;
      };
      "multiband_compressor#0" = {
        band0 = {
          attack-threshold = -40;
          attack-time = 100;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Upward";
          compressor-enable = true;
          external-sidechain = false;
          knee = 0;
          makeup = 0;
          mute = false;
          ratio = 1.149999976158142;
          release-threshold = -100;
          release-time = 300;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 100;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 18;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          stereo-split-source = "Left/Right";
        };
        band1 = {
          attack-threshold = -20;
          attack-time = 60;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -12;
          makeup = 0;
          mute = false;
          ratio = 1.850000023841858;
          release-threshold = -100;
          release-time = 200;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 200;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 100;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 100;
          stereo-split-source = "Left/Right";
        };
        band2 = {
          attack-threshold = -18;
          attack-time = 40;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -8;
          makeup = 0;
          mute = false;
          ratio = 1.649999976158142;
          release-threshold = -100;
          release-time = 160;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 400;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 200;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 200;
          stereo-split-source = "Left/Right";
        };
        band3 = {
          attack-threshold = -16;
          attack-time = 30;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -6;
          makeup = 0;
          mute = false;
          ratio = 1.5499999523162842;
          release-threshold = -100;
          release-time = 140;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 800;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 400;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 400;
          stereo-split-source = "Left/Right";
        };
        band4 = {
          attack-threshold = -15;
          attack-time = 25;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -3.999999761581421;
          makeup = 0;
          mute = false;
          ratio = 1.4500000476837158;
          release-threshold = -100;
          release-time = 120;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 1600;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 800;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 800;
          stereo-split-source = "Left/Right";
        };
        band5 = {
          attack-threshold = -14;
          attack-time = 20;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -3;
          makeup = 0;
          mute = false;
          ratio = 1.350000023841858;
          release-threshold = -100;
          release-time = 100;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 3200;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 1600;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 1600;
          stereo-split-source = "Left/Right";
        };
        band6 = {
          attack-threshold = -30;
          attack-time = 10;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Upward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -6;
          makeup = 0;
          mute = false;
          ratio = 1.0399999618530273;
          release-threshold = -100;
          release-time = 80;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 8000;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 3200;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 3200;
          stereo-split-source = "Left/Right";
        };
        band7 = {
          attack-threshold = -32;
          attack-time = 5;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Upward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -3;
          makeup = 0;
          mute = false;
          ratio = 1.0299999713897705;
          release-threshold = -100;
          release-time = 60;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 20000;
          sidechain-lookahead = 0;
          sidechain-lowcut-frequency = 8000;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 8000;
          stereo-split-source = "Left/Right";
        };
        bypass = false;
        compressor-mode = "Modern";
        dry = -100;
        envelope-boost = "None";
        input-gain = 0;
        output-gain = -0.3;
        stereo-split = false;
        wet = 0;
      };
      plugins_order = [
        "filter#0"
        "multiband_compressor#0"
        "compressor#0"
        "stereo_tools#0"
        "limiter#0"
        "level_meter#0"
      ];
      "stereo_tools#0" = {
        balance-in = 0;
        balance-out = 0;
        bypass = false;
        delay = 0;
        input-gain = 0;
        middle-level = 1;
        middle-panorama = 0;
        mode = "LR > LR (Stereo Default)";
        mutel = false;
        muter = false;
        output-gain = -1;
        phasel = false;
        phaser = false;
        sc-level = 1;
        side-balance = 0;
        side-level = 0.9;
        softclip = false;
        stereo-base = 0;
        stereo-phase = 0;
      };
    };
  };
  "Gentle Dynamics - Dialogue Clarity (Movies)" = {
    output = {
      blocklist = [
      ];
      "compressor#1" = {
        attack = 35;
        boost-amount = 1;
        boost-threshold = -60;
        bypass = false;
        dry = -100;
        hpf-frequency = 150;
        hpf-mode = "12 dB/oct";
        input-gain = 0;
        knee = -8;
        lpf-frequency = 6000;
        lpf-mode = "12 dB/oct";
        makeup = 0;
        mode = "Downward";
        output-gain = 0;
        ratio = 1.7;
        release = 300;
        release-threshold = -100;
        sidechain = {
          lookahead = 3;
          mode = "RMS";
          preamp = 0;
          reactivity = 80;
          source = "Middle";
          stereo-split-source = "Left/Right";
          type = "Feed-forward";
        };
        stereo-split = false;
        threshold = -22;
        wet = 0;
      };
      "compressor#2" = {
        attack = 100;
        boost-amount = 5.999999046325684;
        boost-threshold = -60;
        bypass = false;
        dry = 0;
        hpf-frequency = 100;
        hpf-mode = "12 dB/oct";
        input-gain = 0;
        knee = -12;
        lpf-frequency = 10000;
        lpf-mode = "12 dB/oct";
        makeup = 0;
        mode = "Downward";
        output-gain = -2;
        ratio = 2.35;
        release = 400;
        release-threshold = -100;
        sidechain = {
          lookahead = 3;
          mode = "RMS";
          preamp = 0;
          reactivity = 80;
          source = "Middle";
          stereo-split-source = "Left/Right";
          type = "Feed-forward";
        };
        stereo-split = false;
        threshold = -27;
        wet = -6;
      };
      "deesser#0" = {
        bypass = false;
        detection = "RMS";
        f1-freq = 8000;
        f1-level = 0;
        f2-freq = 6800;
        f2-level = 4.5;
        f2-q = 4;
        input-gain = 0;
        laxity = 10;
        makeup = 0;
        mode = "Wide";
        output-gain = 0;
        ratio = 1;
        sc-listen = false;
        threshold = -26;
      };
      "expander#0" = {
        attack = 45;
        bypass = false;
        dry = -100;
        hpf-frequency = 120;
        hpf-mode = "12 dB/oct";
        input-gain = 0;
        knee = -6;
        lpf-frequency = 20000;
        lpf-mode = "12 dB/oct";
        makeup = 0;
        mode = "Downward";
        output-gain = 0;
        ratio = 1.7999999523162842;
        release = 250;
        release-threshold = -100;
        sidechain = {
          lookahead = 3;
          mode = "Peak";
          preamp = 0;
          reactivity = 120;
          source = "Middle";
          stereo-split-source = "Left/Right";
          type = "Internal";
        };
        stereo-split = false;
        threshold = -50;
        wet = 0;
      };
      "filter#0" = {
        balance = 0;
        bypass = false;
        equal-mode = "IIR";
        frequency = 18;
        gain = 0;
        input-gain = 0;
        mode = "APO (DR)";
        output-gain = 0;
        quality = 0.7;
        slope = "x4";
        type = "High-pass";
        width = 4;
      };
      "level_meter#0" = {
        bypass = false;
      };
      "limiter#0" = {
        alr = false;
        alr-attack = 3;
        alr-knee = 0;
        alr-release = 50;
        attack = 3;
        bypass = false;
        dithering = "24bit";
        external-sidechain = false;
        gain-boost = false;
        input-gain = 0;
        lookahead = 5;
        mode = "Herm Thin";
        output-gain = 0;
        oversampling = "Full x8(3L)";
        release = 20;
        sidechain-preamp = 0;
        stereo-link = 100;
        threshold = -1.5;
      };
      "multiband_compressor#0" = {
        band0 = {
          attack-threshold = -30;
          attack-time = 150;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          external-sidechain = false;
          knee = -6;
          makeup = 0;
          mute = false;
          ratio = 1;
          release-threshold = -100;
          release-time = 400;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 120;
          sidechain-lookahead = 3;
          sidechain-lowcut-frequency = 20;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          stereo-split-source = "Left/Right";
        };
        band1 = {
          attack-threshold = -30;
          attack-time = 100;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -8;
          makeup = 0;
          mute = false;
          ratio = 1.100000023841858;
          release-threshold = -35;
          release-time = 300;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 250;
          sidechain-lookahead = 3;
          sidechain-lowcut-frequency = 120;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 10;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 120;
          stereo-split-source = "Left/Right";
        };
        band2 = {
          attack-threshold = -30;
          attack-time = 30;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Upward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -8;
          makeup = 1.5;
          mute = false;
          ratio = 2.5;
          release-threshold = -35;
          release-time = 400;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 3500;
          sidechain-lookahead = 3;
          sidechain-lowcut-frequency = 300;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 80;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 250;
          stereo-split-source = "Left/Right";
        };
        band3 = {
          attack-threshold = -30;
          attack-time = 10;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -3.999999761581421;
          makeup = 0;
          mute = false;
          ratio = 1.100000023841858;
          release-threshold = -100;
          release-time = 80;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 8000;
          sidechain-lookahead = 3;
          sidechain-lowcut-frequency = 3500;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 80;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 3500;
          stereo-split-source = "Left/Right";
        };
        band4 = {
          attack-threshold = -34;
          attack-time = 8;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = true;
          external-sidechain = false;
          knee = -3.999999761581421;
          makeup = 0;
          mute = false;
          ratio = 1.100000023841858;
          release-threshold = -100;
          release-time = 60;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 20000;
          sidechain-lookahead = 3;
          sidechain-lowcut-frequency = 8000;
          sidechain-mode = "Peak";
          sidechain-preamp = 0;
          sidechain-reactivity = 80;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 8000;
          stereo-split-source = "Left/Right";
        };
        band5 = {
          attack-threshold = -30;
          attack-time = 50;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = false;
          external-sidechain = false;
          knee = -6;
          makeup = 0;
          mute = false;
          ratio = 1;
          release-threshold = -100;
          release-time = 200;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 8000;
          sidechain-lookahead = 3;
          sidechain-lowcut-frequency = 6000;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 80;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 20000;
          stereo-split-source = "Left/Right";
        };
        band6 = {
          attack-threshold = -30;
          attack-time = 50;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = false;
          external-sidechain = false;
          knee = -6;
          makeup = 0;
          mute = false;
          ratio = 1;
          release-threshold = -100;
          release-time = 200;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 10500;
          sidechain-lookahead = 3;
          sidechain-lowcut-frequency = 8000;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 80;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 8000;
          stereo-split-source = "Left/Right";
        };
        band7 = {
          attack-threshold = -50;
          attack-time = 50;
          boost-amount = 5.999999046325684;
          boost-threshold = -72;
          compression-mode = "Downward";
          compressor-enable = true;
          enable-band = false;
          external-sidechain = false;
          knee = -6;
          makeup = 0;
          mute = false;
          ratio = 1;
          release-threshold = -100;
          release-time = 200;
          sidechain-custom-highcut-filter = true;
          sidechain-custom-lowcut-filter = true;
          sidechain-highcut-frequency = 20000;
          sidechain-lookahead = 3;
          sidechain-lowcut-frequency = 10500;
          sidechain-mode = "RMS";
          sidechain-preamp = 0;
          sidechain-reactivity = 80;
          sidechain-source = "Middle";
          solo = false;
          split-frequency = 10500;
          stereo-split-source = "Left/Right";
        };
        bypass = false;
        compressor-mode = "Modern";
        dry = 0;
        envelope-boost = "None";
        input-gain = 0;
        output-gain = 0;
        stereo-split = false;
        wet = -6;
      };
      plugins_order = [
        "expander#0"
        "filter#0"
        "multiband_compressor#0"
        "compressor#1"
        "compressor#2"
        "deesser#0"
        "stereo_tools#0"
        "limiter#0"
        "level_meter#0"
      ];
      "stereo_tools#0" = {
        balance-in = 0;
        balance-out = 0;
        bypass = false;
        delay = 0;
        input-gain = 0;
        middle-level = 1;
        middle-panorama = 0;
        mode = "LR > LR (Stereo Default)";
        mutel = false;
        muter = false;
        output-gain = -1;
        phasel = false;
        phaser = false;
        sc-level = 1;
        side-balance = 0;
        side-level = 0.9;
        softclip = false;
        stereo-base = 0;
        stereo-phase = 0;
      };
    };
  };

  # credits: https://github.com/JackHack96/EasyEffects-Presets

  /*
  This preset is targeted for laptop speakers and tries to improve both lower and higher frequencies.
  It also tries to normalize the volumes in different medias like speech and music.
  More information can be found in this blog:
  https://medium.com/@susuthapa19961227/trying-to-improve-audio-in-linux-with-pulseeffects-63f37ea5b320
  */
  "Advanced AutoGain" = {
    output = {
      autogain = {
        target = -12;
      };
      blocklist = [
      ];
      equalizer = {
        input-gain = -0.3;
        left = {
          band0 = {
            frequency = 22.59;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band1 = {
            frequency = 28.44;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band2 = {
            frequency = 35.8;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band3 = {
            frequency = 45.07;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band4 = {
            frequency = 56.74;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band5 = {
            frequency = 71.43;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band6 = {
            frequency = 89.93;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band7 = {
            frequency = 113.21;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band8 = {
            frequency = 142.53;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band9 = {
            frequency = 179.43;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band10 = {
            frequency = 225.89;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band11 = {
            frequency = 284.38;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band12 = {
            frequency = 358.02;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band13 = {
            frequency = 450.72;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band14 = {
            frequency = 567.42;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band15 = {
            frequency = 714.34;
            gain = -1;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band16 = {
            frequency = 899.29;
            gain = -2;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band17 = {
            frequency = 1132.15;
            gain = -3.6;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band18 = {
            frequency = 1425.29;
            gain = -2.5;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band19 = {
            frequency = 1794.33;
            gain = -1.5;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band20 = {
            frequency = 2258.93;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band21 = {
            frequency = 2843.82;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band22 = {
            frequency = 3580.16;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band23 = {
            frequency = 4507.15;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band24 = {
            frequency = 5674.16;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band25 = {
            frequency = 7143.35;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band26 = {
            frequency = 8992.94;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band27 = {
            frequency = 11321.45;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band28 = {
            frequency = 14252.86;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band29 = {
            frequency = 17943.28;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
        };
        mode = "IIR";
        num-bands = 30;
        output-gain = -6.5;
        right = {
          band0 = {
            frequency = 22.59;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band1 = {
            frequency = 28.44;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band2 = {
            frequency = 35.8;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band3 = {
            frequency = 45.07;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band4 = {
            frequency = 56.74;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band5 = {
            frequency = 71.43;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band6 = {
            frequency = 89.93;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band7 = {
            frequency = 113.21;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band8 = {
            frequency = 142.53;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band9 = {
            frequency = 179.43;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band10 = {
            frequency = 225.89;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band11 = {
            frequency = 284.38;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band12 = {
            frequency = 358.02;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band13 = {
            frequency = 450.72;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band14 = {
            frequency = 567.42;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band15 = {
            frequency = 714.34;
            gain = -1;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band16 = {
            frequency = 899.29;
            gain = -2;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band17 = {
            frequency = 1132.15;
            gain = -3.6;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band18 = {
            frequency = 1425.29;
            gain = -2.5;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band19 = {
            frequency = 1794.33;
            gain = -1.5;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band20 = {
            frequency = 2258.93;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band21 = {
            frequency = 2843.82;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band22 = {
            frequency = 3580.16;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band23 = {
            frequency = 4507.15;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band24 = {
            frequency = 5674.16;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band25 = {
            frequency = 7143.35;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band26 = {
            frequency = 8992.94;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band27 = {
            frequency = 11321.45;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band28 = {
            frequency = 14252.86;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band29 = {
            frequency = 17943.28;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 4.36;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
        };
        split-channels = false;
      };
      exciter = {
        amount = 6;
        blend = 0;
        ceil = 16000;
        ceil-active = false;
        harmonics = 8.000000000000002;
        input-gain = -2;
        output-gain = 0;
        scope = 5500;
      };
      limiter = {
        alr = false;
        alr-attack = 5;
        alr-knee = 0;
        alr-release = 50;
        attack = 5;
        dithering = "None";
        gain-boost = true;
        input-gain = 0;
        lookahead = 10;
        mode = "Herm Thin";
        output-gain = 0;
        oversampling = "Half x4(3L)";
        release = 5;
        sidechain-preamp = 0;
        stereo-link = 100;
        threshold = 0;
      };
      plugins_order = [
        "equalizer"
        "exciter"
        "autogain"
        "limiter"
      ];
    };
  };
  /*
  Perfect EQ: https://www.ziyadnazem.com/post/956431457/the-perfect-eq-settings-unmasking-the-eq
  */
  "Perfect EQ" = {
    output = {
      blocklist = [
      ];
      equalizer = {
        input-gain = -2;
        left = {
          band0 = {
            frequency = 32;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band1 = {
            frequency = 64;
            gain = 2;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372453;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band2 = {
            frequency = 125;
            gain = 1;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band3 = {
            frequency = 250;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band4 = {
            frequency = 500;
            gain = -1;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372453;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band5 = {
            frequency = 1000;
            gain = -2;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band6 = {
            frequency = 2000;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372449;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band7 = {
            frequency = 4000;
            gain = 2;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372449;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band8 = {
            frequency = 8000;
            gain = 3;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372453;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band9 = {
            frequency = 16000;
            gain = 3;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
        };
        mode = "IIR";
        num-bands = 10;
        output-gain = 0;
        right = {
          band0 = {
            frequency = 32;
            gain = 4;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band1 = {
            frequency = 64;
            gain = 2;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372453;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band2 = {
            frequency = 125;
            gain = 1;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band3 = {
            frequency = 250;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band4 = {
            frequency = 500;
            gain = -1;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372453;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band5 = {
            frequency = 1000;
            gain = -2;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band6 = {
            frequency = 2000;
            gain = 0;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372449;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band7 = {
            frequency = 4000;
            gain = 2;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372449;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band8 = {
            frequency = 8000;
            gain = 3;
            mode = "RLC (BT)";
            mute = false;
            q = 1.5047602375372453;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
          band9 = {
            frequency = 16000;
            gain = 3;
            mode = "RLC (BT)";
            mute = false;
            q = 1.504760237537245;
            slope = "x1";
            solo = false;
            type = "Bell";
          };
        };
        split-channels = false;
      };
      plugins_order = [
        "equalizer"
      ];
    };
  };
}

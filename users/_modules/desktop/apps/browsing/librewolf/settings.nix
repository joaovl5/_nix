{
  nixos_config,
  globals,
  ...
}: let
  fxsync_cfg = nixos_config.my."unit.fxsync";
  gpu_enable = nixos_config.my.nvidia.enable;
  inherit (globals.dns) tld;
in {
  "browser.toolbars.bookmarks.visibility" = "never";
  "identity.sync.tokenserver.uri" = "https://${fxsync_cfg.endpoint.target}.${tld}/1.0/sync/1.5";
  "dom.webgpu.enabled" = gpu_enable;

  # firefox optimizations
  # these are optimized for speed at the detriment of some privacy
  "network.captive-portal-service.enabled" = false;
  "network.notify.checkForProxies" = false;
  ## cache
  "browser.cache.disk.capacity" = 8192000; # Increase cache size on disk to 8 GB
  "browser.cache.disk.smart_size.enabled" = false; # force a fixed max cache size on disk
  "browser.cache.frecency_half_life_hours" = 18; # lower cache sweep intervals
  "browser.cache.max_shutdown_io_lag" = 16; # let the browser finish more io on shutdown
  "browser.cache.memory.capacity" = 2097152; # fixed maximum 2 GB in memory cache
  "browser.cache.memory.max_entry_size" = 327680; # maximum size of in memory cached objects
  "browser.cache.disk.metadata_memory_limit" = 15360; # increase size (in KB) of "Intermediate memory caching of frequently used metadata (a.k.a. disk cache memory pool)"
  ## gfx rendering tweaks
  # "gfx.canvas.accelerated" = true;
  # "gfx.canvas.accelerated.cache-items" = 32768;
  # "gfx.canvas.accelerated.cache-size" = 4096;
  # "layers.acceleration.force-enabled" = false;
  # "gfx.content.skia-font-cache-size" = 80;
  # "gfx.webrender.all" = true;
  # "gfx.webrender.compositor" = true;
  # "gfx.webrender.compositor.force-enabled" = true;
  # "gfx.webrender.enabled" = true;
  # "gfx.webrender.precache-shaders" = true;
  # "gfx.webrender.program-binary-disk" = true;
  # "gfx.webrender.software.opengl" = true;
  # "gfx.webrender.allow-partial-present-buffer-age" = false;
  # "gfx.webrender.max-partial-present-rects" = 0;
  # "image.mem.decode_bytes_at_a_time" = 65536;
  # "image.mem.shared.unmap.min_expiration_ms" = 120000;
  # "layers.gpu-process.enabled" = true;
  # "layers.gpu-process.force-enabled" = true;
  # "image.cache.size" = 10485760;
  # "media.memory_cache_max_size" = 1048576;
  # "media.memory_caches_combined_limit_kb" = 3145728;
  # "media.hardware-video-decoding.force-enabled" = true;
  # "media.ffmpeg.vaapi.enabled" = true;
  ## increase predictive network operations
  "network.dns.disablePrefetchFromHTTPS" = false;
  "network.dnsCacheEntries" = 20000;
  "network.dnsCacheExpiration" = 3600;
  "network.dnsCacheExpirationGracePeriod" = 240;
  "network.predictor.enable-hover-on-ssl" = true;
  "network.predictor.enable-prefetch" = true;
  "network.predictor.preconnect-min-confidence" = 20;
  "network.predictor.prefetch-force-valid-for" = 3600;
  "network.predictor.prefetch-min-confidence" = 30;
  "network.predictor.prefetch-rolling-load-count" = 120;
  "network.predictor.preresolve-min-confidence" = 10;
  ## faster ssl
  "network.ssl_tokens_cache_capacity" = 32768; # more tls token caching, fast reconnects
  ## *disable network separations*
  "fission.autostart" = false;
  "privacy.partition.network_state" = false;
  ## reduce process count
  "dom.ipc.processCount" = 1;
  "dom.ipc.processCount.webIsolated" = 1;
  ## jit threshold
  "javascript.options.baselinejit.threshold" = 50;
  "javascript.options.ion.threshold" = 5000;
  "network.buffer.cache.size" = 65535;
  "javascript.options.concurrent_multiprocess_gcs.cpu_divisor" = 8;
  "browser.display.auto_quality_min_font_size" = 0;
}

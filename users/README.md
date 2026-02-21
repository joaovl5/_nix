# /users

- defines users for different settings
  - `lav` - main desktop user
  - `tyrant` - main server user
  - `plankton` - (UNUSED/WIP) user for stripped-down/lightweight host
- `./_modules` - defines desktop-centric modules for user functionality
  - some of these may be used by servers, but will generally be used in maintenance/quality-of-life situations
- `./_scripts` - misc scripts, mainly used by some `_modules` now
- `./_services` - custom-made systemd services for any purpose, mainly used for the `post_install` script
- `./_units` - modularized versions of different apps, meant to be headless/server-only

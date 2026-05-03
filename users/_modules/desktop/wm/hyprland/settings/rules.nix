_: {
  windowrule = [
    # ignore maximize requests from apps
    "match:class *, suppress_event maximize"

    # xwayland fixes
    "no_focus on, match:class ^$, match:title ^$, match:xwayland 1, match:float 1, match:fullscreen 0, match:pin 0"
    "no_blur on, match:class ^()$, match:title ^()$"

    # avoid idle for fullscreen apps
    "idle_inhibit fullscreen, match:class ^(*)$"
    "idle_inhibit fullscreen, match:title ^(*)$"
    "idle_inhibit fullscreen, match:fullscreen 1"

    # tearing fixes
    "immediate on, match:title .*\.exe"
    "immediate on, match:title .*minecraft.*"
    "immediate on, match:class ^(steam_app).*"

    # center/float
    ## save
    "center on, float on, match:title ^(Save As)(.*)$"
    "center on, float on, match:title ^(.*)(wants to save)$"
    ## open
    "center on, float on, match:title ^(.*)(wants to open)$"
    "center on, float on, match:title ^(File Upload)(.*)$"
    "center on, float on, match:title ^(Open File)(.*)$"
    "center on, float on, match:title ^(Open File)(.*)$"
    "center on, float on, match:title ^(Open Folder)(.*)$"
    "float on, match:title ^(Add Folder to Workspace)(.*)$"
    "center on, float on, match:title ^(Select a File)(.*)$"
    "center on, float on, size (monitor_w*0.6) (monitor_h*0.65), match:title ^(Choose wallpaper)(.*)$"
    "float on, size (monitor_w*0.45), center on, match:class ^(pwvucontrol)$"
    "float on, size (monitor_w*0.45), center on, match:class ^(com.saivert.pwvucontrol)$"
    ## misc
    "center on, float on, match:title ^(Library)(.*)$"
    "center on, match:title (File Operation Progress)"
    "center on, match:title (Confirm to replace files)"
    "move (40) (80), match:title ^(Copying — Dolphin)$"
    "no_initial_focus on, match:class ^(plasma-changeicons)$"
    "float on, match:class ^(org.kde.polkit-kde-authentication-agent-1)$"
    "float on, match:class (xdg-desktop-portal-gtk)"
    "float on, match:class (xdg-desktop-portal-hyprland)"
    "float on, match:class (org.gnome.Calculator), match:title (Calculator)"
    "float on, opacity 0.9 0.6, match:class ^([Rr]ofi)$"
    "float on, match:class ^(eog)$"
    "float on, match:class ^(nwg-look|qt5ct|qt6ct|mpv)$"
    "float on, match:class ^(nm-applet|nm-connection-editor|blueman-manager)$"
    "float on, match:class ^(wihotspot-gui)$"
    "float on, match:class ^(gnome-system-monitor|org.gnome.SystemMonitor)$"
    "float on, match:class ^(yad)$"
    "float on, opacity 0.9 0.8, match:class ^(file-roller|org.gnome.FileRoller)$"
    "float on, match:class ^(evince)$"
    "float on, match:class ^([Bb]aobab|org.gnome.[Bb]aobab)$"
    "float on, opacity 0.9 0.8, size (monitor_w*0.6) (monitor_h*0.7), match:title (Kvantum Manager)"
    "float on, match:class ^([Ss]team)$, match:title ^((?![Ss]team).*|[Ss]team [Ss]ettings)$"
    "float on, match:class ^([Qq]alculate-gtk)$"
    "float on, opacity 0.9 0.7, size (monitor_w*0.6)"
    "float on, opacity 0.9 0.7, size (monitor_w*0.6) (monitor_h*0.7), match:class ^([Ff]erdium)$"

    # opacity-related
    "opacity 0.9 0.7, match:class ^(Brave-browser(-beta|-dev)?)$"
    "opacity 0.9 0.7, match:class ^([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr)$"
    "opacity 0.9 0.6, match:class ^([Tt]horium-browser)$"
    "opacity 0.9 0.8, match:class ^([Mm]icrosoft-edge(-stable|-beta|-dev|-unstable)?)$"
    "opacity 0.9 0.8, match:class ^(google-chrome(-beta|-dev|-unstable)?)$"
    "opacity 0.94 0.86, match:class ^(chrome-.+-Default)$ # Chrome PWAs"
    "opacity 0.9 0.8, match:class ^([Tt]hunar)$"
    "opacity 0.8 0.6, match:class ^(pcmanfm-qt)$"
    "opacity 0.8 0.7, match:class ^(gedit|org.gnome.TextEditor)$"
    "opacity 0.9 0.8, match:class ^(deluge)$"
    "opacity 0.9 0.8, match:class ^(Alacritty)$"
    "opacity 0.9 0.8, match:class ^(kitty)$"
    "opacity 0.9 0.7, match:class ^(mousepad)$"
    "opacity 0.9 0.7, match:class ^(VSCodium|codium-url-handler)$"
    "opacity 0.9 0.8, match:class ^(nwg-look|qt5ct|qt6ct|yad)$"
    "opacity 1.0 1.0, match:class ^(com.obsproject.Studio)$"
    "opacity 0.9 0.7, match:class ^([Aa]udacious)$"
    "opacity 0.9 0.8, match:class ^(org.gnome.Nautilus)$"
    "opacity 0.9 0.8, match:class ^(VSCode|code-url-handler)$"
    "opacity 0.9 0.8, match:class ^(jetbrains-.+)$"
    "opacity 0.94 0.86, match:class ^([Dd]iscord|[Vv]esktop)$"
    "opacity 0.9 0.8, match:class ^(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)$"
    "opacity 0.94 0.86, match:class ^(gnome-disks|evince|wihotspot-gui|org.gnome.baobab)$"
    "opacity 0.8 0.7, match:class ^(app.drey.Warp)$"
    "opacity 0.9 0.8, match:class ^(seahorse)$"
    "opacity 0.82 0.75, size (monitor_w*0.7) (monitor_h*0.7), match:class ^(gnome-system-monitor|org.gnome.SystemMonitor)$"
    "opacity 0.9 0.8, match:class ^(xdg-desktop-portal-gtk)$"
    # size
    "size (monitor_w*0.7) (monitor_h*0.7), match:class ^(xdg-desktop-portal-gtk)$"
    "size (monitor_w*0.6) (monitor_h*0.7), match:class ^(qt6ct)$"
    "size (monitor_w*0.7) (monitor_h*0.7), match:class ^(evince|wihotspot-gui)$"
    "size (monitor_w*0.6) (monitor_h*0.7), match:class ^(file-roller|org.gnome.FileRoller)$"
    # ----------
    # etc
    "border_size 0, match:class ^(com.mitchellh.ghostty)$"
  ];

  layerrule = [
    "ignore_alpha 0, blur on, no_anim on, match:namespace overview"
    "xray on, match:namespace .*"
    # no anims
    "no_anim on, match:namespace walker"
    "no_anim on, match:namespace selection"
    "no_anim on, match:namespace overview"
    "no_anim on, match:namespace anyrun"
    "no_anim on, match:namespace indicator.*"
    "no_anim on, match:namespace osk"
    "no_anim on, match:namespace hyprpicker"
    "no_anim on, match:namespace gtk4-layer-shell"
  ];
}

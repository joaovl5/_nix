args: let
  public = import ../../../_modules/public.nix args;
  mk_var = name: type: params: {
    inherit
      name
      type
      params
      ;
  };
  mk_match = trigger: replace: vars: {
    inherit
      trigger
      replace
      vars
      ;
  };
  # mk_secret = trigger: secret_path: (
  #   mk_match trigger "{{secret}}" [
  #     (mk_var "secret" "shell" {cmd = "cat ${secret_path}";})
  #   ]
  # );
in {
  services.espanso.matches.base.matches = [
    # Shortcuts
    (mk_match "!day" "{{day}}" [(mk_var "day" "date" {format = "%m/%d/%Y";})])
    (mk_match "!time" "{{time}}" [(mk_var "time" "date" {format = "%H:%M";})])
    # Personal
    ## Emails
    (mk_match ";mg" public.emails.google_1 [])
    (mk_match ";mG" public.emails.google_2 [])
    (mk_match ";mo" public.emails.outlook [])
    (mk_match ";ms" public.emails.company [])
    ## Links
    (mk_match ";lg" public.links.github [])
    (mk_match ";ll" public.links.linkedin [])

    ## Coding Snippets - TODO: ^1 move to nvim setup

    (mk_match "!3q" ''"""$|$"""'' [])
    ### HTML
    (mk_match "!hd" "<div>$|$</div>" [])
    ### Python
    (mk_match "!ps" ''
      def main() -> None:
          $|$

      if __name__ == "__main__":
          main()
    '' [])
    (mk_match "!pc" ''
      class $|$:
          def __init__(self) -> None:
              pass
    '' [])
    (mk_match "!pf" ''
      def $|$():
        pass
    '' [])
    (mk_match "!pm" ''
      match $|$:
          case _:
    '' [])
    (mk_match "!pe" ''
      try:
          $|$
      except Exception as e:
          pass
    '' [])
    (mk_match "!pp" ''print("$|$")'' [])
    ### Markdown
    (mk_match "!mp" "[$|$]({{clipb}})" [
      (mk_var "clipb" "clipboard" {})
    ])
  ];
}

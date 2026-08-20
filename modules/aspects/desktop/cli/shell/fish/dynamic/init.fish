set -l here (path resolve (path dirname (status filename)))

status is-interactive; and begin
    source "$here/functions.fish"
    source "$here/yazi_integration.fish"
end

# Ship PATH bootstrap — source this at the top of any script that needs
# user-installed binaries (ship, gh, node, etc.).
#
# Claude Code and some CI environments inherit a minimal PATH
# (/usr/bin:/bin:/usr/sbin:/sbin) that excludes common install dirs.
# This adds them if they exist and aren't already on PATH.

for _ship_p in \
  "$HOME/.ship/bin" \
  "/opt/homebrew/bin" \
  "/usr/local/bin" \
  "$HOME/.local/bin" \
  "$HOME/go/bin"; do
  [ -d "$_ship_p" ] && case ":$PATH:" in *":$_ship_p:"*) ;; *) PATH="$_ship_p:$PATH" ;; esac
done
export PATH
unset _ship_p

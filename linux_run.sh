#!/usr/bin/env bash
# Run to get a terminal with HOTCli ready to use.
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# Opened by double-click with no terminal attached: reopen ourselves inside one
if [[ ! -t 0 || ! -t 1 ]]; then
  for t in "$TERMINAL" kitty konsole gnome-terminal xfce4-terminal alacritty foot xterm; do
    [[ -n "$t" ]] && command -v "$t" >/dev/null || continue
    case "$t" in
      kitty|foot)     exec "$t" "$DIR/linux_run.sh" ;;
      gnome-terminal) exec "$t" -- "$DIR/linux_run.sh" ;;
      xfce4-terminal) exec "$t" -x "$DIR/linux_run.sh" ;;
      *)              exec "$t" -e "$DIR/linux_run.sh" ;;
    esac
  done
  exit 1
fi

export PATH="$DIR/scripts:$PATH"
chmod +x "$DIR/scripts/hotcli" "$DIR/scripts/hotwatch" 2>/dev/null   # mod managers may drop the executable bit
[[ -f "$DIR/hotserver.paths" ]] || hotcli setup   # first run: find where HOTServer is installed

echo
hotcli help
echo "Type hotcli commands here, e.g.  hotcli status"
echo "Start the server using hotcli start"
echo "Closing this terminal does NOT stop the server. Use  hotcli stop  for that"
echo

exec "${SHELL:-bash}"

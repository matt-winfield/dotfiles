#!/bin/bash
# Finds the link under the mouse for the right-click menu in ~/.tmux.conf and
# stores it in pane options the menu reads:
#   @ctx_link       the link as shown (URL, mailto:, or path with :line)
#   @ctx_link_open  what `open` should get (empty when there is nothing to open)
#   @ctx_link_text  the visible text of a terminal (OSC 8) link, like the
#                   "Example homepage" of a markdown link; empty otherwise
#
# Usage: link-at-mouse.sh PANE_ID MOUSE_X MOUSE_LINE HYPERLINK PANE_CWD
#                         MOUSE_Y SCROLL_POSITION
#
# Must stay silent and exit 0: output from a foreground run-shell would show
# up in the pane.

# Ghostty starts tmux by its full path, so run-shell's PATH lacks Homebrew.
PATH=/opt/homebrew/bin:/usr/local/bin:$PATH

pane=$1
mouse_x=$2
line=$3
hyperlink=$4
cwd=$5
mouse_y=$6
scroll_position=${7:-0}

main() {
  local link open_target text=
  if [[ -n $hyperlink ]]; then
    link=$hyperlink
    text=$(hyperlink_text_at_column "$(screen_line_with_escapes)" "$mouse_x" "$hyperlink")
    [[ $text == "$link" ]] && text=
  else
    link=$(link_at_column "$line" "$mouse_x")
  fi
  open_target=$(open_target_for "$link")
  tmux set -p -t "$pane" @ctx_link "$link"
  tmux set -p -t "$pane" @ctx_link_open "$open_target"
  tmux set -p -t "$pane" @ctx_link_text "$text"
}

# The line under the mouse as tmux holds it, with OSC 8 link markers kept.
# In copy mode the view is scrolled back, so count up into the history.
screen_line_with_escapes() {
  local y
  [[ $mouse_y =~ ^[0-9]+$ ]] || return 0
  [[ $scroll_position =~ ^[0-9]+$ ]] || scroll_position=0
  y=$((mouse_y - scroll_position))
  tmux capture-pane -p -e -t "$pane" -S "$y" -E "$y"
}

# Prints the visible text of the OSC 8 link to $3 that covers column $2 of
# line $1. Colour codes are dropped first so only printed characters count.
hyperlink_text_at_column() {
  local x=$2 target=$3 s osc=$'\e]8;' st=$'\e\\' rest params uri
  local col=0 current= start=0 text=
  [[ $x =~ ^[0-9]+$ ]] || return 0
  s=$(printf '%s' "$1" | sed $'s/\e\\[[0-9;:?<=>]*[ -/]*[@-~]//g')
  while [[ -n $s ]]; do
    if [[ $s == "$osc"* ]]; then
      rest=${s#"$osc"}
      params=${rest%%"$st"*}
      s=${rest#*"$st"}
      uri=${params#*;}
      if [[ $current == "$target" ]] && ((x >= start && x < col)); then
        break
      fi
      current=$uri start=$col text=
      continue
    fi
    [[ -n $current ]] && text+=${s:0:1}
    s=${s:1}
    col=$((col + 1))
  done
  [[ $current == "$target" ]] && ((x >= start && x < col)) || return 0
  # Trim the spaces a wrapped or padded link can carry.
  text=${text#"${text%%[![:space:]]*}"}
  printf '%s' "${text%"${text##*[![:space:]]}"}"
}

# Prints the link inside the whitespace-separated word covering column $2.
link_at_column() {
  local rest=$1 x=$2 pos=0 token
  [[ $x =~ ^[0-9]+$ ]] || return 0
  while [[ $rest =~ ^([[:space:]]*)([^[:space:]]+)(.*)$ ]]; do
    pos=$((pos + ${#BASH_REMATCH[1]}))
    token=${BASH_REMATCH[2]}
    rest=${BASH_REMATCH[3]}
    if ((x >= pos && x < pos + ${#token})); then
      extract_link "$token"
      return 0
    fi
    pos=$((pos + ${#token}))
  done
}

# Prints the first URL, mailto: or file path in a word, without the
# punctuation around it. A bare file name like .tmux.conf or README.md only
# counts when it exists in the pane's directory, so words like "e.g." don't.
extract_link() {
  local scheme='[a-zA-Z][a-zA-Z0-9+.-]*://[^[:space:]]+'
  local mailto='mailto:[^[:space:]]+'
  local path='[A-Za-z0-9_.~-]*/[^[:space:]]+'
  local file_line='[A-Za-z0-9_.-]*\.[A-Za-z0-9]+:[0-9]+(:[0-9]+)?'
  local bare='[A-Za-z0-9_.-]*\.[A-Za-z0-9_-]+' name
  if [[ $1 =~ ($scheme|$mailto|$path|$file_line) ]]; then
    trim_trailing "${BASH_REMATCH[1]}"
  elif [[ $1 =~ ($bare) ]]; then
    name=$(trim_trailing "${BASH_REMATCH[1]}")
    [[ -n $cwd && -e $cwd/$name ]] && printf '%s' "$name"
  fi
}

# Drops trailing punctuation, and a ")" only when it has no matching "(", so
# https://en.wikipedia.org/wiki/Example_(disambiguation) keeps its bracket.
trim_trailing() {
  local s=$1 last opens closes
  while [[ -n $s ]]; do
    last=${s: -1}
    case $last in
      [.,\;:!?\'\"\]\>\}\`*]) s=${s%?} ;;
      \))
        opens=${s//[^(]/}
        closes=${s//[^)]/}
        ((${#closes} > ${#opens})) || break
        s=${s%?}
        ;;
      *) break ;;
    esac
  done
  printf '%s' "$s"
}

# URLs open as they are. Paths lose any :line[:col] suffix, are resolved
# against the pane's directory, and are only opened when they exist.
open_target_for() {
  local link=$1 file
  [[ -n $link ]] || return 0
  if [[ $link =~ ^[a-zA-Z][a-zA-Z0-9+.-]*: && ! $link =~ ^[^/]*\.[A-Za-z0-9]+:[0-9] ]]; then
    printf '%s' "$link"
    return 0
  fi
  file=$link
  [[ $file =~ ^(.*):[0-9]+(:[0-9]+)?$ ]] && file=${BASH_REMATCH[1]}
  # shellcheck disable=SC2088 # the literal ~ is what we're replacing
  [[ $file == "~/"* ]] && file=$HOME/${file#"~/"}
  [[ $file == /* ]] || file=$cwd/$file
  [[ -e $file ]] && printf '%s' "$file"
  return 0
}

main 2>/dev/null
exit 0

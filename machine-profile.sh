# Prints "work" or "personal".
# Resolution order: $DOTFILES_PROFILE, ~/.config/dotfiles/profile, then hostname.
# Hostnames starting with BWG- are work; any other machine is personal.
dotfiles_machine_profile() {
    if [[ -n "${DOTFILES_PROFILE:-}" ]]; then
        printf '%s\n' "$DOTFILES_PROFILE"
        return
    fi

    if [[ -f "$HOME/.config/dotfiles/profile" ]]; then
        tr -d '[:space:]' < "$HOME/.config/dotfiles/profile"
        return
    fi

    local machine_host
    machine_host="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
    case "$machine_host" in
        BWG-*) printf '%s\n' work ;;
        *) printf '%s\n' personal ;;
    esac
}

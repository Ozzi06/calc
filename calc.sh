#!/bin/bash

INSTALL_DIR="$(dirname "$(readlink -f "$0")")"
SESSIONS_DIR="$INSTALL_DIR/.sessions"
STARTUP_FILE="$INSTALL_DIR/.startup.py"

mkdir -p "$SESSIONS_DIR"

# --- CLI Flag Handling ---
SESSION_NAME="default"

usage() {
    echo "Usage: calc [-s name] [-l] [-d name]"
    echo "  -s <name>  Open/Create a named session"
    echo "  -l         List all sessions"
    echo "  -d <name>  Delete a session"
    echo "  -s <name> -r <new> Rename a session"
    exit 0
}

while getopts "s:ld:r:" opt; do
    case $opt in
        s) SESSION_NAME="$OPTARG" ;;
        l) 
            echo -e "NAME\t\tLAST USED"
            echo -e "----\t\t---------"
            for d in "$SESSIONS_DIR"/*/; do
                [ -d "$d" ] || continue
                name=$(basename "$d")
                ts_file="$d/typescript"
                if [ -f "$ts_file" ]; then
                    last_used=$(date -r "$ts_file" "+%Y-%m-%d %H:%M")
                else
                    last_used="Never"
                fi
                echo -e "$name\t\t$last_used"
            done
            exit 0
            ;;
        d)
            read -p "Delete session '$OPTARG'? [y/N] " confirm
            if [[ $confirm == [yY] ]]; then
                rm -rf "$SESSIONS_DIR/$OPTARG"
                echo "Deleted."
            fi
            exit 0
            ;;
        r)
            NEW_NAME="$OPTARG"
            if [ ! -d "$SESSIONS_DIR/$SESSION_NAME" ]; then
                echo "Session '$SESSION_NAME' does not exist."
                exit 1
            fi
            if [ -d "$SESSIONS_DIR/$NEW_NAME" ]; then
                read -p "Session '$NEW_NAME' already exists. Overwrite? [y/N] " confirm
                if [[ $confirm == [yY] ]]; then
                    rm -rf "$SESSIONS_DIR/$NEW_NAME"
                else
                    echo "Aborted."
                    exit 0
                fi
            fi
            mv "$SESSIONS_DIR/$SESSION_NAME" "$SESSIONS_DIR/$NEW_NAME"
            echo "Renamed '$SESSION_NAME' to '$NEW_NAME'."
            exit 0
            ;;
        *) usage ;;
    esac
done

# --- Main Logic ---
SESSION_PATH="$SESSIONS_DIR/$SESSION_NAME"
mkdir -p "$SESSION_PATH"
TYPESCRIPT="$SESSION_PATH/typescript"

# 1. Restore Visuals (Transcript)
if [ -f "$TYPESCRIPT" ]; then
    grep -v "^Script started\|^Script done" "$TYPESCRIPT"
    echo -e "\033[34m--- session '$SESSION_NAME' resumed | $(date "+%Y-%m-%d %H:%M") ---\033[0m"
    echo -e "math, numpy, fractions, decimal preloaded"
    echo -e "------------------------------------------------"
else
    # Brand new session header (not saved to log)
    echo -e "\033[1;32mcalc\033[0m | session: \033[36m$SESSION_NAME\033[0m"
    echo -e "math, numpy, fractions, decimal preloaded"
    echo -e "------------------------------------------------"
fi

# 2. Setup Environment
export SESSION_DIR="$SESSION_PATH"
export PYTHONSTARTUP="$STARTUP_FILE"

# 3. Launch with 'script'
# -a: append
# -q: quiet
# -c: command to run
script -a -q -c "python3 -q -i" "$TYPESCRIPT"

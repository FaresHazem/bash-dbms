#!/bin/bash

# --- Setup ---
DB_ROOT="./databases"
mkdir -p "$DB_ROOT"
MODE="CLI" # Default mode

# --- UI ABSTRACTION LAYER ---
# These functions handle the "Difference" between Terminal and GUI

function msg_box() {
    local msg=$1
    if [[ "$MODE" == "GUI" ]]; then
        zenity --info --text="$msg" --width=300
    else
        echo -e "\n>>> $msg"
        read -p "Press Enter to continue..."
    fi
}

function err_box() {
    local msg=$1
    if [[ "$MODE" == "GUI" ]]; then
        zenity --error --text="$msg" --width=300
    else
        echo -e "\n!!! ERROR: $msg"
        read -p "Press Enter to continue..."
    fi
}

function get_input() {
    local label=$1
    if [[ "$MODE" == "GUI" ]]; then
        zenity --entry --title="Input Required" --text="$label"
    else
        local val
        read -p "$label: " val
        echo "$val"
    fi
}

function show_data() {
    local title=$1
    local file=$2
    if [[ "$MODE" == "GUI" ]]; then
        (sed -n '1p' "$file"; tail -n +4 "$file") | column -s, -t | \
        zenity --text-info --title="$title" --font="Monospace" --width=600 --height=400
    else
        echo -e "\n--- $title ---"
        (sed -n '1p' "$file"; tail -n +4 "$file") | column -s, -t
        read -p "Press Enter..."
    fi
}

# --- CORE LOGIC (The "Engine") ---
# This logic is written ONCE and used by both modes.

function join_by { local d=${1-} f=${2-}; if shift 2; then printf %s "$f" "${@/#/$d}"; fi; }
function is_int { [[ "$1" =~ ^-?[0-9]+$ ]]; }

function core_insert_row() {
    local db_path=$1 t_name=$2
    local t_file="$db_path/$t_name.txt"
    [[ ! -f "$t_file" ]] && { err_box "Table not found"; return; }

    IFS=',' read -r -a c_names < <(sed -n '1p' "$t_file")
    IFS=',' read -r -a c_types < <(sed -n '2p' "$t_file")
    local pk_idx=$(sed -n '3p' "$t_file")
    
    row=()
    for i in "${!c_names[@]}"; do
        while true; do
            val=$(get_input "Value for ${c_names[$i]} (${c_types[$i]})")
            [[ -z "$val" ]] && return # User cancelled
            
            if [[ "${c_types[$i]}" == "int" ]] && ! is_int "$val"; then
                err_box "Must be an integer"; continue
            fi
            if [[ "$i" -eq "$pk_idx" ]]; then
                if ! awk -F, -v col=$((pk_idx+1)) -v v="$val" 'NR>3 {if($col==v) exit 1}' "$t_file"; then
                    err_box "Primary Key '$val' already exists"; continue
                fi
            fi
            row+=("$val")
            break
        done
    done
    join_by "," "${row[@]}" >> "$t_file"
    msg_box "Row inserted successfully."
}

# --- MENUS ---

function table_menu() {
    local db_name=$1
    local db_path="$DB_ROOT/$db_name"
    while true; do
        if [[ "$MODE" == "GUI" ]]; then
            choice=$(zenity --list --title="DB: $db_name" --width=400 --height=400 \
                --column="Option" "Create Table" "List Tables" "Insert Row" "Select All" "Delete Row" "Update Row" "Drop Table" "Disconnect")
        else
            echo -e "\n-- Database: $db_name (Terminal Mode) --"
            echo "1) Create Table   2) List Tables   3) Insert Row"
            echo "4) Select All     5) Delete Row    6) Update Row"
            echo "7) Drop Table     8) Disconnect"
            read -p "Choice: " choice
            # Map numbers to names for the case statement
            case $choice in 1) choice="Create Table";; 2) choice="List Tables";; 3) choice="Insert Row";; 
                            4) choice="Select All";; 5) choice="Delete Row";; 6) choice="Update Row";;
                            7) choice="Drop Table";; 8) choice="Disconnect";; esac
        fi

        [[ -z "$choice" || "$choice" == "Disconnect" ]] && break

        case "$choice" in
            "Create Table")
                t_name=$(get_input "Table Name")
                col_count=$(get_input "Number of Columns")
                cols=(); types=()
                for ((i=1; i<=col_count; i++)); do
                    cols+=($(get_input "Col $i Name"))
                    types+=($(get_input "Col $i Type (str/int)"))
                done
                pk=$(get_input "PK Column Number (1-$col_count)")
                join_by "," "${cols[@]}" > "$db_path/$t_name.txt"
                join_by "," "${types[@]}" >> "$db_path/$t_name.txt"
                echo "$((pk-1))" >> "$db_path/$t_name.txt"
                msg_box "Table created."
                ;;
            "List Tables")
                list=$(ls "$db_path" | sed 's/\.txt//')
                [[ "$MODE" == "GUI" ]] && zenity --info --text="$list" || echo -e "\n$list\n" && read
                ;;
            "Insert Row") core_insert_row "$db_path" "$(get_input "Table Name")" ;;
            "Select All") 
                t=$(get_input "Table Name")
                show_data "$t" "$db_path/$t.txt" 
                ;;
            "Delete Row")
                t=$(get_input "Table Name"); pk_v=$(get_input "PK value to delete")
                pk_idx=$(sed -n '3p' "$db_path/$t.txt")
                tmp=$(mktemp)
                awk -F, -v col=$((pk_idx+1)) -v v="$pk_v" 'NR<=3 || $col != v' "$db_path/$t.txt" > "$tmp"
                mv "$tmp" "$db_path/$t.txt"
                msg_box "Done."
                ;;
            "Drop Table") rm "$db_path/$(get_input "Table Name").txt" && msg_box "Dropped." ;;
        esac
    done
}

# --- STARTUP ---

# 1. Choose Mode
choice=$(zenity --list --title="Choose Interface" --column="Mode" "Terminal" "Graphical (GUI)" --width=300 --height=200 2>/dev/null)
if [[ "$choice" == "Graphical (GUI)" ]]; then
    MODE="GUI"
else
    MODE="CLI"
    clear
fi

# 2. Main Menu Loop
while true; do
    if [[ "$MODE" == "GUI" ]]; then
        main_choice=$(zenity --list --title="Main Menu" --width=400 --height=400 --column="Action" \
            "Create Database" "List Databases" "Connect" "Drop Database" "Exit")
    else
        echo -e "\n=== MAIN MENU (Terminal) ==="
        echo "1) Create Database  2) List Databases"
        echo "3) Connect          4) Drop Database"
        echo "5) Exit"
        read -p "Choice: " main_choice
        case $main_choice in 1) main_choice="Create Database";; 2) main_choice="List Databases";; 3) main_choice="Connect";; 4) main_choice="Drop Database";; 5) main_choice="Exit";; esac
    fi

    [[ -z "$main_choice" || "$main_choice" == "Exit" ]] && exit 0

    case "$main_choice" in
        "Create Database") mkdir -p "$DB_ROOT/$(get_input "DB Name")" && msg_box "DB Created" ;;
        "List Databases") list=$(ls "$DB_ROOT"); [[ "$MODE" == "GUI" ]] && zenity --info --text="$list" || echo "$list" ;;
        "Connect") 
            db=$(get_input "Enter DB Name")
            [[ -d "$DB_ROOT/$db" ]] && table_menu "$db" || err_box "Not found"
            ;;
        "Drop Database") rm -r "$DB_ROOT/$(get_input "DB Name")" && msg_box "Dropped" ;;
    esac
done

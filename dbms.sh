#!/bin/bash
# --- Setup ---
DB_ROOT="./databases"
mkdir -p "$DB_ROOT"
MODE="GUI" # Default mode

# --- UI ABSTRACTION LAYER ---
# These functions handle the "Difference" between Terminal and GUI

function msg_box() {
    local msg=$1
    if [[ "$MODE" == "GUI" ]]; then
        zenity --info --text="$msg" --width=400 2>/dev/null
    else
        echo -e "\n>>> $msg"
        read -p "Press Enter to continue..."
    fi
}

function err_box() {
    local msg=$1
    if [[ "$MODE" == "GUI" ]]; then
        zenity --error --text="$msg" --width=400 2>/dev/null
    else
        echo -e "\n!!! ERROR: $msg"
        read -p "Press Enter to continue..."
    fi
}

function get_input() {
    local label=$1
    if [[ "$MODE" == "GUI" ]]; then
        zenity --entry --title="Input Required" --text="$label" --width=500 2>/dev/null
    else
        local val
        read -p "$label: " val
        echo "$val"
    fi
}

function select_table() {
    local db_path=$1
    if [[ "$MODE" == "GUI" ]]; then
        local list=$(ls "$db_path" 2>/dev/null | sed 's/\.txt//')
        if [[ -z "$list" ]]; then
            zenity --info --text="No tables found." --width=400 2>/dev/null
            return 1
        fi
        local choice=$(zenity --list --title="Select Table" --column="Table Name" $list --width=500 --height=400 2>/dev/null)
        [[ -z "$choice" ]] && return 1
        echo "$choice"
    else
        get_input "Table Name"
    fi
}

function show_data() {
    local title=$1
    local file=$2
    if [[ "$MODE" == "GUI" ]]; then
        if [[ ! -s "$file" ]]; then
            zenity --info --text="Table is empty or corrupt." --width=400 2>/dev/null
            return
        fi
        # Display Header (Line 1) and Data (Line 4+)
        (sed -n '1p' "$file"; tail -n +4 "$file") | column -s, -t | \
        zenity --text-info --title="$title" --font="Monospace" --width=800 --height=500 2>/dev/null
    else
        echo -e "\n--- $title ---"
        (sed -n '1p' "$file"; tail -n +4 "$file") | column -s, -t
        read -p "Press Enter..."
    fi
}

# --- CORE LOGIC (The "Engine") ---

function join_by { local d=${1-} f=${2-}; if shift 2; then printf %s "$f" "${@/#/$d}"; fi; }
function is_int { [[ "$1" =~ ^-?[0-9]+$ ]]; }

function core_insert_row() {
    local db_path=$1 t_name=$2
    local t_file="$db_path/$t_name.txt"
    [[ ! -f "$t_file" ]] && { err_box "Table not found"; return; }

    # Read Metadata
    IFS=',' read -r -a c_names < <(sed -n '1p' "$t_file")
    IFS=',' read -r -a c_types < <(sed -n '2p' "$t_file")
    local pk_idx=$(sed -n '3p' "$t_file")

    # Basic Validation
    if [[ ${#c_names[@]} -eq 0 ]]; then err_box "Table corrupted (no headers)"; return; fi

    row=()
    for i in "${!c_names[@]}"; do
        while true; do
            val=$(get_input "Value for ${c_names[$i]} (${c_types[$i]})")
            [[ -z "$val" ]] && return # Cancel/Empty handling
            
            # Type Validation
            if [[ "${c_types[$i]}" == "int" ]] && ! is_int "$val"; then
                err_box "Must be an integer"; continue
            fi
            
            # PK Uniqueness Check
            if [[ "$i" -eq "$pk_idx" ]]; then
                # Check data rows (line 4 onwards)
                # Fix: Use 'found' flag and exit !found in END block to correctly return status
                if awk -F, -v col=$((pk_idx+1)) -v v="$val" 'NR>3 {if($col==v) {found=1; exit 0}} END {exit !found}' "$t_file"; then
                     err_box "Primary Key '$val' already exists"; continue
                fi
            fi
            row+=("$val")
            break
        done
    done

    if [[ -s "$t_file" && -n "$(tail -c 1 "$t_file")" ]]; then
        echo "" >> "$t_file"
    fi

    join_by "," "${row[@]}" >> "$t_file"
    msg_box "Row inserted successfully."
}

function core_update_row() {
    local db_path=$1 t_name=$2
    local t_file="$db_path/$t_name.txt"
    [[ ! -f "$t_file" ]] && { err_box "Table not found"; return; }

    IFS=',' read -r -a c_names < <(sed -n '1p' "$t_file")
    IFS=',' read -r -a c_types < <(sed -n '2p' "$t_file")
    local pk_idx=$(sed -n '3p' "$t_file")
    local pk_awk_idx=$((pk_idx + 1))
    local pk_type=${c_types[$pk_idx]}

    local pk_val=$(get_input "Enter Primary Key of row to update")
    [[ -z "$pk_val" ]] && return

    if ! awk -F, -v col="$pk_awk_idx" -v v="$pk_val" -v type="$pk_type" \
        'NR>3 {
            if (type == "int") {
                if ($col+0 == v+0) {found=1; exit 0}
            } else {
                if ($col == v) {found=1; exit 0}
            }
        } END {exit !found}' "$t_file"; then
         err_box "Row with PK '$pk_val' not found"; return
    fi

    local available_cols=()
    for i in "${!c_names[@]}"; do
        if [[ "$i" -ne "$pk_idx" ]]; then
            available_cols+=("${c_names[$i]}")
        fi
    done

    if [[ ${#available_cols[@]} -eq 0 ]]; then
        err_box "No editable columns (Only PK exists)"
        return
    fi

    local col_choice
    if [[ "$MODE" == "GUI" ]]; then
        col_choice=$(zenity --list --title="Select Column" --column="Column Name" "${available_cols[@]}" --width=500 --height=450 2>/dev/null)
    else
        echo "Available columns: ${available_cols[*]}"
        read -p "Enter column to update: " col_choice
    fi
    [[ -z "$col_choice" ]] && return

    local update_idx=-1
    local type_check=""
    for i in "${!c_names[@]}"; do
        if [[ "${c_names[$i]}" == "$col_choice" ]]; then
            update_idx=$i
            type_check="${c_types[$i]}"
            break
        fi
    done

    if [[ "$update_idx" -eq -1 ]]; then err_box "Invalid Column Name"; return; fi

    if [[ "$update_idx" -eq "$pk_idx" ]]; then
        err_box "Cannot update Primary Key column."
        return
    fi

    local new_val=$(get_input "Enter new value for $col_choice ($type_check)")
    
    if [[ "$type_check" == "int" ]] && ! is_int "$new_val"; then
        err_box "Value must be an integer"; return
    fi

    local awk_col=$((update_idx + 1))
    local tmp=$(mktemp)
    
    awk -F, -v pk_col="$pk_awk_idx" -v pk_v="$pk_val" \
            -v upd_col="$awk_col" -v new_v="$new_val" \
            -v type="$pk_type" \
            'BEGIN{OFS=","} {
                if (NR>3) {
                    match_found = 0;
                    if (type == "int") {
                        if ($pk_col+0 == pk_v+0) match_found = 1
                    } else {
                        if ($pk_col == pk_v) match_found = 1
                    }
                    if (match_found) $upd_col=new_v;
                }
                print
            }' "$t_file" > "$tmp"
    
    mv "$tmp" "$t_file"
    msg_box "Update Successful."
}

# --- MENUS ---

function table_menu() {
    local db_name=$1
    local db_path="$DB_ROOT/$db_name"
    while true; do
        if [[ "$MODE" == "GUI" ]]; then
            choice=$(zenity --list --title="DB: $db_name" --width=500 --height=450 \
                --column="Option" "Create Table" "List Tables" "Insert Row" "Select All" "Delete Row" "Update Row" "Drop Table" "Disconnect" 2>/dev/null)
        else
            echo -e "\n-- Database: $db_name (Terminal Mode) --"
            echo "1) Create Table   2) List Tables   3) Insert Row"
            echo "4) Select All     5) Delete Row    6) Update Row"
            echo "7) Drop Table     8) Disconnect"
            read -p "Choice: " choice
            case $choice in 1) choice="Create Table";; 2) choice="List Tables";; 3) choice="Insert Row";; 
                            4) choice="Select All";; 5) choice="Delete Row";; 6) choice="Update Row";;
                            7) choice="Drop Table";; 8) choice="Disconnect";; esac
        fi

        [[ -z "$choice" || "$choice" == "Disconnect" ]] && break

        case "$choice" in
            "Create Table")
                t_name=$(get_input "Table Name")
                [[ -z "$t_name" ]] && continue
                
                col_count=$(get_input "Number of Columns")
                ! is_int "$col_count" && { err_box "Invalid Number"; continue; }

                cols=(); types=()
                for ((i=1; i<=col_count; i++)); do
                    cols+=("$(get_input "Col $i Name")")
                    types+=("$(get_input "Col $i Type (str/int)")")
                done
                
                pk=$(get_input "PK Column Number (1-$col_count)")
                ! is_int "$pk" && { err_box "Invalid PK"; continue; }

                join_by "," "${cols[@]}" > "$db_path/$t_name.txt"
                echo "" >> "$db_path/$t_name.txt"
                
                join_by "," "${types[@]}" >> "$db_path/$t_name.txt"
                echo "" >> "$db_path/$t_name.txt"
                
                echo "$((pk-1))" >> "$db_path/$t_name.txt"
                
                msg_box "Table created."
                ;;
            "List Tables")
                list=$(ls "$db_path" 2>/dev/null | sed 's/\.txt//')
                if [[ -z "$list" ]]; then
                    msg_box "No tables found."
                else
                    if [[ "$MODE" == "GUI" ]]; then
                        zenity --list --title="Tables" --column="Table Name" $list --width=500 --height=400 >/dev/null 2>&1
                    else
                        echo -e "\n--- Tables ---\n$list"
                        read -p "Press Enter..."
                    fi
                fi
                ;;
            "Insert Row") 
                t_name=$(select_table "$db_path")
                [[ -n "$t_name" ]] && {
                    [[ -f "$db_path/$t_name.txt" ]] && core_insert_row "$db_path" "$t_name" || err_box "Table not found"
                }
                ;;
            "Select All") 
                t=$(select_table "$db_path")
                [[ -n "$t" ]] && {
                    [[ -f "$db_path/$t.txt" ]] && show_data "$t" "$db_path/$t.txt" || err_box "Table not found"
                }
                ;;
            "Delete Row")
                t=$(select_table "$db_path")
                [[ -n "$t" ]] && {
                    if [[ -f "$db_path/$t.txt" ]]; then
                        pk_v=$(get_input "PK value to delete")
                        pk_idx=$(sed -n '3p' "$db_path/$t.txt")
                        tmp=$(mktemp)
                        # Keep lines 1-3 (metadata) + rows that don't match PK
                        awk -F, -v col=$((pk_idx+1)) -v v="$pk_v" 'NR<=3 || $col != v' "$db_path/$t.txt" > "$tmp"
                        mv "$tmp" "$db_path/$t.txt"
                        msg_box "Done."
                    else
                        err_box "Table not found"
                    fi
                }
                ;;
            "Update Row")
                t_name=$(select_table "$db_path")
                [[ -n "$t_name" ]] && {
                    [[ -f "$db_path/$t_name.txt" ]] && core_update_row "$db_path" "$t_name" || err_box "Table not found"
                }
                ;;
            "Drop Table") 
                t=$(select_table "$db_path")
                [[ -n "$t" ]] && rm "$db_path/$t.txt" 2>/dev/null && msg_box "Dropped." 
                ;;
        esac
    done
}

# --- STARTUP ---

choice=$(zenity --list --title="Choose Interface" --column="Mode" "Terminal" "Graphical (GUI)" --width=400 --height=400 2>/dev/null)
if [[ "$choice" == "Graphical (GUI)" ]]; then
    MODE="GUI"
else
    MODE="CLI"
    clear
fi

while true; do
    if [[ "$MODE" == "GUI" ]]; then
        main_choice=$(zenity --list --title="Main Menu" --width=500 --height=450 --column="Action" \
            "Create Database" "List Databases" "Connect" "Drop Database" "Exit" 2>/dev/null)
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
        "Create Database") 
            dbname=$(get_input "DB Name")
            [[ -n "$dbname" ]] && mkdir -p "$DB_ROOT/$dbname" && msg_box "DB Created" 
            ;;
        "List Databases") 
            list=$(ls "$DB_ROOT" 2>/dev/null)
            if [[ -z "$list" ]]; then
                msg_box "No databases found."
            else
                if [[ "$MODE" == "GUI" ]]; then
                    zenity --list --title="Databases" --column="Database Name" $list --width=500 --height=400 >/dev/null 2>&1
                else
                    echo -e "\n--- Databases ---\n$list"
                    read -p "Press Enter..."
                fi
            fi
            ;;
        "Connect") 
            if [[ "$MODE" == "GUI" ]]; then
                list=$(ls "$DB_ROOT" 2>/dev/null)
                if [[ -z "$list" ]]; then
                     msg_box "No databases found to connect to."
                else
                    db=$(zenity --list --title="Connect to Database" --column="Database Name" $list --width=500 --height=400 2>/dev/null)
                    [[ -n "$db" ]] && table_menu "$db"
                fi
            else
                db=$(get_input "Enter DB Name")
                [[ -d "$DB_ROOT/$db" ]] && table_menu "$db" || err_box "Not found"
            fi
            ;;
        "Drop Database") 
            dbname=$(get_input "DB Name")
            [[ -d "$DB_ROOT/$dbname" ]] && rm -r "$DB_ROOT/$dbname" && msg_box "Dropped" 
            ;;
    esac
done
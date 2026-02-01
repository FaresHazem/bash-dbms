#!/bin/bash

DB_ROOT="./databases"

# Ensure databases folder exists
mkdir -p "$DB_ROOT"

# Display Main Menu
show_main_menu() {
    echo "=============================="
    echo "       Bash DBMS"
    echo "=============================="
    echo "1) Create Database"
    echo "2) List Databases"
    echo "3) Connect To Database"
    echo "4) Drop Database"
    echo "5) Exit"
    echo "=============================="
    echo -n "Enter choice: "
}

# Main Loop
while true
do
    clear
    show_main_menu
    read choice

    case $choice in

        1)  # Create Database
            echo "Enter Database Name: "
            read db_name

            if [[ -z "$db_name" ]]; then
                echo "Name cannot be empty!"
            elif [[ -d "$DB_ROOT/$db_name" ]]; then
                echo "Database already exists!"
            else
                mkdir "$DB_ROOT/$db_name"
                echo "Database '$db_name' created successfully."
            fi
            read -p "Press Enter to continue..."
            ;;

        2)  # List Databases
            echo "Available Databases:"
            echo "--------------------"
            if [ "$(ls -A $DB_ROOT)" ]; then
                ls "$DB_ROOT"
            else
                echo "No databases found."
            fi
            read -p "Press Enter to continue..."
            ;;

        3)  # Connect To Database
            echo "Enter Database Name to Connect: "
            read db_name

            if [[ -z "$db_name" ]]; then
                echo "Name cannot be empty!"
            elif [[ ! -d "$DB_ROOT/$db_name" ]]; then
                echo "Database does not exist!"
            else
                DB_PATH="$DB_ROOT/$db_name"
                while true
                do
                    clear
                    echo "=============================="
                    echo " Connected to Database: $db_name"
                    echo "=============================="
                    echo "1) Create Table"
                    echo "2) List Tables"
                    echo "3) Drop Table"
                    echo "4) Insert Into Table"
                    echo "5) Select From Table"
                    echo "6) Delete From Table"
                    echo "7) Update Table"
                    echo "8) Back to Main Menu"
                    echo "=============================="
                    echo -n "Enter choice: "
                    read table_choice

                    case $table_choice in

                        1)  # Create Table
                            echo "Enter Table Name: "
                            read table_name

                            if [[ -z "$table_name" ]]; then
                                echo "Table name cannot be empty!"
                            elif [[ -f "$DB_PATH/$table_name.txt" ]]; then
                                echo "Table already exists!"
                            else
                                echo "Enter number of columns: "
                                read col_count

                                if ! [[ "$col_count" =~ ^[0-9]+$ ]] || [[ "$col_count" -le 0 ]]; then
                                    echo "Invalid number of columns!"
                                else
                                    cols=()
                                    types=()
                                    for ((i=1; i<=col_count; i++)); do
                                        read -p "Column $i name: " col_name
                                        read -p "Column $i datatype (int/string): " col_type

                                        cols+=("$col_name")
                                        types+=("$col_type")
                                    done

                                    echo "Columns: ${cols[*]}"
                                    echo "Datatypes: ${types[*]}"
                                    echo "Select Primary Key column number (1-$col_count): "
                                    read pk
                                    pk_index=$((pk-1))

                                    # Save table schema
                                    echo "${cols[*]}" | tr ' ' ',' > "$DB_PATH/$table_name.txt"
                                    echo "${types[*]}" | tr ' ' ',' >> "$DB_PATH/$table_name.txt"
                                    echo "$pk_index" >> "$DB_PATH/$table_name.txt"

                                    echo "Table '$table_name' created successfully!"
                                fi
                            fi
                            read -p "Press Enter to continue..."
                            ;;

                        2)  # List Tables
                            echo "Tables in database '$db_name':"
                            echo "-------------------------------"
                            if [ "$(ls -A $DB_PATH/*.txt 2>/dev/null)" ]; then
                                for t in "$DB_PATH"/*.txt; do
                                    echo "$(basename "$t" .txt)"
                                done
                            else
                                echo "No tables found."
                            fi
                            read -p "Press Enter to continue..."
                            ;;

                        3)  # Drop Table
                            echo "Enter Table Name to Drop: "
                            read table_name
                            if [[ -z "$table_name" ]]; then
                                echo "Table name cannot be empty!"
                            elif [[ ! -f "$DB_PATH/$table_name.txt" ]]; then
                                echo "Table does not exist!"
                            else
                                read -p "Are you sure you want to delete '$table_name'? (y/n): " confirm
                                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                                    rm "$DB_PATH/$table_name.txt"
                                    echo "Table '$table_name' deleted successfully."
                                else
                                    echo "Operation cancelled."
                                fi
                            fi
                            read -p "Press Enter to continue..."
                            ;;

                        4)  # Insert Into Table
                            echo "Enter Table Name to Insert Into: "
                            read table_name
                            TABLE_FILE="$DB_PATH/$table_name.txt"
                            if [[ -z "$table_name" ]]; then
                                echo "Table name cannot be empty!"
                            elif [[ ! -f "$TABLE_FILE" ]]; then
                                echo "Table does not exist!"
                            else
                                # Read schema
                                IFS=',' read -r -a cols < <(sed -n '1p' "$TABLE_FILE")
                                IFS=',' read -r -a types < <(sed -n '2p' "$TABLE_FILE")
                                pk_index=$(sed -n '3p' "$TABLE_FILE")

                                row=()
                                for i in "${!cols[@]}"; do
                                    while true; do
                                        read -p "Enter value for ${cols[i]} (${types[i]}): " val

                                        # Type check
                                        if [[ "${types[i]}" == "int" ]]; then
                                            if [[ ! "$val" =~ ^-?[0-9]+$ ]]; then
                                                echo "Invalid integer!"
                                                continue
                                            fi
                                        fi

                                        # Check primary key uniqueness
                                        if [[ "$i" -eq "$pk_index" ]]; then
                                            if awk -F, -v pk=$((pk_index+1)) -v v="$val" 'NR>3{if($pk==v){exit 1}}' "$TABLE_FILE"; then
                                                row+=("$val")
                                                break
                                            else
                                                echo "Primary key value must be unique!"
                                                continue
                                            fi
                                        else
                                            row+=("$val")
                                            break
                                        fi
                                    done
                                done

                                # Append row
                                echo "${row[*]}" | tr ' ' ',' >> "$TABLE_FILE"
                                echo "Row inserted successfully!"
                            fi
                            read -p "Press Enter to continue..."
                            ;;

                        5)  # Select From Table
                            echo "Enter Table Name to Select From: "
                            read table_name
                            TABLE_FILE="$DB_PATH/$table_name.txt"
                            if [[ -z "$table_name" ]]; then
                                echo "Table name cannot be empty!"
                            elif [[ ! -f "$TABLE_FILE" ]]; then
                                echo "Table does not exist!"
                            else
                                echo "Data in '$table_name':"
                                echo "-----------------------"
                                # Skip first 3 lines (schema) and display
                                tail -n +4 "$TABLE_FILE" | column -s, -t
                            fi
                            read -p "Press Enter to continue..."
                            ;;

                        6)  # Delete From Table
                            echo "Enter Table Name to Delete From: "
                            read table_name
                            TABLE_FILE="$DB_PATH/$table_name.txt"
                            if [[ -z "$table_name" ]]; then
                                echo "Table name cannot be empty!"
                            elif [[ ! -f "$TABLE_FILE" ]]; then
                                echo "Table does not exist!"
                            else
                                IFS=',' read -r -a cols < <(sed -n '1p' "$TABLE_FILE")
                                echo "Enter primary key value of row to delete (${cols[$(sed -n '3p' $TABLE_FILE)]}): "
                                read pk_val
                                pk_index=$(sed -n '3p' "$TABLE_FILE")
                                # Delete row
                                if grep -q "^$pk_val," <(tail -n +4 "$TABLE_FILE"); then
                                    tmp_file=$(mktemp)
                                    head -n 3 "$TABLE_FILE" > "$tmp_file"
                                    tail -n +4 "$TABLE_FILE" | awk -F, -v pk=$((pk_index+1)) -v val="$pk_val" ' $pk != val {print}' >> "$tmp_file"
                                    mv "$tmp_file" "$TABLE_FILE"
                                    echo "Row deleted successfully."
                                else
                                    echo "Row not found."
                                fi
                            fi
                            read -p "Press Enter to continue..."
                            ;;

                        7)  # Update Table
                            echo "Enter Table Name to Update: "
                            read table_name
                            TABLE_FILE="$DB_PATH/$table_name.txt"
                            if [[ -z "$table_name" ]]; then
                                echo "Table name cannot be empty!"
                            elif [[ ! -f "$TABLE_FILE" ]]; then
                                echo "Table does not exist!"
                            else
                                IFS=',' read -r -a cols < <(sed -n '1p' "$TABLE_FILE")
                                IFS=',' read -r -a types < <(sed -n '2p' "$TABLE_FILE")
                                pk_index=$(sed -n '3p' "$TABLE_FILE")
                                echo "Enter primary key value of row to update (${cols[$pk_index]}): "
                                read pk_val
                                if ! grep -q "^$pk_val," <(tail -n +4 "$TABLE_FILE"); then
                                    echo "Row not found."
                                else
                                    row_index=$(tail -n +4 "$TABLE_FILE" | awk -F, -v pk=$((pk_index+1)) -v val="$pk_val" ' $pk==val {print NR; exit }')
                                    new_row=()
                                    for i in "${!cols[@]}"; do
                                        read -p "Enter new value for ${cols[i]} (${types[i]}): " val
                                        # Type check
                                        if [[ "${types[i]}" == "int" ]]; then
                                            if [[ ! "$val" =~ ^-?[0-9]+$ ]]; then
                                                echo "Invalid integer! Using old value."
                                                val=$(sed -n "$((3+row_index))p" "$TABLE_FILE" | cut -d, -f $((i+1)))
                                            fi
                                        fi
                                        # PK uniqueness check
                                        if [[ "$i" -eq "$pk_index" ]]; then
                                            if awk -F, -v pk=$((pk_index+1)) -v v="$val" 'NR>3{if($pk==v){exit 1}}' "$TABLE_FILE"; then
                                                :
                                            else
                                                echo "Primary key must be unique! Using old value."
                                                val=$(sed -n "$((3+row_index))p" "$TABLE_FILE" | cut -d, -f $((i+1)))
                                            fi
                                        fi
                                        new_row+=("$val")
                                    done
                                    # Replace row
                                    tmp_file=$(mktemp)
                                    head -n 3 "$TABLE_FILE" > "$tmp_file"
                                    tail -n +4 "$TABLE_FILE" | awk -v r=$row_index -F, 'NR==r{$0=""}1' >> "$tmp_file"
                                    echo "${new_row[*]}" | tr ' ' ',' >> "$tmp_file"
                                    mv "$tmp_file" "$TABLE_FILE"
                                    echo "Row updated successfully."
                                fi
                            fi
                            read -p "Press Enter to continue..."
                            ;;

                        8) break ;;
                        *) echo "Invalid choice!"; read -p "Press Enter..." ;;
                    esac
                done
            fi
            ;;

        4)  # Drop Database
            echo "Enter Database Name to Drop: "
            read db_name
            if [[ -z "$db_name" ]]; then
                echo "Name cannot be empty!"
            elif [[ ! -d "$DB_ROOT/$db_name" ]]; then
                echo "Database does not exist!"
            else
                read -p "Are you sure you want to delete '$db_name'? (y/n): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    rm -r "$DB_ROOT/$db_name"
                    echo "Database '$db_name' deleted successfully."
                else
                    echo "Operation cancelled."
                fi
            fi
            read -p "Press Enter to continue..."
            ;;

        5)  # Exit
            echo "Goodbye!"
            exit 0
            ;;

        *)
            echo "Invalid choice!"
            read -p "Press Enter to continue..."
            ;;
    esac

done

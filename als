#!/bin/bash

# Initialize variables
ALL_FILES=false
DIR=""
SORT_BY="name"       # default sorting
REVERSE=false
DIRS_FIRST=false

show_help() {
    echo -e "Usage: ./als.sh [OPTIONS] [DIRECTORY]"
    echo -e "\nA beautiful, enhanced directory listing utility for Termux.\n"
    echo -e "Options:"
    echo -e "  -a, --all         Show hidden and dot files"
    echo -e "  -s, --sort TYPE   Sort by: name, size, type (Default: name)"
    echo -e "  -r, --reverse     Reverse the sorting order"
    echo -e "  -d, --dirs-first  Group directories at the top"
    echo -e "  -h, --help        Display this help menu"
    exit 0
}

# Parse Arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            ALL_FILES=true
            shift
            ;;
        -s|--sort)
            if [[ "$2" =~ ^(name|size|type)$ ]]; then
                SORT_BY="$2"
                shift 2
            else
                echo "Error: Invalid sort type '$2'. Use name, size, or type."
                exit 1
            fi
            ;;
        -r|--reverse)
            REVERSE=true
            shift
            ;;
        -d|--dirs-first)
            DIRS_FIRST=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        -*)
            echo "Unknown option: $1. Use -h or --help for usage details."
            exit 1
            ;;
        *)
            DIR=$1
            shift
            ;;
    esac
done

# Default path check
if [[ -z "$DIR" ]]; then
    DIR=$(pwd)
fi
DIR=$(realpath "$DIR")

if [[ ! -d "$DIR" ]]; then
    echo "Error: Directory '$DIR' does not exist."
    exit 1
fi

# Gather initial file list
if [ "$ALL_FILES" = true ]; then
    LIST=$(ls -A "$DIR")
else
    LIST=$(ls "$DIR")
fi

if [[ -z "$LIST" ]]; then
    echo "Directory is empty."
    exit 0
fi

mapfile -t LIST_ARRAY <<< "$LIST"

# Column Configurations
MAX_NAME_LEN=25
MAX_SIZE_LEN=10
MAX_TYPE_LEN=16

# Temp arrays to collect data values for sorting processing
declare -A FILE_SIZES_RAW
declare -A FILE_SIZES_HUMAN
declare -A FILE_TYPES
declare -A FILE_IS_DIR
declare -A FILE_IS_SYMLINK

# Pre-fetch properties for processing and sorting
for file in "${LIST_ARRAY[@]}"; do
    [[ -z "$file" ]] && continue
    FULL_PATH="$DIR/$file"
    [[ ! -e "$FULL_PATH" && ! -L "$FULL_PATH" ]] && continue

    # Standard link tracking (Removed manual storage override)
    if [ -h "$FULL_PATH" ] || [ -L "$FULL_PATH" ]; then
        FILE_IS_SYMLINK["$file"]=true
        FILE_IS_DIR["$file"]=false
    else
        FILE_IS_SYMLINK["$file"]=false
        if [ -d "$FULL_PATH" ]; then
            FILE_IS_DIR["$file"]=true
        else
            FILE_IS_DIR["$file"]=false
        fi
    fi

    # Raw Sizes for structural ordering calculations
    if [ ! -r "$FULL_PATH" ]; then
        FILE_SIZES_HUMAN["$file"]="Locked"
        FILE_SIZES_RAW["$file"]=-1
    else
        # True size parsing
        size_string=$(du -sh "$FULL_PATH" | awk '{print $1}')
        FILE_SIZES_HUMAN["$file"]=$size_string
        
        # Translate human metrics (K, M, G) into pure block integers for numerical sorting accuracy
        num=$(echo "$size_string" | grep -oE '^[0-9.]+')
        unit=$(echo "$size_string" | grep -oE '[A-Z]+$')
        if [ "${FILE_IS_DIR["$file"]}" = true ] && [[ -z "$num" ]]; then
            FILE_SIZES_RAW["$file"]=0
        else
            case $unit in
                K) FILE_SIZES_RAW["$file"]=$(awk "BEGIN {print $num * 1024}") ;;
                M) FILE_SIZES_RAW["$file"]=$(awk "BEGIN {print $num * 1048576}") ;;
                G) FILE_SIZES_RAW["$file"]=$(awk "BEGIN {print $num * 1073741824}") ;;
                *) FILE_SIZES_RAW["$file"]=${num:-0} ;;
            esac
        fi
    fi

    # Format Column File Type Labels
    if [ "${FILE_IS_SYMLINK["$file"]}" = true ]; then
        FILE_TYPES["$file"]="Symlink"
    elif [ "${FILE_IS_DIR["$file"]}" = true ]; then
        FILE_TYPES["$file"]="Directory"
    elif [ -x "$FULL_PATH" ]; then
        FILE_TYPES["$file"]="Executable"
    else
        ext="${file##*.}"
        if [[ "$ext" != "$file" && -n "$ext" ]]; then
            FILE_TYPES["$file"]="${ext^^} File"
        else
            FILE_TYPES["$file"]="Regular File"
        fi
    fi
done

# Custom Sorting Algorithm via Array Parsing
SORTED_KEYS=("${LIST_ARRAY[@]}")

# Sort Implementation Routine
for ((i=0; i<${#SORTED_KEYS[@]}; i++)); do
    for ((j=i+1; j<${#SORTED_KEYS[@]}; j++)); do
        key1="${SORTED_KEYS[i]}"
        key2="${SORTED_KEYS[j]}"
        swap=false

        # Rule A: Primary Directory Grouping Priority Check (-d option)
        if [ "$DIRS_FIRST" = true ]; then
            if [ "${FILE_IS_DIR[$key1]}" = false ] && [ "${FILE_IS_DIR[$key2]}" = true ]; then
                swap=true
            elif [ "${FILE_IS_DIR[$key1]}" = true ] && [ "${FILE_IS_DIR[$key2]}" = false ]; then
                swap=false
            else
                sub_sort=true
            fi
        else
            sub_sort=true
        fi

        if [ "$sub_sort" = true ]; then
            case $SORT_BY in
                name)
                    if [[ "${key1,,}" > "${key2,,}" ]]; then swap=true; fi
                    ;;
                size)
                    if (( $(awk "BEGIN {print (${FILE_SIZES_RAW[$key1]} > ${FILE_SIZES_RAW[$key2]}) ? 1 : 0}") )); then swap=true; fi
                    ;;
                type)
                    if [[ "${FILE_TYPES[$key1],,}" > "${FILE_TYPES[$key2],,}" ]]; then swap=true; fi
                    ;;
            esac
            
            if [ "$REVERSE" = true ]; then
                if [ "$swap" = true ]; then swap=false; else swap=true; fi
            fi
        fi

        if [ "$swap" = true ]; then
            tmp="${SORTED_KEYS[i]}"
            SORTED_KEYS[i]="${SORTED_KEYS[j]}"
            SORTED_KEYS[j]="$tmp"
        fi
    done
done

# Render Formatting Outputs
printf "Listing files for ${DIR}...\n\n"

generate_border_line() {
    printf "%s" "$1"
    printf "%.s─" $(seq 1 $((MAX_NAME_LEN + 2)))
    printf "%s" "$2"
    printf "%.s─" $(seq 1 $((MAX_SIZE_LEN + 2)))
    printf "%s" "$2"
    printf "%.s─" $(seq 1 $((MAX_TYPE_LEN + 2)))
    printf "%s\n" "$3"
}

generate_border_line "╭" "┬" "╮"
printf "│ %-${MAX_NAME_LEN}s │ %-${MAX_SIZE_LEN}s │ %-${MAX_TYPE_LEN}s │\n" "File Name" "Size" "Type"
generate_border_line "├" "┼" "┤"

for file in "${SORTED_KEYS[@]}"; do
    [[ -z "$file" ]] && continue
    FULL_PATH="$DIR/$file"
    
    IS_SYMLINK=${FILE_IS_SYMLINK["$file"]:-false}
    IS_DIR=${FILE_IS_DIR["$file"]:-false}
    
    IS_DOTFILE=false
    [[ "$file" == .* ]] && IS_DOTFILE=true

    IS_EXE=false
    if [ -x "$FULL_PATH" ] && [ "$IS_DIR" = false ] && [ "$IS_SYMLINK" = false ]; then
        IS_EXE=true
    fi

    # Name String Prep
    if [ "$IS_SYMLINK" = true ]; then
        TARGET_LEN=$((MAX_NAME_LEN - 1))
        display_name="$file*"
        [ ${#file} -gt $TARGET_LEN ] && display_name="${file:0:$((TARGET_LEN - 3))}...*"
    else
        display_name="$file"
        [ ${#file} -gt $MAX_NAME_LEN ] && display_name="${file:0:$((MAX_NAME_LEN - 3))}..."
    fi

    file_size=${FILE_SIZES_HUMAN["$file"]:-"-"}
    file_type=${FILE_TYPES["$file"]:-"Unknown"}
    [ ${#file_type} -gt $MAX_TYPE_LEN ] && file_type="${file_type:0:$((MAX_TYPE_LEN - 3))}..."

    padded_name=$(printf "%-${MAX_NAME_LEN}s" "$display_name")
    trimmed_name="${padded_name%"${padded_name##*[![:space:]]}"}"
    spaces="${padded_name#"$trimmed_name"}"

    # Row Printing Engine
    if [ "$IS_SYMLINK" = true ]; then
        text_part="${display_name%\*}"
        needed_spaces=$(( MAX_NAME_LEN - ${#display_name} ))
        extra_spaces=$(printf "%${needed_spaces}s" "")
        
        if [ -d "$FULL_PATH" ]; then
            if [ "$IS_DOTFILE" = true ]; then
                final_name="\e[1;3;34m${text_part}\e[0m\e[32m*\e[0m${extra_spaces}"
            else
                final_name="\e[1;34m${text_part}\e[0m\e[32m*\e[0m${extra_spaces}"
            fi
        else
            if [ "$IS_DOTFILE" = true ]; then
                final_name="\e[3;90m${text_part}\e[0m\e[32m*\e[0m${extra_spaces}"
            else
                final_name="${text_part}\e[32m*\e[0m${extra_spaces}"
            fi
        fi
        printf "│ %b │ %-${MAX_SIZE_LEN}s │ %-${MAX_TYPE_LEN}s │\n" "$final_name" "$file_size" "$file_type"

    elif [ "$IS_DIR" = true ]; then
        final_name="\e[1;34m${trimmed_name}\e[0m${spaces}"
        [ "$IS_DOTFILE" = true ] && final_name="\e[1;3;34m${trimmed_name}\e[0m${spaces}"
        printf "│ %b │ %-${MAX_SIZE_LEN}s │ %-${MAX_TYPE_LEN}s │\n" "$final_name" "$file_size" "$file_type"

    elif [ "$IS_EXE" = true ]; then
        final_name="\e[32m${trimmed_name}\e[0m${spaces}"
        [ "$IS_DOTFILE" = true ] && final_name="\e[3;32m${trimmed_name}\e[0m${spaces}"
        printf "│ %b │ %-${MAX_SIZE_LEN}s │ %-${MAX_TYPE_LEN}s │\n" "$final_name" "$file_size" "$file_type"

    elif [ "$IS_DOTFILE" = true ]; then
        final_name="\e[3;90m${trimmed_name}\e[0m${spaces}"
        printf "│ %b │ %-${MAX_SIZE_LEN}s │ %-${MAX_TYPE_LEN}s │\n" "$final_name" "$file_size" "$file_type"
        
    else
        printf "│ %-${MAX_NAME_LEN}s │ %-${MAX_SIZE_LEN}s │ %-${MAX_TYPE_LEN}s │\n" "$display_name" "$file_size" "$file_type"
    fi
done

generate_border_line "╰" "┴" "╯"

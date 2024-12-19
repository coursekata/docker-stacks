#!/bin/bash

# Default Python version from environment variable
PYTHON_VERSION=${PYTHON_VERSION:-}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --python-version) PYTHON_VERSION="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if PYTHON_VERSION is set
if [ -z "$PYTHON_VERSION" ]; then
    echo "Python version not specified. Set PYTHON_VERSION environment variable or use --python-version option."
    exit 1
fi

# Fetch constraints from the URL and store a copy in the same directory as this script
constraints_file="$(dirname "$0")/constraints-${PYTHON_VERSION}.txt"
constraints_url="https://tk.deepnote.com/constraints/${PYTHON_VERSION}.txt"
curl -L "$constraints_url" -o "$constraints_file"
constraints=$(cat "$constraints_file")

# Replace specific version constraints for parso
constraints=$(echo "$constraints" | sed 's/parso<[^,]*,>=0.7.0/parso>=0.7.0/')

# Format the constraints for pixi
formatted_constraints=$(echo "$constraints" | xargs -I {} echo '"{}"' | tr '\n' ' ')

# Add the formatted constraints using pixi
xargs pixi add -f deepnote -p linux-64 --pypi <<< "$formatted_constraints"

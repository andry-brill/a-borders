#!/bin/bash

output_file="combined.dart"

# Empty the output file if it exists, or create it if it doesn't
> "$output_file"

# Loop through all .dart files
for file in *.dart; do
    # Skip the output file itself so we don't loop infinitely
    if [[ "$file" == "$output_file" ]]; then
        continue
    fi

    echo "Processing $file..."

    # Add the filename as a comment
    echo "// --- File: $file ---" >> "$output_file"
    
    # Append the file content
    cat "$file" >> "$output_file"
    
    # Add two newlines for spacing
    echo -e "\n\n" >> "$output_file"
done

echo "Done! Merged into $output_file"
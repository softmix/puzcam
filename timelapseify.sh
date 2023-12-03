#!/bin/bash

# Constants
desired_file_size_mb=1.8
kilobits_per_mb=8192
initial_bitrate_kbps=250  # Starting bitrate, adjust as needed

# Check if there are any subdirectories
if [ -z "$(ls -d */)" ]; then
    echo "No subdirectories found. Exiting."
    exit 1
fi

# Desired duration is 60 seconds (1 minute)
desired_duration=60

# Loop through each subdirectory
for dir in */; do
    # Change into the directory
    cd "$dir"

    # Check if there are any chunk files in this directory
    if ls chunk_*.webm 1> /dev/null 2>&1; then
        echo "Processing in directory: $dir"

        # Concatenate chunks
        temp_output_file="temp_merged_output.webm"
        final_output_file="merged_output.webm"
        > "$temp_output_file"

        for chunk in $(ls chunk_*.webm | sort -V); do
            cat "$chunk" >> "$temp_output_file"
        done

        # Repackage the video file
        ffmpeg -y -loglevel warning -i "$temp_output_file" -c:v copy -c:a copy "$final_output_file"

        # Calculate total duration of the video in seconds
        total_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$final_output_file")
        
        # Check if total_duration is a valid number
        if ! [[ $total_duration =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo "Invalid total duration for $dir. Skipping."
            cd ..
            continue
        fi

        total_duration=$(printf "%.0f" "$total_duration")  # Convert to integer

        # Calculate speed-up factor
        factor=$(echo "$total_duration / $desired_duration" | bc -l)
        factor=$(printf "%.2f" "$factor")  # Format to 2 decimal places

        # Ensure factor is greater than zero
        if (( $(echo "$factor <= 0" | bc -l) )); then
            echo "Invalid factor calculated for $dir. Skipping."
            cd ..
            continue
        fi

        echo "Factor calculated: $factor"
        echo "Total duration: $total_duration seconds"
        echo "Desired duration: $desired_duration seconds"
        echo "Initial bitrate: ${initial_bitrate_kbps}kbps"
        echo "Desired file size: ${desired_file_size_mb}MB"

        # Detect crop parameters using Python script
        python3 ../crop_detector.py "$final_output_file"
        read -r x y w h < crop_params.txt

        # Go back to the parent directory
        cd ..

        # Adjust bitrate based on the output file size
        for (( i=0; i<5; i++ )); do
            final_output="${dir%/}.webm"

            echo "Iteration $i: Bitrate = ${initial_bitrate_kbps}kbps"

            # Two-pass encoding with current bitrate
            ffmpeg -y -loglevel warning -i "$dir$final_output_file" -vf "setpts=PTS/$factor,crop=${w}:${h}:${x}:${y}" -c:v libvpx-vp9 -b:v ${initial_bitrate_kbps}k -pass 1 -vsync vfr -an -f webm /dev/null && \
            ffmpeg -y -loglevel warning -i "$dir$final_output_file" -vf "setpts=PTS/$factor,crop=${w}:${h}:${x}:${y}" -c:v libvpx-vp9 -b:v ${initial_bitrate_kbps}k -pass 2 -vsync vfr -an "$final_output"

            # Check file size
            actual_size_kb=$(du -k "$final_output" | cut -f1)
            actual_size_mb=$(echo "scale=2; $actual_size_kb/1024" | bc)

            echo "Iteration $i: File size = ${actual_size_mb}MB with bitrate = ${initial_bitrate_kbps}kbps"

            # Calculate the ratio of actual size to desired size
            size_ratio=$(echo "scale=2; $actual_size_mb / $desired_file_size_mb" | bc)

            # Adjust bitrate proportionally
            initial_bitrate_kbps=$(echo "scale=2; $initial_bitrate_kbps / $size_ratio" | bc)
            initial_bitrate_kbps=${initial_bitrate_kbps%.*}  # Convert to integer

            # Add a check to prevent extreme bitrate adjustments
            if [ $initial_bitrate_kbps -le 100 ]; then
                initial_bitrate_kbps=100
            elif [ $initial_bitrate_kbps -ge 5000 ]; then
                initial_bitrate_kbps=5000
            fi

            # Check if the size is within an acceptable range (e.g., +/- 5%)
            if (( $(echo "$actual_size_mb >= (0.95 * $desired_file_size_mb)" | bc -l) )) && (( $(echo "$actual_size_mb <= (1.05 * $desired_file_size_mb)" | bc -l) )); then
                break
            fi
        done

        echo "Final file size = ${actual_size_mb}MB with bitrate = ${initial_bitrate_kbps}kbps"
        echo "Finished processing in directory: $dir"
    else
        echo "No chunk files in directory: $dir"
        # Go back to the parent directory
        cd ..
    fi
done

echo "All processing complete."

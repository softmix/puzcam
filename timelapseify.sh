#!/bin/bash

# Constants
desired_file_size_mb=1.8
initial_bitrate_kbps=250  # Starting bitrate, usually works well on the first try
desired_duration_sec=60   # Desired video duration in seconds

# Check if a specific subdirectory is given as an argument
if [ $# -eq 1 ]; then
    directories=($1/)
else
    # Check if there are any subdirectories
    if [ -z "$(ls -d */)" ]; then
        echo "No subdirectories found. Exiting."
        exit 1
    fi
    directories=(*/)
fi

# Loop through each specified directory
for dir in "${directories[@]}"; do
    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist. Skipping."
        continue
    fi

    # Change into the directory
    cd "$dir"

    # Check if there are any chunk files in this directory
    if ls chunk_*.webm 1> /dev/null 2>&1; then
        echo "Processing in directory: $dir"

        # Concatenate chunks into a single file
        merged_chunks_file="merged_chunks_output.webm"
        > "$merged_chunks_file"

        for chunk in $(ls chunk_*.webm | sort -V); do
            cat "$chunk" >> "$merged_chunks_file"
        done

        # Repackage the video file with fixed duration
        duration_adjusted_file="duration_adjusted_output.webm"
        ffmpeg -y -loglevel warning -i "$merged_chunks_file" -c:v copy -c:a copy "$duration_adjusted_file"

        # Calculate total duration of the video in seconds
        total_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$duration_adjusted_file")
        total_duration=$(printf "%.0f" "$total_duration")  # Convert to integer

        # Calculate speed-up factor
        factor=$(echo "$total_duration / $desired_duration_sec" | bc -l)
        factor=$(printf "%.2f" "$factor")  # Format to 2 decimal places

        # Ensure factor is greater than zero
        if (( $(echo "$factor <= 0" | bc -l) )); then
            echo "Invalid factor calculated for $dir. Skipping."
            cd ..
            continue
        fi

        echo "Factor calculated: $factor"
        echo "Total duration: $total_duration seconds"


        # Detect crop parameters using Python script
        python3 ../crop_detector.py "$duration_adjusted_file"
        read -r x y w h < crop_params.txt

        # Go back to the parent directory
        cd ..

        # Adjust bitrate based on the output file size
        for (( i=0; i<5; i++ )); do
            final_encoded_file="${dir%/}.webm"

            echo "Iteration $i: Bitrate = ${initial_bitrate_kbps}kbps"

            # Two-pass encoding with current bitrate and scaling
            ffmpeg -y -loglevel warning -i "$dir$duration_adjusted_file" -vf "setpts=PTS/$factor,crop=${w}:${h}:${x}:${y},scale='min(iw,2048)':'min(ih,2048)':force_original_aspect_ratio=decrease" -r 30 -c:v libvpx-vp9 -b:v ${initial_bitrate_kbps}k -pass 1 -vsync vfr -an -f webm /dev/null && \
            ffmpeg -y -i "$dir$duration_adjusted_file" -vf "setpts=PTS/$factor,crop=${w}:${h}:${x}:${y},scale='min(iw,2048)':'min(ih,2048)':force_original_aspect_ratio=decrease" -r 30 -c:v libvpx-vp9 -b:v ${initial_bitrate_kbps}k -pass 2 -vsync vfr -an "$final_encoded_file"

            # Check file size
            actual_size_kb=$(du -k "$final_encoded_file" | cut -f1)
            actual_size_mb=$(echo "scale=2; $actual_size_kb/1024" | bc)

            echo "Iteration $i: File size = ${actual_size_mb}MB with bitrate = ${initial_bitrate_kbps}kbps"

            # Calculate the ratio of actual size to desired size
            size_ratio=$(echo "scale=2; $actual_size_mb / $desired_file_size_mb" | bc)

            # Adjust bitrate proportionally
            initial_bitrate_kbps=$(echo "scale=2; $initial_bitrate_kbps / $size_ratio" | bc)
            initial_bitrate_kbps=${initial_bitrate_kbps%.*}  # Convert to integer

            # Limit bitrate to prevent extreme adjustments
            if [ $initial_bitrate_kbps -le 100 ]; then
                initial_bitrate_kbps=100
            elif [ $initial_bitrate_kbps -ge 5000 ]; then
                initial_bitrate_kbps=5000
            fi

            # Check if the size is within an acceptable range
            if (( $(echo "$actual_size_mb >= (0.95 * $desired_file_size_mb)" | bc -l) )) && (( $(echo "$actual_size_mb <= (1.05 * $desired_file_size_mb)" | bc -l) )); then
                break
            fi
        done

        echo "Final file size = ${actual_size_mb}MB with bitrate = ${initial_bitrate_kbps}kbps"
        echo "Finished processing in directory: $dir"
    else
        echo "No chunk files in directory: $dir"
        cd ..
    fi
done

echo "All processing complete."

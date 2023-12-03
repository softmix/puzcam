import cv2
import numpy as np
import subprocess
import sys

def extract_frame(video_path, frame_path='frame.jpg', time='00:00:05'):
    """
    Extracts a frame from the video.
    """
    command = f"ffmpeg -y -loglevel warning -i {video_path} -ss {time} -vframes 1 {frame_path}"
    subprocess.run(command, shell=True)

def find_content_boundaries(frame_path, letterbox_color=(24, 24, 24)):
    """
    Finds the boundaries of the content in the frame.
    """
    # Load the image
    image = cv2.imread(frame_path)

    # Calculate the difference of each pixel from the letterbox color
    diff = np.abs(image - np.array(letterbox_color)).sum(axis=2)

    # Threshold to identify pixels significantly different from the letterbox
    thresh = diff > 30  # Adjust this value as needed

    # Find the content boundaries
    rows = np.any(thresh, axis=1)
    cols = np.any(thresh, axis=0)
    y, h = np.where(rows)[0][[0, -1]]
    x, w = np.where(cols)[0][[0, -1]]

    return x, y, w - x, h - y

def main():
    video_path = sys.argv[1]  # Get video path from command line argument
    frame_path = 'extracted_frame.jpg'

    # Extract a frame from the video
    extract_frame(video_path, frame_path)

    # Find content boundaries
    x, y, w, h = find_content_boundaries(frame_path)

    # Write the crop parameters to a file
    with open('crop_params.txt', 'w') as f:
        f.write(f"{x} {y} {w} {h}\n")

if __name__ == "__main__":
    main()

import cv2
import os
from pathlib import Path

def resize_videos(input_dir, output_dir):
    # Create output directory if it doesn't exist
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    
    # Supported video file extensions
    video_extensions = ('.mp4', '.avi', '.mov', '.mkv', '.flv', '.wmv')
    
    # Process each file in the input directory
    for filename in os.listdir(input_dir):
        if filename.lower().endswith(video_extensions):
            input_path = os.path.join(input_dir, filename)
            output_path = os.path.join(output_dir, filename)
            
            # Open the video file
            cap = cv2.VideoCapture(input_path)
            
            # Get video properties
            fps = cap.get(cv2.CAP_PROP_FPS)
            frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            original_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            original_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            
            # Verify original resolution is 1440x1080
            if original_width != 1440 or original_height != 1080:
                print(f"Warning: {filename} has resolution {original_width}x{original_height} (expected 1440x1080). Skipping.")
                cap.release()
                continue
            
            # Define the output resolution
            new_width, new_height = 720, 540
            
            # Set up the video writer
            fourcc = cv2.VideoWriter_fourcc(*'mp4v')  # or use other codecs like 'XVID'
            out = cv2.VideoWriter(output_path, fourcc, fps, (new_width, new_height))
            
            # Process each frame
            for _ in range(frame_count):
                ret, frame = cap.read()
                if not ret:
                    break
                
                # Resize the frame
                resized_frame = cv2.resize(frame, (new_width, new_height), interpolation=cv2.INTER_AREA)
                
                # Write the resized frame
                out.write(resized_frame)
            
            # Release resources
            cap.release()
            out.release()
            print(f"Processed: {filename}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Resize videos from 1440x1080 to 720x540')
    parser.add_argument('input_dir', help='Input directory containing videos')
    parser.add_argument('output_dir', help='Output directory for resized videos')
    
    args = parser.parse_args()
    
    resize_videos(args.input_dir, args.output_dir)
    print("Video resizing complete!")

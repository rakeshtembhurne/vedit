#!/bin/bash

# Check if input file is provided
if [ -z "$1" ]; then
	echo "Usage: $0 <input_file>"
	exit 1
fi

input_file="$1"
input_file_ext="${input_file##*.}"
clip_prefix="clip"
duration=15
fade_duration=0
combined_output="deadpool_final.${input_file_ext}"

# Ensure the output directory exists
mkdir -p output_clips

# Step 1: Split the video into 15-second clips
echo ""
echo "Splitting video into 15-second clips..."
ffmpeg -loglevel quiet -stats -hide_banner -stats -i "$input_file" -c:v copy -c:a copy -f segment -segment_time $duration -reset_timestamps 1 "output_clips/${clip_prefix}%03d.${input_file_ext}" 2>&1 | tee split_log.txt

# Check created clips
echo ""
echo "Checking created clips..."
ls -lh output_clips/

# Create file list for concatenation
echo ""
echo "Creating file list for concatenation..."
>filelist.txt # Ensure filelist.txt is empty before starting

# Apply fading effects to each clip
for file in output_clips/${clip_prefix}*.${input_file_ext}; do
	echo ""
	echo "Processing $file..."

	clip_num=$(basename "$file" | grep -o '[0-9]\+')
	faded_file="${file/\.${input_file_ext}/_faded.${input_file_ext}}"
	diff=$(expr "$duration - $fade_duration" | bc)

	# Apply fade in and fade out to each clip
	# ffmpeg -i "$file" -vf "fade=t=in:st=0:d=$fade_duration, fade=t=out:st=$diff:d=$fade_duration" -c:a copy "$faded_file"
	# ffmpeg -y -i "$file" -vf "hflip, scale=iw*1.2:ih*1.2, chromakey=0x00FF00:0.1:0.2, fade=t=in:st=0:d=$fade_duration, fade=t=out:st=$diff:d=$fade_duration" -af "asetrate=44100*0.8,aresample=44100,atempo=1.25" "$faded_file"
	ffmpeg -loglevel quiet -stats -y -i "$file" -vf "hflip, scale=iw*1.2:ih*1.2, chromakey=0x00FF00:0.1:0.2, fade=t=in:st=0:d=$fade_duration, fade=t=out:st=$diff:d=$fade_duration, eq=saturation=1.2:contrast=1.2:brightness=0.1" -af "asetrate=44100*0.9,aresample=44100,atempo=1.2" -c:v h264_videotoolbox "$faded_file"
	# ffplay -vf "hflip, scale=iw*1.2:ih*1.2, chromakey=0x00FF00:0.1:0.2, fade=t=in:st=0:d=$fade_duration, fade=t=out:st=$diff:d=$fade_duration, eq=saturation=1.5:contrast=1.2:brightness=0.1" -af "asetrate=44100*1.1,aresample=44100,atempo=1.1" "$faded_file"

done

# Create file list for concatenation
for faded_file in output_clips/${clip_prefix}*_faded.${input_file_ext}; do
	echo ""
	echo "file '${faded_file}'" >>filelist.txt
done

# Verify that filelist.txt was created
echo ""
echo "Verifying filelist.txt..."
if [ -s filelist.txt ]; then
	echo "filelist.txt created successfully."
else
	echo "filelist.txt is empty or was not created. Please check the script."
	exit 1
fi

# Step 2: Concatenate clips without additional fading
echo "Concatenating clips with effects..."
ffmpeg -f concat -safe 0 -i filelist.txt -c copy "$combined_output"

echo "Combining process completed. Output file: $combined_output"

#!/bin/bash

# Function to check input file
check_input_file() {
	if [ -z "$1" ]; then
		echo "Usage: $0 <input_file>"
		exit 1
	fi
}

# Function to split video into clips
split_video() {
	echo "Splitting video into 15-second clips..."
	ffmpeg -loglevel quiet -stats -hide_banner -stats -i "$1" -c:v copy -c:a copy -f segment -segment_time $duration -reset_timestamps 1 "output_clips/${clip_prefix}%03d.${input_file_ext}" 2>&1 | tee split_log.txt
}

# Function to apply fading effects to each clip
apply_fading_effects() {
	for file in output_clips/${clip_prefix}*.${input_file_ext}; do
		echo "Processing $file..."
		clip_num=$(basename "$file" | grep -o '[0-9]\+')
		faded_file="${file/\.${input_file_ext}/_faded.${input_file_ext}}"
		diff=$(expr "$duration - $fade_duration" | bc)

		ffmpeg -loglevel quiet -stats -y -i "$file" -vf "hflip, scale=iw*1.2:ih*1.2, chromakey=0x00FF00:0.1:0.2, fade=t=in:st=0:d=$fade_duration, fade=t=out:st=$diff:d=$fade_duration, eq=saturation=1.2:contrast=1.2:brightness=0.1" -af "asetrate=44100*0.9,aresample=44100,atempo=1.2" -c:v h264_videotoolbox "$faded_file"
	done
}

# Function to create file list for concatenation
create_file_list() {
	>filelist.txt
	for faded_file in output_clips/${clip_prefix}*_faded.${input_file_ext}; do
		echo "file '${faded_file}'" >>filelist.txt
	done
}

# Function to concatenate clips
concatenate_clips() {
	echo "Concatenating clips with effects..."
	ffmpeg -f concat -safe 0 -i filelist.txt -c copy "$combined_output"
}

# Main script
check_input_file "$1"
input_file="$1"
input_file_ext="${input_file##*.}"
clip_prefix="clip"
duration=15
fade_duration=0
combined_output="deadpool_final.${input_file_ext}"

mkdir -p output_clips
split_video "$input_file"
apply_fading_effects
create_file_list
concatenate_clips

echo "Combining process completed. Output file: $combined_output"

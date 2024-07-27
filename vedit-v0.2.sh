#!/bin/bash

# Function to check input file
check_input_file() {
	if [ -z "$1" ]; then
		echo "Usage: $0 <command> [options]"
		exit 1
	fi
}

reset_all() {
	echo "Resetting and deleting all files and folders..."
	rm -rf "$(pwd)/output_clips"
	rm -f filelist.txt
	rm -f split_log.txt
	echo "Reset completed."
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

		ffmpeg -loglevel quiet -stats -y -i "$file" -vf "hflip, scale=iw*1.2:ih*1.2, chromakey=0x00FF00:0.1:0.2, fade=t=in:st=0:d=$fade_duration, fade=t=out:st=$diff:d=$fade_duration, eq=saturation=1.2:contrast=1.2:brightness=0.1" -af "asetrate=44100*0.99,atempo=0.99,volume=0.99" -c:v h264_videotoolbox "$faded_file"
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
	ffmpeg -f concat -safe 0 -i filelist.txt -shortest -c copy "$combined_output"
}

# Function to download youtube video
download_youtube_video() {
	echo "FIRST ${1}"
	echo "SECOND ${2}"
	yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" -o "$2" "$1"
}

rename_files() {
	for file in *; do
		if [ -f "$file" ]; then
			case "$file" in
			*.mp4 | *.avi | *.mkv | *.mov | *.flv | *.wmv)
				name="${file%.*}"
				ext="${file##*.}"
				new_name=$(echo "$name" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]' | tr -s '_' | sed 's/^_//')
				mv "$file" "${new_name}.${ext}"
				;;
			esac
		fi
	done
}

rewrite_all() {
	rename_files
	for file in *.mp4 *.avi *.mkv *.mov *.flv *.wmv; do
		input_name="$file"
		output_name="${file%.*}_final.mp4"
		vedit rewrite "$input_name" "$output_name"
	done
}

# Main script
check_input_file "$1"

case "$1" in
rewrite)
	input_file="$2"
	combined_output="$3"
	input_file_ext="${input_file##*.}"
	clip_prefix="clip"
	duration=15
	fade_duration=0.1

	reset_all
	rename_files

	# Create output directory in the current working directory
	mkdir -p "$(pwd)/output_clips"

	split_video "$input_file"
	apply_fading_effects
	create_file_list
	concatenate_clips

	echo "Combining process completed. Output file: $combined_output"
	;;
rewrite_all)
	rewrite_all
	;;
test)
	rename_files
	;;
download)
	if [ -z "$3" ]; then
		echo "Error: Filename is required for download command"
		exit 1
	fi
	download_youtube_video "$2" "$3"
	;;
*)
	echo "Invalid command. Available commands: rewrite, download, test"
	exit 1
	;;
esac

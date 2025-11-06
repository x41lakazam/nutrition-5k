#!/bin/bash

# Check if user provided sampling step
if [ -z "$1" ]; then
  echo "Usage: $0 <frame_step>"
  exit 1
fi

frame_step="$1"
max_jobs=$(nproc)   # number of parallel jobs = CPU cores

# Create central output directory
main_outdir="./frames_sampled${frame_step}"
mkdir -p "$main_outdir"

# Find dish directories (exclude frames_sampled folders)
dirs=($(find . -mindepth 1 -maxdepth 1 -type d ! -name "frames_sampled*"))
total_dishes=${#dirs[@]}®
current=0

# Function to process a dish
process_dish() {
  dir="$1"
  dishname=$(basename "$dir")
  outdir="${main_outdir}/${dishname}"
  mkdir -p "$outdir"

  for camera in {A..D}; do
    infile="${dir}/camera_${camera}.h264"
    outfile="${outdir}/camera_${camera}frame%03d.jpeg"

    if [ -f "$infile" ]; then
      ffmpeg -hide_banner -loglevel error -i "$infile" \
        -vf "select=not(mod(n\,${frame_step}))" \
        -fps_mode vfr "$outfile"
    fi
  done
}

export -f process_dish
export frame_step main_outdir

for dir in "${dirs[@]}"; do
  ((current++))
  percent=$(( current * 100 / total_dishes ))
  echo -ne "Queued $dir ($current/$total_dishes) [$percent%]\r"

  process_dish "$dir" &

  # Limit number of background jobs
  while [ "$(jobs -rp | wc -l)" -ge "$max_jobs" ]; do
    sleep 1
  done
done

wait
echo -e "\nDone. Frames extracted to $main_outdir"


#!/bin/bash
maxattempts=5

function create_list_to_be_downloaded() {
  filename="$1"
  list=$(curl -s https://dumps.wikimedia.org/backup-index.html | cat | grep -v "(private data)" | grep "span class='done'" | sed -r 's/.*<a href="([^\/]+)\/([^"]+)">(.*)<\/a>.*/\1 \2/g' | tac)
  echo "$list" | while read wiki date; do
    echo "Fetching files to download for $wiki $date"
    dlpage=$(curl -s https://dumps.wikimedia.org/$wiki/$date/ | grep "$wiki-$date-pages-meta-history.*\.7z" | sed -r 's/.*<a href="([^"]+)">([^<]+)<\/a>.*/\2 https:\/\/dumps.wikimedia.org\1/g')
    echo "$dlpage" | while read file url; do
      echo "$wiki $date $file $url" >> "$filename"
    done
  done
}

function remove_file_if_invalid() {
  local file="$1"
  local wiki="$2"
  local date="$3"

  if [ -f "$file" ]; then
    actual_sha1sum=$(sha1sum "$file") &
    expected_sha1sum=$(curl -s "https://dumps.wikimedia.org/$wiki/$date/$wiki-$date-sha1sums.txt" | grep "$file") &
    wait
    if [[ "$actual_sha1sum" = "$expected_sha1sum" ]]; then
      echo "Validating $file: ok"
    else
      rm "$file"
      echo "Validating $file: NOK"
    fi
  fi
}

function download_from_list() {
  filename="$1"
  while read wiki date file url; do
    remove_file_if_invalid "$file" "$wiki" "$date"

    if [ ! -f "$file" ]; then
      for i in $(seq 1 $maxattempts); do
        echo ""
        echo "${file}"
        curl $url -o $file

        if [[ $(remove_file_if_invalid "$file" "$wiki" "$date" | awk '{print $NF}') = "ok" ]]; then
          break
        else
          echo "Attempt $i/$maxattempts: Failed to download $file"
        fi
      done
    fi
  done < "$filename"
}

dl_file="to_download.txt"
create_list_to_be_downloaded "$dl_file"
download_from_list "$dl_file"

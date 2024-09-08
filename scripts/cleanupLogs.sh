#!/usr/bin/env bash
#
# EchoVR GameServer Log Organization Script
#
# This script will recursively search for logs within the "./old" folder and move them to "./archive".
# The "./archive" folder is organized by year and year-month folders, parsed from the filenames.
# The logs will also be renamed to include some additional information with easier formatting.


# CONSTANTS
search_dir="/ready-at-dawn-echo-arena/logs/old"
new_dir_root="/ready-at-dawn-echo-arena/logs/"
archive_dir=archive
old_dir_name=old

# Loop "old" directories
for old_dir in $(find ${search_dir} -type d | grep "${old_dir_name}" | grep -v "${archive_dir}" | sort -r); do

    # Get container from parent directory
    #   Example: "./old/12345
    container_id="$(basename "${old_dir}")"
    if [[ "${container_id}" == "${old_dir_name}" ]]; then
            # Example: "./12345/old"
        container_id="$(basename "$(dirname "${old_dir}")")"
    fi

    # Loop "*.log" files from "old" directory
    for old_filename in $(ls -1 "${old_dir}" | grep '\.log$'); do
        old_path=${old_dir}/${old_filename}

        # Parse log filename
        #   Example: "[r14(server)]-[10-31-2023]_[23-59-59]_123.log"
        log_ver=${old_filename:1:3}
        log_mode=${old_filename:5:6}
        year=${old_filename:21:4}
        month=${old_filename:15:2}
        day=${old_filename:18:2}
        hour=${old_filename:28:2}
        minute=${old_filename:31:2}
        second=${old_filename:34:2}
        file_basename=${old_filename%%.log}
        process_id=${file_basename##*_}

        # Parse file for ip and port
        #   Example: [10-31-2024] [23:59:59]: Dedicated: registered as 0x0123456789ABCDEF at [192.168.0.2/1.1.1.1:1234]
        ip_address="0.0.0.0"
        port="0000"
        registered_line="$(grep -m1 ' Dedicated: registered as ' ${old_path})"

        if [[ ! "$registered_line" == "" ]]; then
            line_tail="${registered_line##*/}"
            connection="${line_tail%%]*}"
            ip_address="${connection%%:*}"
            port="${connection##*:}"
        fi  

        # Build new filename
        #   Example: 2023-10-31_23-59-59_r14_server_12345_123__1.1.1.1_1234.log
        new_filename="${year}-${month}-${day}_${hour}-${minute}-${second}_${log_ver}_${log_mode}_${container_id}_${process_id}__${ip_address}_${port}.log"

        # Move file
        new_dir=${new_dir_root}/${archive_dir}/${year}/${year}-${month}
        new_path=${new_dir}/${new_filename}
        echo "$old_filename: $old_path --> $new_path"
        mkdir -p "${new_dir}"
        mv -n "${old_path}" "${new_path}"
    done
done

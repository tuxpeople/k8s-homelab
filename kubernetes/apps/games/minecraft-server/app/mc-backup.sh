#!//usr/bin/bash
# based on https://github.com/mikenye/docker-minecraft_bedrock_server/blob/main/rootfs/usr/local/bin/run_backup

# bonus features on
shopt -s extglob

SERVER_TYPE="bedrock_server"
BACKUP_DIR="/backup/minecraft_backup"
DATA_DIR="/data"
SERVER_PID=$(echo `grep -l ${SERVER_TYPE} /proc/+([0-9])/cmdline` | cut -d'/' -f3)

readconsole(){
    cat /proc/${SERVER_PID}/fd/1 > /tmp/console
}

# Started
echo "======= BACKUP OPERATION BEGIN ======="

# Start it in the background
readconsole &

# Save readconsole() PID, to kill the function later
MYSELF=$!

# Start backup with performing a save resume in case of failed backup
echo save resume > /proc/${SERVER_PID}/fd/0

sleep 5

# Trigger a backup
echo "Placing server into 'save hold'..."
echo save hold > /proc/${SERVER_PID}/fd/0

# Wait for backup to be ready
EXITCODE=1
while [ "$EXITCODE" -ne "0" ]; do
    echo save query > /proc/${SERVER_PID}/fd/0
    grep "Data saved. Files are now ready to be copied." /tmp/console > /dev/null 2>&1
    EXITCODE=$?
    sleep 2
done

echo "Server is now in 'save hold', performing backup..."

sleep 2

# Kill progress
kill $MYSELF >/dev/null 2>&1

# Get files needed for backup
FILES_TO_BACKUP=$(grep -a -A 1 "Data saved. Files are now ready to be copied." /tmp/console | tail -1 | cut -d "]" -f 2- | sed 's/^ *//g')

# Get current date/time of backup
BACKUP_DATETIME=$(date +%Y-%m-%d-%H%M.%S.%N)

# Set inter-field separator
IFS=','

# Prepare array
read -ra BKUP <<< "$FILES_TO_BACKUP"

# Loop through files to back up
for i in "${BKUP[@]}"; do

    i=$(echo "$i" | sed 's/^ *//g' | sed 's/\r//g')

    # For each entry given, get the path, file and offset
    WORLD_DIR=$(echo "$i" | cut -d '/' -f 1)
    WORLD_FILE=$(basename "$(echo "$i" | cut -d ':' -f 1)")
    WORLD_FILE_OFFSET=$(echo "$i" | cut -d ':' -f 2)

    # Create backup directory
    BACKUP_DESTINATION="${BACKUP_DIR}/${WORLD_DIR}/${BACKUP_DATETIME}"
    mkdir -p "${BACKUP_DESTINATION}"

    # Copy specified backup files into backup dir & truncate files to specified offset
    cd "${DATA_DIR}/worlds/${WORLD_DIR}" || exit 1
    find . \
        -type f \
        -name "${WORLD_FILE}" \
        -print0 | while read -r -d $'\0' file
    do
        # shellcheck disable=SC2001
        file=$(echo "${file}" | sed "s|^\./||")
        mkdir -p "$(dirname "${BACKUP_DESTINATION}/${file}")"
        cp "./${file}" "${BACKUP_DESTINATION}/${file}"
        truncate -s "$WORLD_FILE_OFFSET" "${BACKUP_DESTINATION}/${file}"
    done

    # Also copy settings, whitelist and permissions for this point in time
    cp "${DATA_DIR}/server.properties" "${BACKUP_DESTINATION}/server.properties"
    cp "${DATA_DIR}/whitelist.json" "${BACKUP_DESTINATION}/whitelist.json"
    cp "${DATA_DIR}/permissions.json" "${BACKUP_DESTINATION}/permissions.json"

done

# Release system from backup
echo "Releasing server from 'save hold'..."
echo save resume > /proc/${SERVER_PID}/fd/0

# Compress backup
echo "Compressing backup..."
cd "${BACKUP_DIR}/${WORLD_DIR}" || exit 1
# shellcheck disable=SC2016
tar czvf "${BACKUP_DATETIME}.tar.gz" "${BACKUP_DATETIME}"  | stdbuf -o0 awk '{print "  + " $0}'

# Clean up files now they're compressed
echo "Removing temporary files..."
rm -r "${BACKUP_DIR}/${WORLD_DIR}/${BACKUP_DATETIME}"

# Show backup file info
stat --format="Created backup file: '%n', size: %s bytes" "${BACKUP_DIR}/${WORLD_DIR}/${BACKUP_DATETIME}.tar.gz"

# Finished
echo "======= BACKUP OPERATION FINISHED ======="
echo ""

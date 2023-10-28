#!//usr/bin/bash
# based on https://github.com/mikenye/docker-minecraft_bedrock_server/blob/main/rootfs/usr/local/bin/run_backup
set -x
# bonus features on
shopt -s extglob

SERVER_TYPE="bedrock_server"
BACKUP_FOLDER="/backup/minecraft_backup"
DATA_DIR="/data"
SERVER_PID=$(echo `grep -l ${SERVER_TYPE} /proc/+([0-9])/cmdline` | cut -d'/' -f3)
BACKUP_DATETIME=$(date +%Y%m%d-%H%M%S)

BACKUP_DIR="${BACKUP_FOLDER}/${BACKUP_NAME:-$(hostname)}"

# checks
[ -z "${SERVER_PID}" ] && exit 1
[ -z "${BACKUP_DIR}" ] && exit 1

# create temporary file
TMPFILE=$(mktemp /tmp/mc-backup.XXXXXX)

readconsole(){
    # Write the stdout of the pocess into the temporary file
    cat /proc/${SERVER_PID}/fd/1 > ${TMPFILE}

    # Delete the temporary file. The content will stay available until the cat gets terminated
    rm ${TMPFILE}
}

# Ready, steady, go!
echo "Starting with the backup"

# Start the background process to listen to the stdout of the server
readconsole &

# Save readconsole() PID, to kill the function later
RC_PID=$!

# Start backup with performing a save resume in case of previously failed backup
echo save resume > /proc/${SERVER_PID}/fd/0

# Little break, just in case
sleep 5

# Trigger a backup by writing save hold into server's stdin
echo "Placing server into 'save hold'..."
echo save hold > /proc/${SERVER_PID}/fd/0

# Continously wait for backup to be ready using save query every 2 seconds and read the console's reaction
EXITCODE=1
while [ "${EXITCODE}" -ne "0" ]; do
    echo save query > /proc/${SERVER_PID}/fd/0
    grep "Data saved. Files are now ready to be copied." ${TMPFILE} > /dev/null 2>&1
    EXITCODE=$?
    sleep 2
done

echo "Server is now in 'save hold', performing backup..."

# Little break, just in case
sleep 2

# Get files needed for backup
FILES_TO_BACKUP=$(grep -a -A 1 "Data saved. Files are now ready to be copied." ${TMPFILE} | tail -1 | cut -d "]" -f 2- | sed 's/^ *//g')

# Kill background process to listen to the stdout of the server, as we do not longer need it
kill $RC_PID >/dev/null 2>&1

# Set inter-field separator
IFS=','

# Prepare array
read -ra BACKUP_LIST <<< "$FILES_TO_BACKUP"

# checks
[ -z "${BACKUP_LIST}" ] && exit 1

# Loop through the list of files
for i in "${BACKUP_LIST[@]}"; do

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
    # cp "${DATA_DIR}/server.properties" "${BACKUP_DESTINATION}/server.properties"
    # cp "${DATA_DIR}/whitelist.json" "${BACKUP_DESTINATION}/whitelist.json"
    # cp "${DATA_DIR}/permissions.json" "${BACKUP_DESTINATION}/permissions.json"

done

# Release system from backup
echo "Releasing server from 'save hold'..."
echo save resume > /proc/${SERVER_PID}/fd/0

# Compress backup
echo "Compressing backup..."
cd "${BACKUP_DIR}/${WORLD_DIR}" || exit 1
tar czvf "${BACKUP_DATETIME}.tar.gz" "${BACKUP_DATETIME}"  | stdbuf -o0 awk '{print "  + " $0}'

# Clean up files now they're compressed
echo "Removing temporary files..."
rm -r "${BACKUP_DIR}/${WORLD_DIR}/${BACKUP_DATETIME}"

# Show backup file info
stat --format="Created backup file: '%n', size: %s bytes" "${BACKUP_DIR}/${WORLD_DIR}/${BACKUP_DATETIME}.tar.gz"

# Finished
echo "Backup Finished"
echo ""

exit 0

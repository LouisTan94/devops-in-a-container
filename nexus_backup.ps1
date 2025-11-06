$VOLUME="devops-in-a-container_nexus_data"
# Backup:
$date = Get-Date -Format "yyyy-MM-dd_HH-mm"
docker run --rm -v ${VOLUME}:/nexus-data -v ${PWD}:/backup-dir ubuntu sh -c "tar cvzf /backup-dir/${date}_nexus.tar.gz /nexus-data"
# Restore:
#docker run --rm -v "${VOLUME}:/nexus-data" -v "${PWD}:/backup-dir" ubuntu bash -c "rm -rf /nexus-data/{*,.*}; cd /nexus-data && tar xvzf /backup-dir/nexus.tar.gz --strip 1"  
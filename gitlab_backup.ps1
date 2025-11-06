docker exec dep-pipeline-gitlab gitlab-rake gitlab:backup:create DIRECTORY=gitlab

$date = Get-Date -Format "yyyy-MM-dd_HH-mm"
Copy-Item -Path "./gitlab/config/gitlab.rb" -Destination "./gitlab/data/backups/${date}_gitlab.rb"
Copy-Item -Path "./gitlab/config/gitlab-secrets.json" -Destination "./gitlab/data/backups/${date}_gitlab-secrets.json"

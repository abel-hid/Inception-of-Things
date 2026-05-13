#!/bin/bash
set -e

k3d cluster delete mycluster 2>/dev/null || true
docker rm -f gitlab 2>/dev/null || true
rm -rf /srv/gitlab /tmp/bel-idri-gitlab /tmp/bel-idri-gitlab-update

echo "Bonus environment cleaned. If you want, manually remove the GitLab line from /etc/hosts."

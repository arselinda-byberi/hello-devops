#!/usr/bin/env bash
# Starts the whole CI/CD lab inside the Codespace. Safe to run again at any time
# (e.g. after the Codespace was stopped): it only creates what is missing.
#
#   private registry  (k3d-lab-registry.localhost, port 5000)
#   Kubernetes        (k3d = k3s in Docker, cluster "lab", NodePorts 30080/30081)
#   Jenkins           (container on the cluster's network, port 8080)
set -euo pipefail
cd "$(dirname "$0")"

CLUSTER="lab"
REGISTRY="lab-registry.localhost"
NETWORK="k3d-${CLUSTER}"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

step "1/4 Private image registry"
if k3d registry list | grep -q "k3d-${REGISTRY}"; then
  docker start "k3d-${REGISTRY}" >/dev/null
  echo "registry already exists (started)"
else
  k3d registry create "${REGISTRY}" --port 5000
fi

step "2/4 Kubernetes cluster (k3s via k3d)"
if k3d cluster list | grep -q "^${CLUSTER} "; then
  k3d cluster start "${CLUSTER}"
else
  k3d cluster create "${CLUSTER}" \
    --servers 1 --agents 0 \
    --registry-use "k3d-${REGISTRY}:5000" \
    -p "30080:30080@loadbalancer" \
    -p "30081:30081@loadbalancer" \
    --k3s-arg "--disable=traefik@server:*" \
    --k3s-arg "--tls-san=k3d-${CLUSTER}-serverlb@server:*" \
    --wait
fi
kubectl wait --for=condition=Ready node --all --timeout=120s

# Jenkins runs in a container on the cluster network, so it reaches the API
# through the load balancer's container name instead of localhost.
k3d kubeconfig get "${CLUSTER}" \
  | sed -E "s#server: https://[^[:space:]]+#server: https://k3d-${CLUSTER}-serverlb:6443#" \
  > .kubeconfig-jenkins
chmod 644 .kubeconfig-jenkins

step "3/4 Build the Jenkins image (Jenkins + Docker CLI + kubectl + Helm + Python)"
docker build -t lab-jenkins:latest jenkins/

step "4/4 Start Jenkins"
if [ ! -f .jenkins-admin-password ]; then
  head -c 18 /dev/urandom | base64 | tr -d '/+=' | head -c 16 > .jenkins-admin-password
fi

JENKINS_URL="http://localhost:8080/"
if [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
  JENKINS_URL="https://${CODESPACE_NAME}-8080.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/"
fi

docker rm -f lab-jenkins >/dev/null 2>&1 || true
docker run -d --name lab-jenkins --restart unless-stopped \
  --network "${NETWORK}" \
  -p 8080:8080 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$(stat -c %g /var/run/docker.sock)" \
  -v "${PWD}/.kubeconfig-jenkins:/var/jenkins_home/.kube/config:ro" \
  -e JENKINS_ADMIN_PASSWORD="$(cat .jenkins-admin-password)" \
  -e JENKINS_URL="${JENKINS_URL}" \
  lab-jenkins:latest >/dev/null

printf 'Waiting for Jenkins to start'
for _ in $(seq 1 60); do
  if curl -fs -o /dev/null http://localhost:8080/login; then echo " ready"; break; fi
  printf '.'; sleep 3
done

cat <<EOF

==================================================================
 Lab is up.

 Jenkins:   ${JENKINS_URL}
            user: admin
            password: $(cat .jenkins-admin-password)

 Cluster:   kubectl get nodes
 App (dev): curl http://localhost:30080/   (after the first develop build)
 App (prod):curl http://localhost:30081/   (after an approved main build)
==================================================================
EOF

# 1Password secret-reference template for the logging stack.
#
# These are `op://<vault>/<item>/<field>` references, NOT the values themselves,
# so this file is safe to commit. `op run` / `op inject` resolve them at deploy
# time from your 1Password vault.
#
# Deploy with the values injected into the environment:
#   op run --env-file=deploy/logging/logging.env.tpl -- \
#     docker stack deploy -c deploy/logging/logging-stack.yml logging
#
# REPLACE ME — adjust the vault name ("Homelab"), item ("Grafana Cloud Loki"),
# and field names to match how you've stored them in 1Password.
LOKI_URL=op://Homelab/Grafana Cloud Loki/url
LOKI_USERNAME=op://Homelab/Grafana Cloud Loki/username

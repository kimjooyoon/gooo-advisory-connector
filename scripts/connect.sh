#!/usr/bin/env bash
set -euo pipefail
if test "$#" -ne 4; then echo "usage: connect.sh ROOT INPUT_ROOT OUTPUT SUBJECT_SHA" >&2; exit 64; fi
root=$1; input_root=$2; output=$3; subject_sha=$4
test "${#subject_sha}" -eq 40 && case "$subject_sha" in *[!0-9a-f]*) exit 65;; esac
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
: > "$work/relations.ndjson"; : > "$work/projects.ndjson"
for domain in design-evidence infra-evidence local-ledger; do
  bundle="$input_root/$domain/bundle-a"; test -f "$bundle/project.json" && test -f "$bundle/relations.ndjson" || { echo "missing canonical input bundle: $domain" >&2; exit 66; }
  jq -e --arg domain "$domain" '.schema=="gooo/interchange/project/v1" and .domain==$domain and .relation_count==1' "$bundle/project.json" >/dev/null
  jq -e '.schema=="gooo/interchange/relation/v1" and (.state|IN("MATCH","MISMATCH","UNKNOWN")) and (.left.kind|type)=="string" and (.left.id|type)=="string" and (.right.kind|type)=="string" and (.right.id|type)=="string"' "$bundle/relations.ndjson" >/dev/null
  jq -S -c --arg domain "$domain" '.+{connector_domain:$domain}' "$bundle/project.json" >> "$work/projects.ndjson"
  jq -S -c --arg domain "$domain" '.+{connector_domain:$domain}' "$bundle/relations.ndjson" >> "$work/relations.ndjson"
done
mkdir -p "$output"; test -z "$(find "$output" -mindepth 1 -maxdepth 1 -print -quit)"
jq -S -s '[.[]|.left,.right]|unique_by(.kind,.id)|sort_by(.kind,.id)[]|{schema:"gooo/advisory-connector/node/v1",kind:.kind,id:.id}' "$work/relations.ndjson" | jq -S -c . > "$output/nodes.ndjson"
jq -S -s 'sort_by(.connector_domain,.id)[]|{schema:"gooo/advisory-connector/edge/v1",id:.id,domain:.connector_domain,kind:.kind,state:.state,from:.left,to:.right,evidence:.evidence,stage:.stage,step:.step,reason:.reason,unknown_class:.unknown_class,next_operation:.next_operation}' "$work/relations.ndjson" | jq -S -c . > "$output/edges.ndjson"
jq -S -c 'select(.state=="UNKNOWN")' "$output/edges.ndjson" > "$output/unknowns.ndjson"
node_count=$(wc -l < "$output/nodes.ndjson" | tr -d ' '); edge_count=$(wc -l < "$output/edges.ndjson" | tr -d ' '); unknown_count=$(wc -l < "$output/unknowns.ndjson" | tr -d ' ')
anchor_count=$(jq -s '[.[].to|(.kind+"\u0000"+.id)]|unique|length' "$output/edges.ndjson")
jq -S -n --arg subject_sha "$subject_sha" --argjson node_count "$node_count" --argjson edge_count "$edge_count" --argjson unknown_count "$unknown_count" --argjson anchor_count "$anchor_count" --slurpfile projects "$work/projects.ndjson" '{schema:"gooo/advisory-connector/portfolio/v1",subject_sha:$subject_sha,domains:([$projects[].domain]|sort),domain_count:($projects|length),node_count:$node_count,edge_count:$edge_count,unknown_count:$unknown_count,shared_specification_anchor_count:$anchor_count,input_releases:([$projects[]|{domain,repository:.release.repository,tag:.release.tag,target_commit_sha:.release.target_commit_sha,source_asset_sha256:.release.source_asset_sha256}]|sort_by(.domain)),authority:{effect:"READ_ONLY",external_required_gates:0}}' > "$output/portfolio.json"
(cd "$output" && sha256sum portfolio.json nodes.ndjson edges.ndjson unknowns.ndjson > checksums.txt)

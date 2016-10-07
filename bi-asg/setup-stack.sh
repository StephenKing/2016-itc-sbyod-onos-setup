#!/bin/bash
set -euo pipefail

echo "Creating snapshot..."
nova image-create --poll nginx-template nginx-template-snapshot

# echo "Deleting original VM..."
openstack server delete nginx-template

echo "Creating Heat Stack..."
openstack stack create nginx-consul-bi -t asg_consul_stack.yaml -e environment.yaml

echo "Done."

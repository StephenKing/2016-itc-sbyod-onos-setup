output "consul_floating_ips" {
   value = "${join(", ", openstack_compute_instance_v2.consul_node.*.floating_ip)}"
}

output "consul_floating_http" {
  value = "http://${openstack_compute_instance_v2.consul_node.0.floating_ip}:8500"
}

output "nginx_template_floating_ip" {
  value = "${openstack_compute_instance_v2.nginx_template_node.floating_ip}"
}

output "nginx_template_http" {
  value = "http://${openstack_compute_instance_v2.nginx_template_node.floating_ip}"
}

output "nginx_template_instance_id" {
  value = "${openstack_compute_instance_v2.nginx_template_node.uuid}"
}

output "portal_floating_ip" {
  value = "${openstack_compute_instance_v2.portal.floating_ip}"
}

output "vpn_floating_ip" {
  value = "${openstack_compute_instance_v2.vpn.floating_ip}"
}

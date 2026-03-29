output "instance_ip" {
  description = "External IP of the auto-scaled cloud VM"
  value       = google_compute_instance.autoscale_vm.network_interface[0].access_config[0].nat_ip
}

output "instance_name" {
  description = "Name of the auto-scaled cloud VM"
  value       = google_compute_instance.autoscale_vm.name
}

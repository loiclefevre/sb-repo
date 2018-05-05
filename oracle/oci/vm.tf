// Terraform template for Oracle Cloud Infrastructure VM

provider "oci" {
  tenancy_ocid     = "${var.tenancy_ocid}"
  user_ocid        = "${var.user_ocid}"
  fingerprint      = "${var.fingerprint}"
  private_key_path = "${var.private_key_path}"
  region           = "${var.region}"
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = "${var.tenancy_ocid}"
}

resource "oci_core_virtual_network" "VCN-SB" {
  cidr_block     = "10.0.0.0/24"
  compartment_id = "${var.compartment_ocid}"
  display_name   = "VCN-SB-${var.sbName}"
  dns_label      = "sb"
}

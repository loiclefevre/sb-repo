// Terraform template for Oracle Cloud Infrastructure Database Cloud Service VM

resource "oci_database_db_system" "SB-Datastore" {
  availability_domain = "${lookup(data.oci_identity_availability_domains.ADs.availability_domains[var.datastore_availability_domain],"name")}"
  compartment_id = "${var.compartment_ocid}"
  cpu_core_count = "${var.datastore["CPUCoreCount"]}"
  database_edition = "${var.datastore["Edition"]}"
  db_home {
    database {
      "admin_password" = "${var.datastore["AdminPassword"]}"
      "db_name" = "${var.datastore["ContainerName"]}"
      "character_set" = "${var.datastore["CharacterSet"]}"
      "ncharacter_set" = "${var.datastore["NCharacterSet"]}"
      "db_workload" = "${var.datastore["Workload"]}"
      "pdb_name" = "${var.datastore["PDBName"]}"
    }
    db_version = "${var.datastore["Version"]}"
    display_name = "${var.datastore["DisplayName"]}"
  }
  disk_redundancy = "${var.datastore["DiskRedundancy"]}"
  shape = "${var.datastore["NodeShape"]}"
  subnet_id = "${oci_core_subnet.SN-SB-Data.id}"
  ssh_public_keys = ["${var.ssh_public_key}"]
  display_name = "${var.datastore["NodeDisplayName"]}${var.sbName}"
  domain = "${var.datastore["NodeDomainName"]}"
  hostname = "${var.datastore["NodeHostName"]}"
  data_storage_percentage = "${var.datastore["StoragePercent"]}"
  data_storage_size_in_gb = "${var.datastore["StorageSizeInGB"]}"
  license_model = "${var.datastore["LicenseModel"]}"
  node_count = "${var.datastore["NodeCount"]}"
}

# Get DB node list
data "oci_database_db_nodes" "DBNodeList" {
  compartment_id = "${var.compartment_ocid}"
  db_system_id = "${oci_database_db_system.SB-Datastore.id}"
}

# Get DB node details
data "oci_database_db_node" "DBNodeDetails" {
  db_node_id = "${lookup(data.oci_database_db_nodes.DBNodeList.db_nodes[0], "id")}"
}

# Gets the OCID of the first (default) vNIC
data "oci_core_vnic" "DBNodeVnic" {
  vnic_id = "${data.oci_database_db_node.DBNodeDetails.vnic_id}"
}

# Output the private IP of the instance
output "DBNodePublicIP" {
  value = ["${data.oci_core_vnic.DBNodeVnic.public_ip_address}"]
}

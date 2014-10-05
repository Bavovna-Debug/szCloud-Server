<?php

function parse_ip_address()
{
	global $ip_version;
	global $ip_address;
	global $guest_ip;

	$value = $_GET['ip_address'];
	if (!isset($value))
		$value = $_GET['ip'];

	# If IP address not provided we assume that IP address
	# of this user is the one known to HTTP server.
	#
	if (!isset($value))
		$value = $guest_ip;

	if (!isset($value))
		notify_and_quit("IP address is missing");

	# Recognize IP address family.
	#
	if ($ipv4 = filter_var($value, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
		$ip_version = 'A';
		$ip_address = $ipv4;
	} elseif ($ipv6 = filter_var($value, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6)) {
		$ip_version = 'AAAA';
		$ip_address = $ipv6;
	} elseif (filter_var('ssh://' . $value, FILTER_VALIDATE_URL) && !strpos($value, '/')) {
		$ip_version = 'CNAME';
		$ip_address = $value;
	} else {
		notify_and_quit("IP address cannot be recognized");
	}
}
/*
function set_ip_address()
{
	global $guest_ip;
	global $port;
	global $ip_version;
	global $ip_address;
	global $host_id;
	global $agent;

	# If expiration parameter is not given then set seconds to 0.
	# In such case expiration will be ignored by SQL backend.
	#
	$seconds = $_GET['seconds'];
	if (!isset($seconds))
		$seconds = $_GET['sec'];
	if (!isset($seconds))
		$seconds = 0;

	# Check whether IP address of this host has changed since his last bonjour.
	#
	$sql = "SELECT nimbus_set_ip($host_id, '$guest_ip', '$port', '$ip_version', '$ip_address', '$agent', $seconds) AS changed";
	$db_result = mysql_query($sql)
		or notify_and_quit("SQL: nimbus_set_ip query");
	$db_row = mysql_fetch_object($db_result)
		or notify_and_quit("SQL: nimbus_set_ip fetch");

	# According to DynDNS standards, if user's IP address is not changed
	# since his last visit, we should give a return code 304 back.
	# If IP address is changed we confirm with return code 200 that
	# new IP address is accepted and will be reflected in the DNS system.
	#
	if ($db_row->changed) {
		notify_and_quit("OK", 200);
	} else {
		notify_and_quit("IP address did not change", 200);
	}
}
*/
function set_ip_address()
{
	global $ip_address;
	global $host_id;

	$nameServerIPAddress = '78.47.11.62';

	$sql = "SELECT parent_id, full_name
			FROM cloud_bender.hash_repository
			WHERE hash_id = $host_id";
	$db_result = mysql_query($sql)
		or notify_and_quit("SQL-Q: hash_repository");
	$host = mysql_fetch_object($db_result)
		or notify_and_quit("SQL-F: hash_repository");

	$sql = "SELECT hash_id, full_name
			FROM cloud_bender.hash_repository
			WHERE hash_id = $host->parent_id";
	$db_result = mysql_query($sql)
		or notify_and_quit("SQL-Q: hash_repository");
	$cloud = mysql_fetch_object($db_result)
		or notify_and_quit("SQL-F: hash_repository");

	$sql = "SELECT key_algorithm, key_name, key_secret
			FROM cloud_bender.dnssec_keys
				USE INDEX (idx_internal)
			JOIN cloud_bender.dnssec_rules
				USE INDEX (idx_dnssec_key_id_hash_id)
				USING (dnssec_key_id)
			WHERE hash_id = $cloud->hash_id
			  AND internal IS TRUE";
	$db_result = mysql_query($sql)
		or notify_and_quit("SQL-Q: hash_repository");
	$key = mysql_fetch_object($db_result)
		or notify_and_quit("SQL-F: hash_repository");

	$query  = sprintf("server %s\n", $nameServerIPAddress);
	$query .= sprintf("zone %s\n", $cloud->full_name);
	$query .= sprintf("update delete %s A\n",
		$host->full_name);
	$query .= sprintf("update add %s 60 A %s\n",
		$host->full_name,
		$ip_address);
	$query .= "send\n";
	$query .= "quit\n";

	$command = sprintf("echo \"%s\" | nsupdate -v -d -y %s:%s:%s",
		$query,
		strtolower($key->key_algorithm),
		$key->key_name,
		$key->key_secret);

	exec($command);

	notify_and_quit("OK", 200);
}

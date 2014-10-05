<?php

function get_clouds_by_user_id($user_id, $xml)
{
	$sql = "SELECT hash_id, hash_code, name, full_name
			FROM hash_repository
				USE INDEX (idx_user_id_object_type)
			WHERE user_id = $user_id
			  AND object_type = 'CLD'";
	$db_result = mysql_query($sql)
		or notify_and_quit('SQL-Q: clouds');
	while ($db_row = mysql_fetch_object($db_result)) {
		$cloud_xml = $xml->addChild('CLOUD', $db_row->full_name);
		$cloud_xml->addAttribute('HASH', $db_row->hash_code);
		$cloud_xml->addAttribute('NAME', $db_row->name);
		get_hosts_by_cloud_id($db_row->hash_id, $cloud_xml);
	}
}

function get_hosts_by_cloud_id($cloud_id, $xml)
{
	$sql = "SELECT hash_code, name, full_name
			FROM hash_repository
				USE INDEX (idx_user_id_object_type)
			WHERE parent_id = $cloud_id
			  AND object_type = 'HST'";
	$db_result = mysql_query($sql)
		or notify_and_quit('SQL-Q: hosts');

	while ($db_row = mysql_fetch_object($db_result)) {
		$host_xml = $xml->addChild('HOST', $db_row->full_name);
		$host_xml->addAttribute('HASH', $db_row->hash_code);
		$host_xml->addAttribute('NAME', $db_row->name);
	}
}

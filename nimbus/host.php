<?php

function validate_host()
{
	global $secret;
	global $user_id;
	global $host_id;
	global $script;
	global $password;

	if (isset($secret)) {
		#
		# Check whether specified host belongs to this user.
		#
		$sql = "SELECT host_exists_by_secret('$secret') AS host_id";
		$db_result = mysql_query($sql)
			or notify_and_quit("SQL-Q: host_exists_by_secret");
		$db_row = mysql_fetch_object($db_result)
			or notify_and_quit("SQL-F: host_exists_by_secret");

		$host_id = $db_row->host_id;
		if ($host_id == 0)
			notify_and_quit("Wrong host key");
	} else {
		$hostname = $_GET['hostname'];
		if (!isset($hostname))
			$hostname = $_GET['host'];
		if (!isset($hostname) && ($script == 'dyndns'))
			$hostname = $_GET['domain'];
		if (!isset($hostname))
			notify_and_quit("Hostname is missing");

		#
		# Check whether specified host belongs to this user.
		#
		$sql = "SELECT host_exists_by_name($user_id, '$hostname') AS host_id";
		$db_result = mysql_query($sql)
			or notify_and_quit("SQL-Q: host_exists_by_name");
		$db_row = mysql_fetch_object($db_result)
			or notify_and_quit("SQL-F: host_exists_by_name");

		$host_id = $db_row->host_id;
		if ($host_id == 0)
			notify_and_quit("Wrong hostname");

		# Identify user. Quit if password does not match.
		#
		$sql = "SELECT hash_authorization($host_id, $user_id, '$password') AS authorized";
		$db_result = mysql_query($sql)
			or notify_and_quit("SQL-Q: hash_authorization");
		$db_row = mysql_fetch_object($db_result)
			or notify_and_quit("SQL-F: hash_authorization");

		if ($db_row->authorized == false)
			notify_and_quit("Authorization error");
	}
}

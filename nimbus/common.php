<?php

function db_connect()
{
	# Establish MySQL connection.
	#
	mysql_connect("localhost", "cloud", "Nebula15")
		or die("Access denied");

	# Select a database.
	#
	mysql_select_db("cloud_bender")
		or die("Access denied");
}

function notify_and_quit($message, $status_code = 500)
{
	global $guest_ip;
	global $hostname;
	global $port;
	global $agent;
	global $query;
	global $user_id;

	if ($status_code == 500)
		sleep(3);

	# HTTP header of our answer to user consits of return code and comment.
	#
	header("HTTP/1.0 $status_code $message", true, $status_code);

	# Log this bonjour.
	#
	$sql = "INSERT INTO nimbus_debug
				(user_id, ip_address, guest_host_name, port, agent, query, status_code, answer)
			VALUES ($user_id, '$guest_ip', '$hostname', '$port', '$agent', '$query', '$status_code', '$message')";
	mysql_query($sql);

	exit;
}

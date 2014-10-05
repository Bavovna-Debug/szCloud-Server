<?php

# Store some global environment variables for later use.
#
$guest_ip  = $_SERVER['REMOTE_ADDR'];
$hostname  = $_SERVER['REMOTE_HOST'];
$port      = $_SERVER['REMOTE_PORT'];
$agent     = $_SERVER['HTTP_USER_AGENT'];
$query     = $_SERVER['QUERY_STRING'];
$root      = $_SERVER['DOCUMENT_ROOT'];
$script    = substr($_SERVER['SCRIPT_NAME'], 1);

$secret      = null;
$username    = null;
$password    = null;
$user_id     = 0;
$host_id     = 0;
$cloud_id    = 0;
$ip_version  = null;
$ip_address  = null;

require_once($root . '/common.php');
db_connect();

switch ($script) {
case "dyndns":
	require_once($root . '/auth.php');
	require_once($root . '/host.php');
	require_once($root . '/ip.php');

	authenticate();
	validate_host();
	parse_ip_address();
	set_ip_address();
	break;

case "setip":
	require_once($root . '/auth.php');
	require_once($root . '/host.php');
	require_once($root . '/ip.php');

	authenticate();
	validate_host();
	parse_ip_address();
	set_ip_address();
	break;

case "delipv4":
	break;

case "delipv6":
	break;

case "list_all":
	require_once($root . '/auth.php');
	require_once($root . '/list.php');

	authenticate();
	$xml = new SimpleXMLElement('<RESULT />');
	get_clouds_by_user_id($user_id, $xml);
	print $xml->asXML();
	break;

default:
	notify_and_quit("Access violation");
}

exit;

?>

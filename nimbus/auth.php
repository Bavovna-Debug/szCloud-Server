<?php

function authenticate()
{
	if (authenticate_by_secret())
		return;

	if (authenticate_by_customer_number())
		return;

	if (authenticate_by_username())
		return;

	notify_and_quit("Authentication failed");
}

function authenticate_by_secret()
{
	global $secret;

	$secret = $_GET['secret'];
	if (!isset($secret))
		$secret = $_GET['key'];

	if (!isset($secret))
		return false;

	return true;
}

function authenticate_by_customer_number()
{
	global $user_id;

	$customer_number = $_GET['customer'];
	if (!isset($customer_number))
		return false;

	# Check whether user exists and his account is activated.
	#
	$sql = "SELECT virtuemart_user_id AS user_id
			FROM cloud_joomla.joomla_virtuemart_vmusers
			WHERE customer_number = '$customer_number'";
	$db_result = mysql_query($sql)
		or notify_and_quit("SQL-Q: joomla_virtuemart_vmusers");
	$db_row = mysql_fetch_object($db_result)
		or notify_and_quit("Wrong customer number");
	
	$user_id = $db_row->user_id;
	if ($user_id == 0)
		notify_and_quit("Wrong customer number");

	return true;
}

function authenticate_by_username()
{
	global $user_id;
	global $username;
	global $password;

	$username = $_GET['username'];
	if (!isset($username))
		$username = $_GET['user'];

	$password = $_GET['password'];
	if (!isset($password))
		$password = $_GET['pass'];

	# Make sure username and password are provided. Otherwise quit.
	#
	if (!isset($username) || !isset($password))
		return false;

	# Check whether user exists and his account is activated.
	#
	$sql = "SELECT user_exists('$username') AS user_id";
	$db_result = mysql_query($sql)
		or notify_and_quit("SQL-Q: user_exists");
	$db_row = mysql_fetch_object($db_result)
		or notify_and_quit("SQL-F: user_exists");
	
	$user_id = $db_row->user_id;
	if ($user_id == 0)
		notify_and_quit("Wrong username or password");

	# Check whether user is activated.
	#
	$sql = "SELECT user_enabled($user_id) AS enabled";
	$db_result = mysql_query($sql)
		or notify_and_quit("SQL-Q: user_enabled");
	$db_row = mysql_fetch_object($db_result)
		or notify_and_quit("SQL-F: user_enabled");
	
	if ($db_row->enabled == false)
		notify_and_quit("Wrong username or password");

	return true;
}

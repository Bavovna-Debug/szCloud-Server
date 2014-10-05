DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  Check whether user exists. If yes then return his id back.                */
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.user_exists;
CREATE FUNCTION cloud_bender.user_exists (
	$username		VARCHAR(150) CHARACTER SET utf8)

	RETURNS		INTEGER UNSIGNED

NOT DETERMINISTIC
READS SQL DATA
BEGIN
	DECLARE $user_id	INTEGER UNSIGNED;
	DECLARE $found		BOOLEAN DEFAULT TRUE;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	SET $found = FALSE;

	/*
	 * Search for a user and make sure his account is not blocked.
	 */
	SELECT user_id
	FROM cloud_bender.customers
	WHERE username = $username
	  AND blocked = FALSE
	INTO $user_id;

	/*
	 * If such user does not exists return 0.
	 */
	IF NOT $found THEN
		SET $user_id = 0;
	END IF;

	RETURN $user_id;
END;


/******************************************************************************/
/*                                                                            */
/*  Check whether user account is enabled.                                    */
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.user_enabled;
CREATE FUNCTION cloud_bender.user_enabled (
	$user_id			INTEGER UNSIGNED)

	RETURNS				BOOLEAN

NOT DETERMINISTIC
READS SQL DATA
BEGIN
	DECLARE $enabled	BOOLEAN;
	DECLARE $found		BOOLEAN DEFAULT TRUE;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	SET $found = FALSE;

	/*
	 * Check whether user acount is not blocked.
	 */
	SELECT (blocked = FALSE)
	FROM cloud_bender.customers
	WHERE user_id = $user_id
	INTO $enabled;

	/*
	 * If such user does not exists return 0.
	 */
	IF NOT $found THEN
		RETURN FALSE;
	END IF;

	RETURN $enabled;
END;


/******************************************************************************/
/*                                                                            */
/*  Check whether specified host exists by its special host key.              */
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.host_exists_by_secret;
CREATE FUNCTION cloud_bender.host_exists_by_secret (
	$secret				CHAR(16) CHARACTER SET utf8)

	RETURNS			INTEGER

NOT DETERMINISTIC
READS SQL DATA
BEGIN
	DECLARE $host_id	INTEGER UNSIGNED;
	DECLARE $found		BOOLEAN DEFAULT TRUE;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	SET $found = FALSE;

	SELECT hash_id
	FROM cloud_bender.hash_repository
		USE INDEX (idx_secret)
	WHERE secret = $secret
	INTO $host_id;

	IF NOT $found THEN
		SET $host_id = 0;
	END IF;

	RETURN $host_id;
END;


/******************************************************************************/
/*                                                                            */
/*  Check whether specified host exists in users account.                     */
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.host_exists_by_name;
CREATE FUNCTION cloud_bender.host_exists_by_name (
	$user_id			INTEGER UNSIGNED,
	$host_name			VARCHAR(194) CHARACTER SET utf8)

	RETURNS			INTEGER

NOT DETERMINISTIC
READS SQL DATA
BEGIN
	DECLARE $host_id	INTEGER UNSIGNED;
	DECLARE $found		BOOLEAN DEFAULT TRUE;

	DECLARE CONTINUE HANDLER
	FOR NOT FOUND
	SET $found = FALSE;

	/*
	 * Search for a host for specified user.
	 */
	SELECT hash_id
	FROM cloud_bender.hash_repository
		USE INDEX (idx_user_id, idx_full_name)
	WHERE user_id = $user_id
	  AND full_name = $host_name
	INTO $host_id;

	/*
	 * If user does not have specified host in his account return 0.
	 */
	IF NOT $found THEN
		SET $host_id = 0;
	END IF;

	RETURN $host_id;
END;

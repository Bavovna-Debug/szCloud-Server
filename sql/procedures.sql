DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  Validate host's IP address. Return 'true' if IP address is changed since  */
/*  last bonjour. Otherwise, return 'false' which also mean that IP address   */
/*  is still the same.                                                        */
/*                                                                            */
/*  Return value 'true' means that some DNS actions must take place.          */
/*                                                                            */
/******************************************************************************/
DROP FUNCTION IF EXISTS cloud_bender.validate_ip;
CREATE FUNCTION cloud_bender.validate_ip (
	$hash_id			INTEGER,
	$new_ip				CHAR(15))

	RETURNS			BOOLEAN

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $last_ip	CHAR(15);

	/*
	 * Look for last known IP address of a specified host.
	 */
	SELECT ip_address
	FROM cloud_bender.hosts
		USE INDEX (idx_hash_id)
	WHERE hash_id = $hash_id
	INTO $last_ip;

	/*
	 * If there were no IP address recorded for this user or if
	 */
	IF $new_ip != $last_ip THEN
		UPDATE cloud_bender.hosts
			USE INDEX (idx_hash_id)
		SET ip_address = $new_ip
		WHERE hash_id = $hash_id;

		RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END;

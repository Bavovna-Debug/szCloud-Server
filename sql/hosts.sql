DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  List of hosts.                                                            */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.hosts (
	hash_id					INTEGER UNSIGNED	NOT NULL,
	need_dns_revalidation	BOOLEAN			NOT NULL DEFAULT FALSE,
	first_ip_set			BOOLEAN			NOT NULL DEFAULT FALSE,

	UNIQUE KEY idx_hash_id (hash_id),
	KEY idx_first_ip_set (first_ip_set),
	KEY idx_need_dns_revalidation (need_dns_revalidation)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS cloud_bender.create_host;
CREATE PROCEDURE cloud_bender.create_host (
	IN $user_id			INTEGER UNSIGNED,
	IN $cloud_id		INTEGER UNSIGNED,
	IN $host_name		CHAR(64) CHARACTER SET utf8)

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $hash_id	INTEGER UNSIGNED;

	/*
	 * Create a new HASH.
	 */
	SET $hash_id = cloud_bender.create_hash($user_id, $cloud_id, "HST", $host_name);

	/*
	 * Create a new host.
	 */
	INSERT LOW_PRIORITY
	INTO cloud_bender.hosts (hash_id)
	VALUES ($hash_id);
END;

DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  List of user defined domains.                                             */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.domains (
	hash_id			INTEGER UNSIGNED	NOT NULL,
	soa_id			INTEGER UNSIGNED	NOT NULL,
	domain_file_id	INTEGER UNSIGNED	NULL DEFAULT NULL,
	activated		BOOLEAN			NOT NULL DEFAULT FALSE,
	confirmed		BOOLEAN			NOT NULL DEFAULT FALSE,

	UNIQUE KEY idx_hash_id (hash_id),
	KEY idx_domain_file_id (domain_file_id),
	KEY idx_activated_confirmed (activated, confirmed)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.domains_insert;
CREATE TRIGGER cloud_bender.domains_insert
BEFORE INSERT ON cloud_bender.domains
FOR EACH ROW BEGIN
	/*
	 * For each domain there should be a corresponding SOA record entry.
	 */
	INSERT INTO cloud_bender.soas VALUES ();

	SET NEW.soa_id = LAST_INSERT_ID();
END;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP TRIGGER IF EXISTS cloud_bender.clouds_insert;
CREATE TRIGGER cloud_bender.clouds_insert
BEFORE INSERT ON cloud_bender.clouds
FOR EACH ROW BEGIN
	DECLARE $domain_id		INTEGER UNSIGNED;
	DECLARE $activated		BOOLEAN;

	/*
	 * Find out this cloud's domain id.
	 */
	SELECT parent_id
	FROM cloud_bender.hash_repository
		USE INDEX (PRIMARY)
	WHERE hash_id = NEW.hash_id
	INTO $domain_id;

	/*
	 * Find out whether this cloud's domain is activated.
	 */
	SELECT activated
	FROM cloud_bender.domains
		USE INDEX (idx_hash_id)
	WHERE hash_id = $domain_id
	INTO $activated;

	/*
	 * If the domain of this cloud is activated then...
	 */
	IF $activated THEN
		/*
		 * ...mark its domain as updated.
		 */
		CALL cloud_bender.schedule('UPDATE_DOMAIN_FILE', $domain_id, 0);
	END IF;
END;

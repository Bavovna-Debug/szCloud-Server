DELIMITER //

/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dns_updates (
	stamp			TIMESTAMP				NOT NULL DEFAULT CURRENT_TIMESTAMP,
	milliseconds	SMALLINT UNSIGNED		NOT NULL,
	update_id		INTEGER UNSIGNED		NOT NULL AUTO_INCREMENT,
	zone_id			INTEGER UNSIGNED		NOT NULL,
	hash_id			INTEGER UNSIGNED		NOT NULL,
	processed		BOOLEAN				NOT NULL DEFAULT FALSE,
	client_ip		CHAR(40)				NOT NULL,
	client_port		SMALLINT UNSIGNED		NOT NULL,
	update_type		ENUM('ADDRR', 'DELRR', 'DELRRSET') NOT NULL,
	dns_type		ENUM('A', 'AAAA', 'CNAME', 'MX', 'NS', 'RP', 'TXT') NOT NULL,

	PRIMARY KEY (update_id),
	KEY idx_zone_id (zone_id),
	KEY idx_hash_id (hash_id),
	KEY idx_processed (processed)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;


/******************************************************************************/
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dns_rejects (
	stamp			TIMESTAMP				NOT NULL DEFAULT CURRENT_TIMESTAMP,
	milliseconds	SMALLINT UNSIGNED		NOT NULL,
	reject_id		INTEGER UNSIGNED		NOT NULL AUTO_INCREMENT,
	zone_id			INTEGER UNSIGNED		NOT NULL,
	client_ip		CHAR(40)				NOT NULL,
	client_port		SMALLINT UNSIGNED		NOT NULL,
	reason			VARCHAR(40)			NOT NULL,

	PRIMARY KEY (reject_id),
	KEY idx_zone_id (zone_id)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;

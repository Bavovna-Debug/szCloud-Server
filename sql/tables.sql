DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  History of Nimbus requests.                                               */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.nimbus_debug (
	stamp			TIMESTAMP			NOT NULL DEFAULT CURRENT_TIMESTAMP,
	event_id		BIGINT UNSIGNED	NOT NULL AUTO_INCREMENT,
	user_id			INTEGER UNSIGNED	NOT NULL,
	ip_address		CHAR(15)			NOT NULL,
	guest_host_name	VARCHAR(64)		NOT NULL,
	port			SMALLINT UNSIGNED	NOT NULL,
	agent			VARCHAR(128)		NOT NULL,
	query			VARCHAR(200)		NOT NULL,
	status_code		CHAR(3)			NOT NULL,
	answer			VARCHAR(64)		NOT NULL,

	PRIMARY KEY (event_id),
	KEY idx_user_id (user_id)
)
ENGINE = MyISAM
DEFAULT CHARSET = utf8;

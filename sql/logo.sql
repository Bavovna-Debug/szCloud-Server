DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  List of clouds icons and pictures.                                        */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.logos (
	logo_id		INTEGER UNSIGNED	NOT NULL AUTO_INCREMENT,
	recommended	BOOLEAN			NOT NULL DEFAULT FALSE,
	logo_16		VARCHAR(64)		NULL DEFAULT NULL,
	logo_24		VARCHAR(64)		NULL DEFAULT NULL,
	logo_32		VARCHAR(64)		NULL DEFAULT NULL,
	logo_48		VARCHAR(64)		NULL DEFAULT NULL,
	logo_64		VARCHAR(64)		NULL DEFAULT NULL,
	logo_128	VARCHAR(64)		NULL DEFAULT NULL,
	logo_256	VARCHAR(64)		NULL DEFAULT NULL,

	PRIMARY KEY (logo_id)
)
ENGINE = MyISAM
DEFAULT CHARSET = utf8;

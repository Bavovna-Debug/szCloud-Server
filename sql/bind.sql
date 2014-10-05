DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  Journal of restart schedules for BIND process.                            */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.bind_schedules (
	event_id		INTEGER UNSIGNED	NOT NULL AUTO_INCREMENT,
	requested		TIMESTAMP			NOT NULL DEFAULT CURRENT_TIMESTAMP,
	scheduled		TIMESTAMP			NOT NULL,
	processed		TIMESTAMP			NULL DEFAULT NULL,
	zone_name		VARCHAR(255)		NULL DEFAULT NULL,

	PRIMARY KEY (event_id),
	KEY idx_check_not_processed (scheduled, processed)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;

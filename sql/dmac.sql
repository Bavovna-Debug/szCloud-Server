DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  List of clouds.                                                           */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.dmac_repository (
	stamp		TIMESTAMP			NOT NULL DEFAULT CURRENT_TIMESTAMP,
	user_id		INTEGER UNSIGNED	NOT NULL,
	order_id	INTEGER UNSIGNED	NULL DEFAULT NULL,
	coupon_id	INTEGER UNSIGNED	NULL DEFAULT NULL,
	coins		SMALLINT SIGNED	NOT NULL DEFAULT 0,

	INDEX idx_user_id (user_id)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;

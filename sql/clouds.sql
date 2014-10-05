DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  List of clouds.                                                           */
/*                                                                            */
/******************************************************************************/
CREATE TABLE IF NOT EXISTS cloud_bender.clouds (
	hash_id					INTEGER UNSIGNED	NOT NULL,
	soa_id					INTEGER UNSIGNED	NOT NULL,
	bind_file_id			INTEGER UNSIGNED	NULL DEFAULT NULL,
	zone_file_id			INTEGER UNSIGNED	NULL DEFAULT NULL,
	journal_file_id			INTEGER UNSIGNED	NULL DEFAULT NULL,
	capacity				SMALLINT UNSIGNED	NOT NULL,
	activated				BOOLEAN			NOT NULL DEFAULT FALSE,
	confirmed				BOOLEAN			NOT NULL DEFAULT FALSE,
	need_dns_revalidation	BOOLEAN			NOT NULL DEFAULT FALSE,

	UNIQUE KEY idx_hash_id (hash_id),
	UNIQUE KEY idx_soa_id (soa_id),
	KEY idx_need_dns_revalidation (need_dns_revalidation),
	KEY idx_activated_confirmed (activated, confirmed)
)
ENGINE = InnoDB ROW_FORMAT = REDUNDANT
DEFAULT CHARSET = utf8;

/******************************************************************************/
/*                                                                            */
/******************************************************************************/
DROP PROCEDURE IF EXISTS cloud_bender.activate_cloud;
CREATE PROCEDURE cloud_bender.activate_cloud (
	IN $activation_id		INTEGER UNSIGNED,
	IN $domain_id			INTEGER UNSIGNED,
	IN $cloud_name			CHAR(64) CHARACTER SET utf8)

NOT DETERMINISTIC
MODIFIES SQL DATA
BEGIN
	DECLARE $user_id		INTEGER UNSIGNED;
	DECLARE $hash_id		INTEGER UNSIGNED;
	DECLARE $soa_id		INTEGER UNSIGNED;
	DEClARE $capacity		SMALLINT UNSIGNED;

	/*
	 * First get user id.
	 */
	SELECT user_id
	FROM cloud_bender.hash_activations
		USE INDEX (PRIMARY)
	WHERE activation_id = $activation_id
	INTO $user_id;

	/*
	 * 
	 */
	SELECT joomla_virtuemart_product_customfields.custom_value
	FROM cloud_bender.hash_activations
		USE INDEX (PRIMARY)
	JOIN cloud_joomla.joomla_virtuemart_order_items
		USE INDEX (PRIMARY)
		ON virtuemart_order_item_id = order_item_id
	JOIN cloud_joomla.joomla_virtuemart_product_customfields
		USE INDEX (idx_virtuemart_product_id)
		USING (virtuemart_product_id)
	JOIN cloud_joomla.joomla_virtuemart_customs
		USE INDEX (PRIMARY)
		USING (virtuemart_custom_id)
	WHERE activation_id = $activation_id
	  AND custom_title LIKE "HOSTS"
	INTO $capacity;

	/*
	 * Create a new HASH.
	 */
	SET $hash_id = cloud_bender.create_hash($user_id, $domain_id, "CLD", $cloud_name);

	/*
	 * For each cloud there should be a corresponding SOA record entry.
	 * We create one and set customer e-mail address as admin contact address.
	 */
	INSERT INTO cloud_bender.soas (email)
	SELECT email
	FROM cloud_bender.customers
	WHERE user_id = $user_id;

	SET $soa_id = LAST_INSERT_ID();

	/*
	 * Create a new cloud.
	 */
	INSERT LOW_PRIORITY
	INTO cloud_bender.clouds (hash_id, soa_id, capacity)
	VALUES ($hash_id, $soa_id, $capacity);

	/*
	 * And activate newly created hash.
	 */
	CALL cloud_bender.activate_hash($activation_id, $hash_id);

	CALL cloud_bender.schedule("DEFINE_CLOUD", $hash_id, 0);
END;

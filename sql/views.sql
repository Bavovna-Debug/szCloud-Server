DELIMITER //

/******************************************************************************/
/*                                                                            */
/*  Simplify generation of a list of Joomla users which belong                */
/*  to a "Cloud" group.                                                       */
/*                                                                            */
/******************************************************************************/
DROP VIEW IF EXISTS cloud_bender.customers;
CREATE VIEW cloud_bender.customers AS
SELECT u.id AS user_id, name AS customer_name, username, password,
       block AS blocked, (LENGTH(activation) = 0) AS activated,
       email, registerDate AS registered
FROM cloud_joomla.joomla_users AS u,
     cloud_joomla.joomla_usergroups AS g,
     cloud_joomla.joomla_user_usergroup_map AS m
WHERE m.user_id = u.id
  AND m.group_id = g.id
  AND g.title = "Cloud"
ORDER BY u.name;


/******************************************************************************/
/*                                                                            */
/*  Produce full DNS names for clouds.                                        */
/*                                                                            */
/******************************************************************************/
/*
DROP VIEW IF EXISTS cloud_bender.full_cloud_name;
CREATE VIEW cloud_bender.full_cloud_name AS
SELECT c.hash_id AS cloud_id, d.hash_id AS domain_id,
	   c.name AS cloud_name, d.name AS domain_name,
	   CONCAT(c.name, '.', d.name) AS full_name
FROM cloud_bender.hash_repository AS c,
     cloud_bender.hash_repository AS d
WHERE c.object_type = 'CLD'
  AND d.object_type = 'DOM'
  AND c.parent_id IS NOT NULL
  AND c.parent_id = d.hash_id;
*/


/******************************************************************************/
/*                                                                            */
/*  Produce full DNS names for hosts.                                         */
/*                                                                            */
/******************************************************************************/
/*
DROP VIEW IF EXISTS cloud_bender.full_host_name;
CREATE VIEW cloud_bender.full_host_name AS
SELECT h.hash_id AS host_id, c.hash_id AS cloud_id, d.hash_id AS domain_id,
	   h.name AS host_name, c.name AS cloud_name, d.name AS domain_name,
       CONCAT(h.name, '.', c.name, '.', d.name) AS full_name
FROM cloud_bender.hash_repository AS h,
     cloud_bender.hash_repository AS c,
     cloud_bender.hash_repository AS d
WHERE h.object_type = 'HST'
  AND c.object_type = 'CLD'
  AND d.object_type = 'DOM'
  AND h.parent_id IS NOT NULL
  AND c.parent_id IS NOT NULL
  AND h.parent_id = c.hash_id
  AND c.parent_id = d.hash_id;
*/

/* Oracle table definitions for
   Gerty::Netconf::Postprocess::JunOSDBStore
*/



/*  ***********  MAC count history  ************ */

CREATE TABLE JNX_VPLS_MAC_COUNT_HISTORY
(
  HOSTNAME              VARCHAR2(150) NOT NULL,
  INSTANCE_NAME         VARCHAR2(150) NOT NULL,
  INTERFACE_NAME        VARCHAR2(60) DEFAULT NULL,
  VLAN_NUM              NUMBER(11) DEFAULT NULL,
  MAC_COUNT             NUMBER(11) NOT NULL,
  UPDATE_TS             DATE NOT NULL
);

CREATE INDEX JNX_VPLS_MAC_COUNT_HISTORY_I01
  ON JNX_VPLS_MAC_COUNT_HISTORY(HOSTNAME, INSTANCE_NAME, INTERFACE_NAME);

CREATE INDEX JNX_VPLS_MAC_COUNT_HISTORY_I02
  ON JNX_VPLS_MAC_COUNT_HISTORY(INSTANCE_NAME);

CREATE INDEX JNX_VPLS_MAC_COUNT_HISTORY_I03
  ON JNX_VPLS_MAC_COUNT_HISTORY(VLAN_NUM);

CREATE INDEX JNX_VPLS_MAC_COUNT_HISTORY_I04
  ON JNX_VPLS_MAC_COUNT_HISTORY(UPDATE_TS);


/* ***********  Average counts over past 3 days  ************ */

CREATE VIEW JNX_VPLS_MAC_COUNT_AVG3DAYS AS
SELECT
  HOSTNAME,
  INSTANCE_NAME,
  INTERFACE_NAME,
  VLAN_NUM,
  AVG(MAC_COUNT) AS MAC_COUNT
FROM JNX_VPLS_MAC_COUNT_HISTORY
WHERE UPDATE_TS > SYSDATE - 3
GROUP BY HOSTNAME, INSTANCE_NAME, INTERFACE_NAME, VLAN_NUM;


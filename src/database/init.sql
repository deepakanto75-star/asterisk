-- Create the database if it doesn't already exist
CREATE DATABASE IF NOT EXISTS asterisk_db;
USE asterisk_db;

-- Asterisk's standard CDR table (can be kept for reference or removed)
CREATE TABLE cdr (
    id INT(11) NOT NULL AUTO_INCREMENT,
    calldate DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    clid VARCHAR(80) NOT NULL DEFAULT '',
    src VARCHAR(80) NOT NULL DEFAULT '',
    dst VARCHAR(80) NOT NULL DEFAULT '',
    dcontext VARCHAR(80) NOT NULL DEFAULT '',
    channel VARCHAR(80) NOT NULL DEFAULT '',
    dstchannel VARCHAR(80) NOT NULL DEFAULT '',
    lastapp VARCHAR(80) NOT NULL DEFAULT '',
    lastdata VARCHAR(80) NOT NULL DEFAULT '',
    duration INT(11) NOT NULL DEFAULT '0',
    billsec INT(11) NOT NULL DEFAULT '0',
    disposition VARCHAR(45) NOT NULL DEFAULT '',
    amaflags INT(11) NOT NULL DEFAULT '0',
    accountcode VARCHAR(20) NOT NULL DEFAULT '',
    uniqueid VARCHAR(32) NOT NULL DEFAULT '',
    userfield VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (id)
);

-- IMPROVEMENT: Our new custom table for richer call details and recordings
CREATE TABLE call_logs (
    id INT(11) NOT NULL AUTO_INCREMENT,
    uniqueid VARCHAR(32) NOT NULL UNIQUE,
    call_start DATETIME NOT NULL,
    call_end DATETIME,
    caller_id VARCHAR(80) NOT NULL,
    destination VARCHAR(80) NOT NULL,
    duration INT(11) DEFAULT 0,
    disposition VARCHAR(45),
    recording_path VARCHAR(255),
    PRIMARY KEY (id)
);

ALTER TABLE call_logs ADD dialstatus VARCHAR(45) DEFAULT NULL;

-- Grant privileges to the user that Asterisk and Flask will use
GRANT ALL PRIVILEGES ON asterisk_db.* TO 'asterisk_user'@'%' IDENTIFIED BY 'asterisk_password';
FLUSH PRIVILEGES;
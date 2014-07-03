/*
  Commands to create PostgreSQL database

  Edit this, then run using:

    psql -U postgres template1 -f gnudip.pgsql
 
  Or do it by hand using this to copy and paste.
*/

/*************************************/
/* create GnuDIP user */
create user gnudip password 'gnudippass';
/*          ^GnuDIP user     ^GnuDIP password */

/*************************************/
/* create GnuDIP database */
create database gnudip2;
/*              ^GnuDIP database */

/*************************************/
/* use GnuDIP database */
\c gnudip2

/*************************************/
/* domains */
create sequence domains_id;
create table domains (
  id         integer default nextval('domains_id') not null,
  domain     varchar(50),
  changepass varchar(5),
  addself    varchar(5),
  primary key (id)
);
grant select, insert, update, delete on table domains_id to gnudip;
grant select, insert, update, delete on table domains    to gnudip;
/*                                                          ^GnuDIP user */

/*************************************/
/* globalprefs */
create sequence globalprefs_id;
create table globalprefs (
  id    integer default nextval('globalprefs_id') not null,
  param varchar(30),
  value varchar(255),
  primary key (id));
grant select, insert, update, delete on table globalprefs_id to gnudip;
grant select, insert, update, delete on table globalprefs    to gnudip;
/*                                                              ^GnuDIP user */

/*************************************/
/* users */
create sequence users_id;
create table users (
  id           integer default nextval('users_id') not null,
  username     varchar(20) default '' not null,
  password     varchar(32),
  domain       varchar(50) default '' not null,
  email        varchar(50),
  forwardurl   varchar(60),
  updated_secs int,
  updated      varchar(19),
  level        varchar(5) default 'USER' not null,
  currentip    varchar(15),
  autourlon    varchar(5),
  MXvalue      varchar(60),
  MXbackup     varchar(3) default 'NO' not null,
  wildcard     varchar(3) default 'NO' not null,
  allowwild    varchar(3) default 'NO' not null,
  allowmx      varchar(3) default 'NO' not null,
  primary key (id)
);
create index users_domain   on users (domain);
create index users_username on users (username);
grant select, insert, update, delete on table users_id to gnudip;
grant select, insert, update, delete on table users    to gnudip;
/*                                                        ^GnuDIP user */


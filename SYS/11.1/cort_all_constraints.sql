/*
CORT - Oracle server-side tool allowing to change tables similar to create or replace command

Copyright (C) 2013-2014  Softcraft Ltd - Rustam Kafarov

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

create or replace view CORT_ALL_CONSTRAINTS
    (OWNER, CONSTRAINT_NAME, CONSTRAINT_TYPE,
     TABLE_NAME, SEARCH_CONDITION, R_OWNER,
     R_CONSTRAINT_NAME, DELETE_RULE, STATUS,
     DEFERRABLE, DEFERRED, VALIDATED, GENERATED,
     BAD, RELY, LAST_CHANGE, INDEX_OWNER, INDEX_NAME,
     INVALID, VIEW_RELATED)
as
select ou.name, oc.name,
       decode(c.type#, 1, 'C', 2, 'P', 3, 'U',
              4, 'R', 5, 'V', 6, 'O', 7,'C', 8, 'H', 9, 'F',
              10, 'F', 11, 'F', 12, 'S', 13, 'F', 14, 'S', 15, 'S', 16, 'S',
              17, 'S', '?'),
       o.name, c.condition, ru.name, rc.name,
       decode(c.type#, 4,
              decode(c.refact, 1, 'CASCADE', 2, 'SET NULL', 'NO ACTION'),
              NULL),
       decode(c.type#, 5, 'ENABLED',
              decode(c.enabled, NULL, 'DISABLED', 'ENABLED')),
       decode(bitand(c.defer, 1), 1, 'DEFERRABLE', 'NOT DEFERRABLE'),
       decode(bitand(c.defer, 2), 2, 'DEFERRED', 'IMMEDIATE'),
       decode(bitand(c.defer, 4), 4, 'VALIDATED', 'NOT VALIDATED'),
       decode(bitand(c.defer, 8), 8, 'GENERATED NAME', 'USER NAME'),
       decode(bitand(c.defer,16),16, 'BAD', null),
       decode(bitand(c.defer,32),32, 'RELY', null),
       c.mtime,
       decode(c.type#, 2, ui.name, 3, ui.name, null),
       decode(c.type#, 2, oi.name, 3, oi.name, null),
       decode(bitand(c.defer, 256), 256,
              decode(c.type#, 4,
                     case when (bitand(c.defer, 128) = 128
                                or o.status in (3, 5)
                                or ro.status in (3, 5)) then 'INVALID'
                          else null end,
                     case when (bitand(c.defer, 128) = 128
                                or o.status in (3, 5)) then 'INVALID'
                          else null end
                    ),
              null),
       decode(bitand(c.defer, 256), 256, 'DEPEND ON VIEW', null)
from sys.con$ oc, sys.con$ rc, sys.user$ ou, sys.user$ ru,
     sys."_CURRENT_EDITION_OBJ" ro, sys."_CURRENT_EDITION_OBJ" o, sys.cdef$ c,
     sys.obj$ oi, sys.user$ ui
where oc.owner# = ou.user#
  and oc.con# = c.con#
  and c.obj# = o.obj#
  and c.type# != 8
  and c.type# != 12       /* don't include log groups */
  and c.rcon# = rc.con#(+)
  and c.enabled = oi.obj#(+)
  and oi.owner# = ui.user#(+) -- bug fix
  and rc.owner# = ru.user#(+)
  and c.robj# = ro.obj#(+)
  and (o.owner# = userenv('SCHEMAID')
       or o.obj# in (select obj#
                     from sys.objauth$
                     where grantee# in ( select kzsrorol
                                         from x$kzsro
                                       )
                    )
        or /* user has system privileges */
          exists (select null from v$enabledprivs
                  where priv_number in (-45 /* LOCK ANY TABLE */,
                                        -47 /* SELECT ANY TABLE */,
                                        -48 /* INSERT ANY TABLE */,
                                        -49 /* UPDATE ANY TABLE */,
                                        -50 /* DELETE ANY TABLE */)
                  )
      )
/
comment on table CORT_ALL_CONSTRAINTS is
'Constraint definitions on accessible tables'
/
comment on column CORT_ALL_CONSTRAINTS.OWNER is
'Owner of the table'
/
comment on column CORT_ALL_CONSTRAINTS.CONSTRAINT_NAME is
'Name associated with constraint definition'
/
comment on column CORT_ALL_CONSTRAINTS.CONSTRAINT_TYPE is
'Type of constraint definition'
/
comment on column CORT_ALL_CONSTRAINTS.TABLE_NAME is
'Name associated with table with constraint definition'
/
comment on column CORT_ALL_CONSTRAINTS.SEARCH_CONDITION is
'Text of search condition for table check'
/
comment on column CORT_ALL_CONSTRAINTS.R_OWNER is
'Owner of table used in referential constraint'
/
comment on column CORT_ALL_CONSTRAINTS.R_CONSTRAINT_NAME is
'Name of unique constraint definition for referenced table'
/
comment on column CORT_ALL_CONSTRAINTS.DELETE_RULE is
'The delete rule for a referential constraint'
/
comment on column CORT_ALL_CONSTRAINTS.STATUS is
'Enforcement status of constraint - ENABLED or DISABLED'
/
comment on column CORT_ALL_CONSTRAINTS.DEFERRABLE is
'Is the constraint deferrable - DEFERRABLE or NOT DEFERRABLE'
/
comment on column CORT_ALL_CONSTRAINTS.DEFERRED is
'Is the constraint deferred by default -  DEFERRED or IMMEDIATE'
/
comment on column CORT_ALL_CONSTRAINTS.VALIDATED is
'Was this constraint system validated? -  VALIDATED or NOT VALIDATED'
/
comment on column CORT_ALL_CONSTRAINTS.GENERATED is
'Was the constraint name system generated? -  GENERATED NAME or USER NAME'
/
comment on column CORT_ALL_CONSTRAINTS.BAD is
'Creating this constraint should give ORA-02436.  Rewrite it before 2000 AD.'
/
comment on column CORT_ALL_CONSTRAINTS.RELY is
'If set, this flag will be used in optimizer'
/
comment on column CORT_ALL_CONSTRAINTS.LAST_CHANGE is
'The date when this column was last enabled or disabled'
/
comment on column CORT_ALL_CONSTRAINTS.INDEX_OWNER is
'The owner of the index used by this constraint'
/
comment on column CORT_ALL_CONSTRAINTS.INDEX_NAME is
'The index used by this constraint'
/
grant select on CORT_ALL_CONSTRAINTS to public with grant option
/

create or replace public synonym CORT_ALL_CONSTRAINTS for CORT_ALL_CONSTRAINTS
/

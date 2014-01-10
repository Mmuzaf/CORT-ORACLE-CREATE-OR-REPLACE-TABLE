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

create or replace view CORT_ALL_LOB_TEMPLATES
  (USER_NAME, TABLE_NAME, LOB_COL_NAME, SUBPARTITION_NAME, LOB_SEGMENT_NAME, 
  TABLESPACE_NAME)
as
select u.name, o.name, decode(bitand(c.property, 1), 1, ac.name, c.name), 
       st.spart_name, lst.lob_spart_name, ts.name
from sys.obj$ o, sys.defsubpart$ st, sys.defsubpartlob$ lst, sys.ts$ ts, 
     sys.col$ c, sys.attrcol$ ac, sys.user$ u
where o.obj# = lst.bo# and st.bo# = lst.bo# and 
      st.spart_position =  lst.spart_position and 
      lst.lob_spart_ts# = ts.ts#(+) and c.obj# = lst.bo# and 
      c.intcol# = lst.intcol# and lst.intcol# = ac.intcol#(+) and 
      lst.bo# = ac.obj#(+) and -- bug fix 
      o.owner# = u.user# and
      o.subname IS NULL and
      o.namespace = 1 and o.remoteowner IS NULL and o.linkname IS NULL and
      (o.owner# = userenv('SCHEMAID') or
       o.obj# in (select oa.obj# from sys.objauth$ oa 
                  where grantee# in ( select kzsrorol from x$kzsro )) or
       exists (select null from v$enabledprivs
               where priv_number in (-45 /* LOCK ANY TABLE */,
                                     -47 /* SELECT ANY TABLE */,
                                     -48 /* INSERT ANY TABLE */,
                                     -49 /* UPDATE ANY TABLE */,
                                     -50 /* DELETE ANY TABLE */)))
/
create or replace public synonym CORT_ALL_LOB_TEMPLATES for CORT_ALL_LOB_TEMPLATES
/
grant select on CORT_ALL_LOB_TEMPLATES to PUBLIC with grant option
/

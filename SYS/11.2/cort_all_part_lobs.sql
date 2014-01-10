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

create or replace view CORT_ALL_PART_LOBS 
  (TABLE_OWNER, TABLE_NAME, COLUMN_NAME, LOB_NAME, LOB_INDEX_NAME, DEF_CHUNK,
   DEF_PCTVERSION, DEF_CACHE, DEF_IN_ROW,
   DEF_TABLESPACE_NAME, DEF_INITIAL_EXTENT, DEF_NEXT_EXTENT, DEF_MIN_EXTENTS, 
   DEF_MAX_EXTENTS, 
   DEF_MAX_SIZE, DEF_RETENTION, DEF_MINRET,
   DEF_PCT_INCREASE, DEF_FREELISTS, DEF_FREELIST_GROUPS,
   DEF_LOGGING, DEF_BUFFER_POOL, DEF_FLASH_CACHE, DEF_CELL_FLASH_CACHE,
   DEF_ENCRYPT, DEF_COMPRESS, 
   DEF_DEDUPLICATE, DEF_SECUREFILE)
as 
select u.name, 
       o.name,
       decode(bitand(c.property, 1), 1, a.name, c.name),
       lo.name, 
       io.name,
       plob.defchunk * ts.blocksize, -- bug fix
       plob.defpctver$,
       decode(bitand(plob.defflags, 795), 1, 'NO', 2, 'NO', 8, 'CACHEREADS',
                                         16, 'CACHEREADS', 256, 'YES', 512, 
                                         'YES', 'YES'),       
       decode(plob.defpro, 0, 'NO', 2048, 'NO', 'YES'),
       ts.name,
       decode(plob.definiexts, NULL, 'DEFAULT', plob.definiexts),
       decode(plob.defextsize, NULL, 'DEFAULT', plob.defextsize),
       decode(plob.defminexts, NULL, 'DEFAULT', plob.defminexts),
       decode(plob.defmaxexts, NULL, 'DEFAULT', plob.defmaxexts),
       decode(plob.defmaxsize, NULL, 'DEFAULT', plob.defmaxsize),
       decode(plob.defretention, NULL, 'DEFAULT',
       decode(plob.defretention,  0, 'NONE', 1, 'AUTO', 2, 'MIN', 3, 'MAX',
                     4, 'DEFAULT', 'INVALID')),
       decode(plob.defmintime,  NULL, 'DEFAULT', plob.defmintime),
       decode(plob.defextpct,  NULL, 'DEFAULT', plob.defextpct),
       decode(plob.deflists,   NULL, 'DEFAULT', plob.deflists),
       decode(plob.defgroups,  NULL, 'DEFAULT', plob.defgroups),
       decode(bitand(plob.defflags, 790), 0,'NONE', 4,'YES', 2,'NO',  
                                        16, 'NO', 256, 'NO', 512, 'YES', 'UNKNOWN'),
       decode(bitand(plob.defbufpool, 3), 1, 'KEEP', 2, 'RECYCLE', 'DEFAULT'),
       decode(bitand(plob.defbufpool, 12)/4, 1, 'KEEP', 2, 'NONE', 'DEFAULT'),
       decode(bitand(plob.defbufpool, 48)/16, 1, 'KEEP', 2, 'NONE', 'DEFAULT'),
       decode(bitand(plob.defflags,4096), 4096, 'YES',
                     decode(bitand(plob.defpro,2048), 2048, 'NO', 'NONE')),
       decode(bitand(plob.defflags,57344), 8192, 'LOW', 16384, 'MEDIUM',
              32768, 'HIGH',
              decode(bitand(plob.defpro,2048), 2048, 'NO', 'NONE')),
       decode(bitand(plob.defflags,458752), 65536, 'LOB', 131072, 'OBJECT',
              327680, 'LOB VALIDATE', 393216, 'OBJECT VALIDATE',
              decode(bitand(plob.defpro,2048), 2048, 'NO', 'NONE')),
       decode(bitand(plob.defpro,2048), 2048, 'YES', 'NO')
from   sys.obj$ o, sys.col$ c, sys.lob$ l, sys.partlob$ plob, 
       sys.obj$ lo, sys.obj$ io, sys.ts$ ts, sys.user$ u, attrcol$ a
where o.owner# = u.user#
  and o.obj# = c.obj#
  and c.obj# = l.obj#
  and c.intcol# = l.intcol#
  and l.lobj# = lo.obj#
  and l.ind# = io.obj#
  and l.lobj# = plob.lobj#
  and plob.defts# = ts.ts# (+)
  and bitand(c.property,32768) != 32768           /* not unused column */
  and c.obj# = a.obj#(+) and c.intcol# = a.intcol#(+)
  and o.namespace = 1 and o.remoteowner IS NULL and o.linkname IS NULL
  and o.subname IS NULL and lo.subname IS NULL
  and lo.namespace = 8 and lo.remoteowner IS NULL and lo.linkname IS NULL 
  and ((o.owner# = userenv('SCHEMAID') and lo.owner# = userenv('SCHEMAID'))
       or o.obj# in
            (select oa.obj#
             from sys.objauth$ oa
             where grantee# in ( select kzsrorol
                                 from x$kzsro
                               ) 
            )
       or exists (select null from v$enabledprivs
                  where priv_number in (-45 /* LOCK ANY TABLE */,
                                        -47 /* SELECT ANY TABLE */,
                                        -48 /* INSERT ANY TABLE */,
                                        -49 /* UPDATE ANY TABLE */,
                                        -50 /* DELETE ANY TABLE */)
                 )
      )
/ 
create or replace public synonym CORT_ALL_PART_LOBS for CORT_ALL_PART_LOBS 
/
grant select on CORT_ALL_PART_LOBS to PUBLIC with grant option
/

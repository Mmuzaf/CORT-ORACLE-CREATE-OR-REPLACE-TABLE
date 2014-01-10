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

create or replace view CORT_ALL_LOB_PARTITIONS 
  (TABLE_OWNER, TABLE_NAME, COLUMN_NAME, LOB_NAME, 
   PARTITION_NAME, LOB_PARTITION_NAME, LOB_INDPART_NAME, PARTITION_POSITION, 
   COMPOSITE, CHUNK, PCTVERSION, CACHE, IN_ROW,
   TABLESPACE_NAME, INITIAL_EXTENT, NEXT_EXTENT, MIN_EXTENTS, 
   MAX_EXTENTS, MAX_SIZE, RETENTION, MINRETENTION, 
   PCT_INCREASE, FREELISTS, FREELIST_GROUPS,
   LOGGING, BUFFER_POOL, ENCRYPT, COMPRESSION, DEDUPLICATION, SECUREFILE)
as 
select u.name,
       o.name,
       decode(bitand(c.property, 1), 1, a.name, c.name),
       lo.name,
       po.subname,
       lpo.subname,
       lipo.subname,
       lf.frag#,
       'NO',
       lf.chunk * ts.blocksize,
       lf.pctversion$,
       decode(bitand(lf.fragflags, 795), 1, 'NO', 2, 'NO', 8, 'CACHEREADS',
                                         16, 'CACHEREADS', 256, 'YES', 512, 
                                         'YES', 'YES'),
       decode(lf.fragpro, 0, 'NO', 2048, 'NO', 'YES'),
       ts.name,
       to_char(s.iniexts * ts.blocksize), 
       to_char(s.extsize * ts.blocksize),
       to_char(s.minexts),
       to_char(s.maxexts),
       to_char(decode(bitand(s.spare1, 4194304), 4194304, bitmapranges, NULL)),
       decode(bitand(s.spare1, 2097152), 2097152,
              decode(s.lists, 0, 'NONE', 1, 'AUTO', 2, 'MIN', 3, 'MAX',
                     4, 'DEFAULT', 'INVALID'), NULL),
       to_char(decode(bitand(s.spare1, 2097152), 2097152, s.groups, NULL)), 
       to_char(decode(bitand(ts.flags, 3), 1, to_number(NULL),s.extpct)),
       to_char(decode(s.lists, 0, 1, s.lists)), 
       to_char(decode(s.groups, 0, 1, s.groups)),
       decode(bitand(lf.fragflags, 786), 2,'NO', 16, 'NO', 256, 'NO', 512,
                                           'YES', 'YES'), 
       decode(s.cachehint, 0, 'DEFAULT', 1, 'KEEP', 2, 'RECYCLE', NULL),
       decode(bitand(lf.fragflags,4096), 4096, 'YES',
              decode(bitand(lf.fragpro,2048), 2048, 'NO', 'NONE')),
       decode(bitand(lf.fragflags,57344), 8192, 'LOW', 16384, 'MEDIUM',
              32768, 'HIGH',
              decode(bitand(lf.fragpro,2048), 2048, 'NO', 'NONE')),
       decode(bitand(lf.fragflags,458752), 65536, 'LOB', 131072, 'OBJECT',
              327680, 'LOB VALIDATE', 393216, 'OBJECT VALIDATE',
              decode(bitand(lf.fragpro,2048), 2048, 'NO', 'NONE')),
       decode(bitand(lf.fragpro,2048), 2048, 'YES', 'NO')
from   sys.obj$ o, sys.col$ c, 
       sys.lob$ l, sys.obj$ lo, 
       sys.lobfragv$ lf, sys.obj$ lpo, 
       sys.obj$ po, sys.obj$ lipo, 
       sys.partobj$ pobj, sys.tab$ t,
       sys.ts$ ts, sys.seg$ s, sys.user$ u, attrcol$ a
where o.owner# = u.user#
  and pobj.obj# = o.obj#
  and o.obj# = t.obj#
  and bitand(t.trigflag, 1073741824) != 1073741824
  and mod(pobj.spare2, 256) = 0
  and o.obj# = c.obj#
  and c.obj# = l.obj#
  and c.intcol# = l.intcol#
  and l.lobj# = lo.obj#
  and l.lobj# = lf.parentobj#
  and lf.tabfragobj# = po.obj#
  and lf.fragobj# = lpo.obj#
  and lf.indfragobj# = lipo.obj#
  and lf.ts# = s.ts#
  and lf.file# = s.file#
  and lf.block# = s.block#
  and lf.ts# = ts.ts#
  and bitand(c.property,32768) != 32768           /* not unused column */
  and c.obj# = a.obj#(+) and c.intcol# = a.intcol#(+)
  and o.namespace = 1 and o.remoteowner IS NULL and o.linkname IS NULL
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
union all
select u.name,
       o.name,
       decode(bitand(c.property, 1), 1, a.name, c.name),
       lo.name,
       po.subname,
       lpo.subname,
       lipo.subname,
       lcp.part#,
       'YES',
       lcp.defchunk * ts.blocksize, -- bug fix
       lcp.defpctver$,
       decode(bitand(lcp.defflags, 795), 1, 'NO', 2, 'NO', 8, 'CACHEREADS',
                                         16, 'CACHEREADS', 256, 'YES', 512, 
                                         'YES', 'YES'),
       decode(lcp.defpro, 0, 'NO', 2048, 'NO', 'YES'),
       ts.name,
       decode(lcp.definiexts, NULL, 'DEFAULT', lcp.definiexts),
       decode(lcp.defextsize, NULL, 'DEFAULT', lcp.defextsize),
       decode(lcp.defminexts, NULL, 'DEFAULT', lcp.defminexts),
       decode(lcp.defmaxexts, NULL, 'DEFAULT', lcp.defmaxexts),
       decode(lcp.defmaxsize, NULL, 'DEFAULT', lcp.defmaxsize),
       decode(lcp.defretention, NULL, 'DEFAULT',
       decode(lcp.defretention,  0, 'NONE', 1, 'AUTO', 2, 'MIN', 3, 'MAX',
                     4, 'DEFAULT', 'INVALID')),
       decode(lcp.defmintime, NULL, 'DEFAULT', lcp.defmintime),
       decode(lcp.defextpct,  NULL, 'DEFAULT', lcp.defextpct),
       decode(lcp.deflists,   NULL, 'DEFAULT', lcp.deflists),
       decode(lcp.defgroups,  NULL, 'DEFAULT', lcp.defgroups),
       decode(bitand(lcp.defflags, 790), 0,'NONE', 4,'YES', 2,'NO',
                                  16, 'NO', 256, 'NO', 512, 'YES', 'UNKNOWN'),
       decode(lcp.defbufpool, 0, 'DEFAULT', 1, 'KEEP', 2, 'RECYCLE', NULL),
       decode(bitand(lcp.defflags,4096), 4096, 'YES',
              decode(bitand(lcp.defpro,2048), 2048, 'NO', 'NONE')),
       decode(bitand(lcp.defflags,57344), 8192, 'LOW', 16384, 'MEDIUM', 32768,
              'HIGH',
              decode(bitand(lcp.defpro,2048), 2048, 'NO', 'NONE')),
       decode(bitand(lcp.defflags,458752), 65536, 'LOB', 131072, 'OBJECT', 
              327680, 'LOB VALIDATE', 393216, 'OBJECT VALIDATE',
              decode(bitand(lcp.defpro,2048), 2048, 'NO', 'NONE')),
       decode(bitand(lcp.defpro,2048), 2048, 'YES', 'NO')
from   sys.obj$ o, sys.col$ c, 
       sys.lob$ l, sys.obj$ lo, 
       sys.lobcomppartv$ lcp, sys.obj$ lpo, 
       sys.obj$ po, sys.obj$ lipo, 
       sys.ts$ ts, partobj$ pobj, sys.tab$ t, sys.user$ u, attrcol$ a
where o.owner# = u.user#
  and pobj.obj# = o.obj#
  and o.obj# = t.obj#
  and bitand(t.trigflag, 1073741824) != 1073741824
  and mod(pobj.spare2, 256) != 0
  and o.obj# = c.obj#
  and c.obj# = l.obj#
  and c.intcol# = l.intcol#
  and l.lobj# = lo.obj#
  and l.lobj# = lcp.lobj#
  and lcp.tabpartobj# = po.obj#
  and lcp.partobj# = lpo.obj#
  and lcp.indpartobj# = lipo.obj#
  and lcp.defts# = ts.ts# (+)
  and bitand(c.property,32768) != 32768           /* not unused column */
  and c.obj# = a.obj#(+) and c.intcol# = a.intcol#(+)
  and o.namespace = 1 and o.remoteowner IS NULL and o.linkname IS NULL
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
create or replace public synonym CORT_ALL_LOB_PARTITIONS for CORT_ALL_LOB_PARTITIONS 
/
grant select on CORT_ALL_LOB_PARTITIONS to PUBLIC with grant option
/

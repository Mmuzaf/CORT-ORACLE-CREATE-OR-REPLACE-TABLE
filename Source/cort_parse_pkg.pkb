CREATE OR REPLACE PACKAGE BODY cort_parse_pkg
AS
 
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

/*
  Description: Parser utility for SQL commands and CORT hints 
  ----------------------------------------------------------------------------------------------------------------------     
  Release | Author(s)         | Comments
  ----------------------------------------------------------------------------------------------------------------------  
  14.01   | Rustam Kafarov    | Main functionality
  ----------------------------------------------------------------------------------------------------------------------  
*/

  TYPE gt_sql_positions IS RECORD(
    cort_param_start_pos       PLS_INTEGER,
    cort_param_end_pos         PLS_INTEGER,
    columns_start_pos          PLS_INTEGER,
    columns_end_pos            PLS_INTEGER,
    partitions_start_pos       PLS_INTEGER,
    partitions_end_pos         PLS_INTEGER
  );
  g_sql_positions  gt_sql_positions;


  TYPE gt_cort_text_rec IS RECORD(
    text_type      VARCHAR2(30),    -- Could be: COMMENT, LINE COMMENT, LITERAL, CORT PARAM, QUOTED NAME
    text           VARCHAR2(32767), -- original text  
    start_position PLS_INTEGER,     -- start position in original SQL text
    end_position   PLS_INTEGER      -- end position in original SQL text
  );

  TYPE gt_cort_text_arr IS TABLE OF gt_cort_text_rec INDEX BY PLS_INTEGER;

  TYPE gt_hint_arr      IS TABLE OF cort_hints%ROWTYPE INDEX BY VARCHAR2(30); 

  TYPE gt_replace_rec IS RECORD(
    object_type    VARCHAR2(30),
    object_name    VARCHAR2(30),
    start_pos      PLS_INTEGER, 
    end_pos        PLS_INTEGER,
    new_name       VARCHAR2(100)
  );
  
  TYPE gt_replace_arr IS TABLE OF gt_replace_rec INDEX BY PLS_INTEGER;
  
  g_normalized_sql        CLOB;
  g_cort_text_arr         gt_cort_text_arr;
  g_replace_arr           gt_replace_arr;
  g_temp_name_arr         arrays.gt_str_indx;

  g_params                cort_params_pkg.gt_params_rec;

  PROCEDURE debug(
    in_text  IN VARCHAR2
  )
  AS
  BEGIN
    cort_exec_pkg.debug(in_text);
  END debug;

  /*  Masks all reg exp key symbols */
  FUNCTION get_regexp_const(
    in_value          IN VARCHAR2
  )
  RETURN VARCHAR2
  AS
    TYPE t_regexp_keys  IS TABLE OF VARCHAR2(1);
    TYPE t_regexp_masks IS TABLE OF VARCHAR2(4);
    l_regexp_keys  t_regexp_keys  := t_regexp_keys(  '\',  '[',  ']',  '*',  '?',  '.',  '+',  '*',  '-',  '^',  '{',  '}',  '|',  '$',  '(',  ')');
    l_regexp_masks t_regexp_masks := t_regexp_masks('\\', '\[', '\]', '\*', '\?', '\.', '\+', '\*', '\-', '\^', '\{', '\}', '\|', '\$', '\(', '\)');
    l_value   VARCHAR2(32767);
  BEGIN
    l_value := in_value;
    FOR I IN 1..l_regexp_keys.COUNT LOOP
      l_value := REPLACE(l_value, l_regexp_keys(i), l_regexp_masks(i));
    END LOOP;
    RETURN l_value;
  END get_regexp_const;

  /* Return TRUE is given name is simple SQL name and doesnt require double quotes */
  FUNCTION is_simple_name(in_name IN VARCHAR2)
  RETURN BOOLEAN
  AS
  BEGIN
    RETURN REGEXP_LIKE(in_name, '^[A-Z][A-Z0-9_$#]{0,29}$');
  END is_simple_name;

  FUNCTION l_parse_only_sql(
    in_name  IN VARCHAR2,
    in_delim IN VARCHAR2 DEFAULT NULL
  )
  RETURN VARCHAR2
  AS
    l_regexp VARCHAR2(200);
  BEGIN
    IF is_simple_name(in_name) THEN
      l_regexp := '('||get_regexp_const(in_name)||')'||in_delim;
    ELSE
      l_regexp := '("'||get_regexp_const(in_name)||'")';
    END IF;
    RETURN l_regexp;
  END l_parse_only_sql;

  FUNCTION get_owner_name_regexp(
    in_name  IN VARCHAR2,
    in_owner IN VARCHAR2,
    in_delim IN VARCHAR2 DEFAULT NULL
  )
  RETURN VARCHAR2 
  AS
    l_regexp VARCHAR2(200);
  BEGIN
    IF is_simple_name(in_owner) THEN
      l_regexp := get_regexp_const(in_owner);
    ELSE
      l_regexp := '"'||get_regexp_const(in_owner)||'"';
    END IF;
    RETURN '('||l_regexp||'\s*\.\s*)?'||l_parse_only_sql(in_name, in_delim);
  END get_owner_name_regexp;

  /* Returns regular expression to find given constraint of gven type */
  FUNCTION get_column_regexp(
    in_column_rec  IN  cort_exec_pkg.gt_column_rec 
  )
  RETURN VARCHAR2
  AS
    TYPE t_type_exprs  IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR2(30);
    l_type_expr_arr       t_type_exprs;
    l_regexp              VARCHAR2(1000);
  BEGIN
    l_type_expr_arr('NUMBER') := '((NUMBER)|(INTEGER)|(INT)|(SMALLINT)|(DECIMAL)|(NUMERIC)|(DEC))';
    l_type_expr_arr('FLOAT') := '((FLOAT)|(REAL)|(DOUBLE\s+PRECISION))';
    l_type_expr_arr('BINARY_DOUBLE') := '((BINARY_DOUBLE)|(BINARY_FLOAT))';
    l_type_expr_arr('VARCHAR2') := '((VARCHAR2)|(VARCHAR)|(CHARACTER\s+VARYING)|(CHAR\s+VARYING))';
    l_type_expr_arr('CHAR') := '((CHAR)|(CHARACTER))';
    l_type_expr_arr('NVARCHAR2') := '((NVARCHAR2)|(NATIONAL\s+CHARACTER\s+VARYING)|(NATIONAL\s+CHAR\s+VARYING)|(NCHAR\s+VARYING))';
    l_type_expr_arr('NCHAR') := '((NCHAR)|(NATIONAL\s+CHARACTER)|(NATIONAL\s+CHAR))';
    l_type_expr_arr('TIMESTAMP') := '(TIMESTAMP(\([0-9]\))?)';
    l_type_expr_arr('TIMESTAMP WITH TIMEZONE') := '(TIMESTAMP\s*(\(\s*[0-9]\s*\))?\s*WITH\s+TIME\s+ZONE)';
    l_type_expr_arr('TIMESTAMP WITH LOCAL TIMEZONE') := '(TIMESTAMP\s*(\(\s*[0-9]\s*\))?\s+WITH\s+LOCAL\s+TIME\s+ZONE)';
    l_type_expr_arr('INTERVAL YEAR TO MONTH') := '(INTERVAL\s+YEAR\s*(\(\s*[0-9]\s*\))?\s+TO\s+MONTH)';
    l_type_expr_arr('RAW') := '(RAW\s*\(\s*[0-9]+\s*\))';

    l_regexp := '('||l_parse_only_sql(in_column_rec.column_name, '\s')||'\s*';
    IF in_column_rec.data_type_mod IS NOT NULL THEN
      l_regexp := l_regexp||get_regexp_const(in_column_rec.data_type_mod)||'\s+';
    END IF;
    
    IF in_column_rec.virtual_column = 'YES' THEN
      l_regexp := l_regexp||'(GENERATED\s+ALWAYS\s+)?AS)\W';
    ELSE 
      IF in_column_rec.data_type_owner IS NOT NULL THEN
        l_regexp := l_regexp||get_owner_name_regexp(in_column_rec.data_type, in_column_rec.data_type_owner)||')\W';
      ELSE
        IF l_type_expr_arr.EXISTS(in_column_rec.data_type) THEN
          l_regexp := l_regexp||l_type_expr_arr(in_column_rec.data_type)||')\W';
        ELSE
          l_regexp := l_regexp||get_regexp_const(in_column_rec.data_type)||')\W';
        END IF;
      END IF;
    END IF;
    RETURN l_regexp;
  END get_column_regexp;

  -- Returns position of close bracket - ) - ignoring all nested pairs of brackets ( ) and quoted SQL names
  FUNCTION get_closed_bracket(
    in_sql              IN CLOB,
    in_search_position  IN PLS_INTEGER -- Position AFTER open bracket
  )
  RETURN PLS_INTEGER
  AS
    l_search_pos         PLS_INTEGER;
    l_open_bracket_cnt   PLS_INTEGER;
    l_close_bracket_cnt  PLS_INTEGER;
    l_key_pos            PLS_INTEGER;
    l_key                VARCHAR2(1);
  BEGIN
    l_search_pos := in_search_position;
    l_open_bracket_cnt := 1;
    l_close_bracket_cnt := 0;
    LOOP
      l_key_pos := REGEXP_INSTR(in_sql, '\(|\)|"', l_search_pos, 1, 0);
      EXIT WHEN l_key_pos = 0 OR l_key_pos IS NULL
             OR l_open_bracket_cnt > 4000 OR l_close_bracket_cnt > 4000;
      l_key := SUBSTR(in_sql, l_key_pos, 1);
      CASE l_key
        WHEN '(' THEN
          l_open_bracket_cnt := l_open_bracket_cnt + 1;
        WHEN ')' THEN
          l_close_bracket_cnt := l_close_bracket_cnt + 1;
        WHEN '"' THEN
          l_key_pos := REGEXP_INSTR(in_sql, '"', l_search_pos, 1, 0);
      END CASE;
      IF l_open_bracket_cnt = l_close_bracket_cnt THEN
        RETURN l_key_pos;
      END IF;
      l_search_pos := l_key_pos + 1;
    END LOOP;
  END get_closed_bracket;


  PROCEDURE add_text(
    in_text_type IN VARCHAR2,
    in_text      IN VARCHAR2,
    in_start_pos IN PLS_INTEGER,
    in_end_pos   IN PLS_INTEGER
  )
  AS
    l_text_rec gt_cort_text_rec;
  BEGIN
    l_text_rec.text_type := in_text_type;
    l_text_rec.text := in_text;
    l_text_rec.start_position := in_start_pos;
    l_text_rec.end_position := in_end_pos;
    g_cort_text_arr(g_cort_text_arr.count+1) := l_text_rec;
  END add_text;

  -- find all entries for given name 
  FUNCTION find_substitable_name(
    in_object_type  IN VARCHAR2,
    in_object_name  IN VARCHAR2,
    in_new_name     IN VARCHAR2,
    in_pattern      IN VARCHAR2,
    in_search_pos   IN PLS_INTEGER DEFAULT 1,
    in_subexpr      IN PLS_INTEGER DEFAULT 0
  )
  RETURN PLS_INTEGER
  AS
    l_replace_rec gt_replace_rec;
    l_start_pos   PLS_INTEGER;
  BEGIN
--    dbms_output.put_line(in_pattern);
    l_start_pos := REGEXP_INSTR(g_normalized_sql, in_pattern, in_search_pos, 1, 0, null, in_subexpr);
    IF l_start_pos > 0 THEN 
      l_replace_rec.object_type := in_object_type;
      l_replace_rec.object_name := in_object_name;
      l_replace_rec.start_pos := l_start_pos;
      l_replace_rec.end_pos   := REGEXP_INSTR(g_normalized_sql, in_pattern, in_search_pos, 1, 1, null, in_subexpr);
--      dbms_output.put_line('start_pos = '||l_start_pos);
--      dbms_output.put_line('end_pos = '||l_replace_rec.end_pos);
--      dbms_output.put_line('replace str = '||substr(g_normalized_sql, l_start_pos, l_replace_rec.end_pos - l_start_pos));
      l_replace_rec.new_name  := in_new_name;
      g_replace_arr(l_start_pos) := l_replace_rec;
      g_temp_name_arr(in_object_type||':"'||in_new_name||'"') := in_object_name;
      RETURN l_replace_rec.end_pos;
    ELSE
      RETURN 0;
    END IF;
  END find_substitable_name;

  -- find all entries for given table name 
  PROCEDURE find_table_name(
    in_table_name  IN VARCHAR2,
    in_table_owner IN VARCHAR2,
    in_temp_name   IN VARCHAR2
  )
  AS
    l_pattern     VARCHAR2(1000);
    l_search_pos  PLS_INTEGER;
    l_save_pos    PLS_INTEGER;
  BEGIN
    -- find table declaration
    l_search_pos := 1;    
    l_pattern := '\WTABLE\s+'||get_owner_name_regexp(in_table_name, in_table_owner)||'(\s|\()';
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'TABLE',
                        in_object_name  => in_table_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 2
                      );
      EXIT WHEN l_search_pos = 0;              
    END LOOP;                
    -- find self references   
    l_search_pos := g_sql_positions.columns_start_pos;
    l_pattern := '\WREFERENCES\s+'||get_owner_name_regexp(in_table_name, in_table_owner)||'(\s|\()';
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'TABLE',
                        in_object_name  => in_table_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 2
                      );
      EXIT WHEN l_search_pos = 0;              
    END LOOP;                
    -- find create index statement   
    l_pattern := '\WON\s+'||get_owner_name_regexp(in_table_name, in_table_owner)||'(\s|\()';
    l_search_pos := g_sql_positions.columns_start_pos;
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'TABLE',
                        in_object_name  => in_table_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 2
                      );
      EXIT WHEN l_search_pos = 0;              
    END LOOP;                
  END find_table_name;

  -- find all entries for given constraint name 
  PROCEDURE find_constraint_name(
    in_constraint_name IN VARCHAR2,
    in_temp_name       IN VARCHAR2
  )
  AS
    l_pattern     VARCHAR2(1000);
    l_search_pos  PLS_INTEGER;
    l_replace_rec gt_replace_rec;
    l_start_pos   PLS_INTEGER;
  BEGIN
    l_search_pos := g_sql_positions.columns_start_pos;
    l_pattern := '\WCONSTRAINT\s+'||l_parse_only_sql(in_constraint_name, '\s')||'\s*((PRIMARY\s+KEY)|(UNIQUE)|(CHECK)|(FOREIGN\s+KEY))';
    debug(l_pattern);
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'CONSTRAINT',
                        in_object_name  => in_constraint_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 1
                      );
      debug('l_search_pos = '||l_search_pos);
      EXIT WHEN l_search_pos = 0;               
    END LOOP;                  
    l_search_pos := g_sql_positions.columns_end_pos;
    l_pattern := '\WPARTITION\s+BY\s+REFERENCE\s*\(\s*'||l_parse_only_sql(in_constraint_name)||'\s*\)';
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'CONSTRAINT',
                        in_object_name  => in_constraint_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 1
                      );
      EXIT WHEN l_search_pos = 0;               
    END LOOP;                  
  END find_constraint_name;

  -- find all entries for given constraint name 
  PROCEDURE find_log_group_name(
    in_log_group_name IN VARCHAR2,
    in_temp_name      IN VARCHAR2
  )
  AS
    l_pattern     VARCHAR2(1000);
    l_search_pos  PLS_INTEGER;
    l_replace_rec gt_replace_rec;
    l_start_pos   PLS_INTEGER;
  BEGIN
    l_search_pos := g_sql_positions.columns_start_pos;
    l_pattern := '\WSUPPLEMENTAL\s+LOG\s+GROUP\s+'||l_parse_only_sql(in_log_group_name, '\W');
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'LOG_GROUP',
                        in_object_name  => in_log_group_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 1
                      );
      EXIT WHEN l_search_pos = 0;               
    END LOOP;                  
  END find_log_group_name;
  
  -- find all entries for given constraint name 
  PROCEDURE find_index_name(
    in_index_name IN VARCHAR2,
    in_temp_name  IN VARCHAR2
  )
  AS
    l_pattern     VARCHAR2(1000);
    l_search_pos  PLS_INTEGER;
    l_replace_rec gt_replace_rec;
    l_start_pos   PLS_INTEGER;
  BEGIN
    l_search_pos := g_sql_positions.columns_start_pos;
    l_pattern := '\WOIDINDEX\s*'||l_parse_only_sql(in_index_name)||'\s*\(';
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'INDEX',
                        in_object_name  => in_index_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 1
                      );
      EXIT WHEN l_search_pos = 0;               
    END LOOP;                
    l_search_pos := g_sql_positions.columns_start_pos;
    l_pattern := '\WINDEX\s*'||l_parse_only_sql(in_index_name, '\W');
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'INDEX',
                        in_object_name  => in_index_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 1
                      );
      EXIT WHEN l_search_pos = 0;               
    END LOOP;                
  END find_index_name;
  

  -- find all entries for given lob column 
  PROCEDURE find_lob_segment_name(
    in_column_name  IN VARCHAR2,
    in_segment_name IN VARCHAR2,
    in_temp_name    IN VARCHAR2
  )
  AS
    l_pattern     VARCHAR2(1000);
    l_search_pos  PLS_INTEGER;
    l_replace_rec gt_replace_rec;
    l_start_pos   PLS_INTEGER;
  BEGIN
    l_search_pos := g_sql_positions.columns_end_pos;
    l_pattern := '\WLOB\s*\(\s*'||l_parse_only_sql(in_column_name)||'\s*\)\s+STORE\s+AS\s+(BASICFILE\s+|SECUREFILE\s+)?'||l_parse_only_sql(in_segment_name, '\W');
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'LOB',
                        in_object_name  => in_segment_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 3
                      );
      EXIT WHEN l_search_pos = 0;               
    END LOOP;                  
    l_search_pos := g_sql_positions.columns_end_pos;
    l_pattern := '\WSTORE\s+AS\s+(BASICFILE\s+|SECUREFILE\s+)?(LOB|CLOB|BINARY\s+XML)\s+'||l_parse_only_sql(in_segment_name, '\W');
    LOOP
      l_search_pos := find_substitable_name(
                        in_object_type  => 'LOB',
                        in_object_name  => in_segment_name,
                        in_new_name     => in_temp_name,
                        in_pattern      => l_pattern,
                        in_search_pos   => l_search_pos,
                        in_subexpr      => 3
                      );
      EXIT WHEN l_search_pos = 0;               
    END LOOP;                  
  END find_lob_segment_name;

  -- find all substitution entries 
  PROCEDURE find_all_substitutions(
    in_table_rec IN cort_exec_pkg.gt_table_rec
  )
  AS
    l_lob_rec   cort_exec_pkg.gt_lob_rec;
    l_indx      PLS_INTEGER; 
  BEGIN
    g_replace_arr.DELETE;
    g_temp_name_arr.DELETE;

    -- find all instances for table name
    find_table_name(
      in_table_name  => in_table_rec.table_name, 
      in_table_owner => in_table_rec.owner, 
      in_temp_name   => in_table_rec.rename_rec.temp_name
    );
    -- find all named constraints
    FOR i IN 1..in_table_rec.constraint_arr.COUNT LOOP
      IF in_table_rec.constraint_arr(i).generated = 'USER NAME' THEN
        find_constraint_name(
          in_constraint_name => in_table_rec.constraint_arr(i).constraint_name, 
          in_temp_name       => in_table_rec.constraint_arr(i).rename_rec.temp_name
        );
      END IF;  
    END LOOP;
    -- find all named log groups
    FOR i IN 1..in_table_rec.log_group_arr.COUNT LOOP
      IF in_table_rec.log_group_arr(i).generated = 'USER NAME' THEN
        find_log_group_name(
          in_log_group_name => in_table_rec.log_group_arr(i).log_group_name, 
          in_temp_name      => in_table_rec.log_group_arr(i).rename_rec.temp_name
        );
      END IF;  
    END LOOP;
    -- find all indexes 
    FOR i IN 1..in_table_rec.index_arr.COUNT LOOP
      IF in_table_rec.index_arr(i).rename_rec.generated = 'N' THEN
        find_index_name(
          in_index_name => in_table_rec.index_arr(i).index_name, 
          in_temp_name  => in_table_rec.index_arr(i).rename_rec.temp_name
        );
        IF NOT g_temp_name_arr.EXISTS('INDEX:"'||in_table_rec.index_arr(i).rename_rec.temp_name||'"') AND 
           in_table_rec.index_arr(i).constraint_name IS NOT NULL AND
           in_table_rec.constraint_indx_arr.EXISTS(in_table_rec.index_arr(i).constraint_name) 
        THEN
          l_indx := in_table_rec.constraint_indx_arr(in_table_rec.index_arr(i).constraint_name);
          IF g_temp_name_arr.EXISTS('CONSTRAINT:"'||in_table_rec.constraint_arr(l_indx).rename_rec.temp_name||'"') THEN
            g_temp_name_arr('INDEX:"'||in_table_rec.constraint_arr(l_indx).rename_rec.temp_name||'"') := in_table_rec.index_arr(i).index_name;
          END IF; 
        END IF;
      END IF;  
    END LOOP;
    -- find all named lob segments
    l_indx := in_table_rec.lob_arr.FIRST;
    WHILE l_indx IS NOT NULL LOOP
      -- for lob columns
      IF in_table_rec.lob_arr(l_indx).rename_rec.generated = 'N' THEN
        find_lob_segment_name(
          in_column_name  => in_table_rec.lob_arr(l_indx).column_name, 
          in_segment_name => in_table_rec.lob_arr(l_indx).lob_name, 
          in_temp_name    => in_table_rec.lob_arr(l_indx).rename_rec.temp_name
        );
      END IF;  
      l_indx := in_table_rec.lob_arr.NEXT(l_indx);
    END LOOP;
  END find_all_substitutions;
  
  /* Replaces all comments and string literals with blank symbols */
  PROCEDURE normalize_sql(
    in_sql            IN  CLOB
  )
  AS
    l_search_pos                PLS_INTEGER;
    l_key                       VARCHAR2(32767);
    l_key_start_pos             PLS_INTEGER;
    l_key_end_pos               PLS_INTEGER;
    l_expr_start_pos            PLS_INTEGER;
    l_expr_end_pos              PLS_INTEGER;
    l_expr_start_pattern        VARCHAR2(100);
    l_expr_end_pattern          VARCHAR2(100);
    l_expr_type                 VARCHAR2(30);
    l_expr                      CLOB;
    l_quoted_name               VARCHAR2(32767);
    l_expr_cnt                  PLS_INTEGER;
  BEGIN
    l_search_pos := 1;
    l_expr_cnt := 0;
    g_normalized_sql := NULL;
    LOOP
      l_expr_start_pattern := q'{(/\*)|(--)|((N|n)?')|((N|n)?(Q|q)'\S)|"}';
      l_key_start_pos := REGEXP_INSTR(in_sql, l_expr_start_pattern, l_search_pos, 1, 0);
      l_key_end_pos   := REGEXP_INSTR(in_sql, l_expr_start_pattern, l_search_pos, 1, 1);
      EXIT WHEN l_key_start_pos = 0 OR l_key_start_pos IS NULL
             OR l_key_end_pos = 0 OR l_key_end_pos IS NULL
             OR l_expr_cnt > 10000;
      l_key := SUBSTR(in_sql, l_key_start_pos, l_key_end_pos-l_key_start_pos);
      CASE
      WHEN l_key = '/*' THEN
        l_expr_end_pattern := '\*/';
        l_expr_start_pos := REGEXP_INSTR(in_sql, l_expr_end_pattern, l_key_end_pos, 1, 0);
        l_expr_end_pos := l_expr_start_pos + 2;
        l_expr_type := 'COMMENT';
      WHEN l_key = '--' THEN
        l_expr_end_pattern := '$';
        l_expr_start_pos := REGEXP_INSTR(in_sql, l_expr_end_pattern, l_key_end_pos, 1, 0, 'm');
        l_expr_end_pos := l_expr_start_pos;
        l_expr_type := 'LINE COMMENT';
      WHEN l_key = '"' THEN
        l_expr_end_pattern := '"';
        l_expr_start_pos := REGEXP_INSTR(in_sql, l_expr_end_pattern, l_key_end_pos, 1, 0);
        l_expr_end_pos := l_expr_start_pos + 1;
        l_expr_type := 'QUOTED NAME';
      WHEN l_key = 'N'''
        OR l_key = 'n'''
        OR l_key = '''' THEN
        l_expr_end_pattern := '''';
        l_expr_start_pos := REGEXP_INSTR(in_sql, l_expr_end_pattern, l_key_end_pos, 1, 0);
        l_expr_end_pos := l_expr_start_pos + 1;
        l_expr_type := 'LITERAL';
      WHEN REGEXP_LIKE(l_key, q'{(N|n)?(Q|q)'\S}') THEN
        CASE SUBSTR(l_key, -1)
          WHEN '{' THEN l_expr_end_pattern := '}''';
          WHEN '[' THEN l_expr_end_pattern := ']''';
          WHEN '(' THEN l_expr_end_pattern := ')''';
          WHEN '<' THEN l_expr_end_pattern := '>''';
          ELSE l_expr_end_pattern := SUBSTR(l_key, -1)||'''';
        END CASE;
        l_expr_start_pos := INSTR(in_sql, l_expr_end_pattern, l_key_end_pos);
        l_expr_end_pos := l_expr_start_pos + 2;
        l_expr_type := 'LITERAL';
      ELSE
        l_key_start_pos := NULL;
        l_expr_end_pos := NULL; 
        l_key_start_pos := NULL;
      END CASE;
      l_expr := SUBSTR(in_sql, l_key_start_pos, l_expr_end_pos - l_key_start_pos);
      CASE  
      WHEN l_expr_type IN ('COMMENT','LINE COMMENT') THEN
        add_text(l_expr_type, l_expr, l_key_start_pos, l_expr_end_pos);
        l_expr := RPAD(' ', LENGTH(l_expr), ' ');   
      WHEN l_expr_type = 'QUOTED NAME' THEN
        l_quoted_name := SUBSTR(l_expr, 2, LENGTH(l_expr)-2);
        -- if simple name quoted then simplify it
        IF is_simple_name(l_quoted_name) THEN
          l_expr := ' '||UPPER(l_quoted_name)||' ';
        ELSE  
          add_text(l_expr_type, l_expr, l_key_start_pos, l_expr_end_pos);
        END IF;
      WHEN l_expr_type = 'LITERAL' THEN
        add_text(l_expr_type, l_expr, l_key_start_pos, l_expr_end_pos);
        l_expr := RPAD(' ', LENGTH(l_expr), ' ');   
      ELSE
        l_expr := NULL;
      END CASE;

      g_normalized_sql := g_normalized_sql || 
                          UPPER(SUBSTR(in_sql, l_search_pos, l_key_start_pos-l_search_pos)) ||
                          l_expr;
      l_search_pos := l_expr_end_pos;
      l_expr_cnt := l_expr_cnt + 1;
    END LOOP;
    g_normalized_sql := g_normalized_sql || UPPER(SUBSTR(in_sql, l_search_pos));
  END normalize_sql;
  
  FUNCTION get_normalized_sql(
    in_quoted_names IN BOOLEAN DEFAULT TRUE,
    in_str_literals IN BOOLEAN DEFAULT TRUE,
    in_comments     IN BOOLEAN DEFAULT TRUE
  )
  RETURN CLOB
  AS
    l_sql     CLOB;
    l_len     PLS_INTEGER;
    l_replace VARCHAR2(32767);
  BEGIN
    l_sql := g_normalized_sql;
    IF NOT in_quoted_names THEN
      FOR i IN 1..g_cort_text_arr.COUNT LOOP
        IF g_cort_text_arr(i).text_type = 'QUOTED NAME' THEN
          l_len := LENGTH(g_cort_text_arr(i).text);
          l_replace := RPAD(' ', l_len, ' ');
          dbms_lob.write(l_sql, l_len, g_cort_text_arr(i).start_position, l_replace);
        END IF;
      END LOOP;    
    END IF;
    IF in_str_literals THEN
      FOR i IN 1..g_cort_text_arr.COUNT LOOP
        IF g_cort_text_arr(i).text_type = 'LITERAL' THEN
          l_len := LENGTH(g_cort_text_arr(i).text);
          l_replace := g_cort_text_arr(i).text;
          dbms_lob.write(l_sql, l_len, g_cort_text_arr(i).start_position, l_replace);
        END IF;
      END LOOP;    
    END IF;
    IF in_comments THEN
      FOR i IN 1..g_cort_text_arr.COUNT LOOP
        IF g_cort_text_arr(i).text_type IN ('COMMENT', 'LINE COMMENT') THEN
          l_len := LENGTH(g_cort_text_arr(i).text);
          l_replace := g_cort_text_arr(i).text;
          dbms_lob.write(l_sql, l_len, g_cort_text_arr(i).start_position, l_replace);
        END IF;
      END LOOP;    
    END IF;
    RETURN l_sql;
  END get_normalized_sql;
  
  -- parses table name and cort hints position
  PROCEDURE parse_object_sql(
    in_operation       IN VARCHAR2,-- CREATE/DROP
    in_object_type     IN VARCHAR2,
    in_object_name     IN VARCHAR2,
    in_object_owner    IN VARCHAR2
  )
  AS
    l_search_pos                PLS_INTEGER;
    l_regexp                    VARCHAR2(1000);
    l_key_start_pos             PLS_INTEGER;
    l_key_end_pos               PLS_INTEGER;
    l_key                       CLOB;
    l_indx                      PLS_INTEGER;
  BEGIN
    l_search_pos := 1;
    CASE in_object_type 
    WHEN 'TABLE' THEN
      CASE in_operation
      WHEN 'CREATE' THEN 
        l_regexp := '(\s*)(CREATE)\s+((GLOBAL\s+TEMPORARY\s+)?TABLE)\s*';
      WHEN 'DROP' THEN
        l_regexp := '(DROP)\s+(TABLE)\s*';  
      END CASE;
      l_regexp := l_regexp || get_owner_name_regexp(in_object_name, in_object_owner)||'(\s|\()';
    END CASE;  
    l_key_start_pos := REGEXP_INSTR(g_normalized_sql, l_regexp, l_search_pos, 1, 0); -- find table definition
    l_key_end_pos := REGEXP_INSTR(g_normalized_sql, l_regexp, l_search_pos, 1, 1); -- find end of table definition
    IF l_key_start_pos = 1 THEN
      g_sql_positions.cort_param_start_pos := REGEXP_INSTR(g_normalized_sql, l_regexp, l_search_pos, 1, 1, null, 2); -- find table definition
      g_sql_positions.cort_param_end_pos := REGEXP_INSTR(g_normalized_sql, l_regexp, l_search_pos, 1, 0, null, 3); -- find end of table definition
      IF in_operation = 'CREATE' AND in_object_type = 'TABLE' THEN 
        l_search_pos := l_key_end_pos - 1;
        l_regexp := '\('; -- find a open bracket
        g_sql_positions.columns_start_pos := REGEXP_INSTR(g_normalized_sql, l_regexp, l_search_pos, 1, 1);
        IF g_sql_positions.columns_start_pos > 0 THEN
          -- find a close bracket
          g_sql_positions.columns_end_pos := get_closed_bracket(
                                               in_sql             => g_normalized_sql,
                                               in_search_position => g_sql_positions.columns_start_pos
                                             );
        END IF;
      END IF;  
    END IF;
    debug('cort_param_start_pos='||g_sql_positions.cort_param_start_pos);
    debug('cort_param_end_pos='||g_sql_positions.cort_param_end_pos);
    debug('columns_start_pos='||g_sql_positions.columns_start_pos);
    debug('columns_end_pos='||g_sql_positions.columns_end_pos);
  END parse_object_sql;
  
  -- parses columns positions
  PROCEDURE parse_columns(
    io_table_rec      IN OUT NOCOPY cort_exec_pkg.gt_table_rec
  )
  AS
    l_search_pos                PLS_INTEGER;
    l_regexp                    VARCHAR2(1000);
    l_key_start_pos             PLS_INTEGER;
    l_key_end_pos               PLS_INTEGER;
    l_key                       CLOB;
    l_indx                      PLS_INTEGER;
    l_next_position             PLS_INTEGER;
  BEGIN
    l_search_pos := g_sql_positions.columns_start_pos;
    FOR i IN 1..io_table_rec.column_arr.COUNT LOOP
      IF io_table_rec.column_arr(i).hidden_column = 'NO' THEN
        l_regexp := get_column_regexp(in_column_rec => io_table_rec.column_arr(i));
        l_key_start_pos := REGEXP_INSTR(g_normalized_sql, l_regexp, l_search_pos, 1, 0, null, 1);
        l_key_end_pos := REGEXP_INSTR(g_normalized_sql, l_regexp, l_search_pos, 1, 1, null, 1);
        IF l_key_start_pos > 0 THEN
          io_table_rec.column_arr(i).sql_start_position := l_key_start_pos;
          io_table_rec.column_arr(i).sql_end_position := l_key_end_pos;
          l_search_pos := l_key_end_pos;
          debug('Parsing: Column '||io_table_rec.column_arr(i).column_name||' startpos = '||l_key_start_pos||' endpos = '||l_key_end_pos);        
        ELSE
          debug('Parsing: Column '||io_table_rec.column_arr(i).column_name||' not found. Regexp = '||l_regexp);        
          debug('Parsing: Regexp = '||l_regexp);        
        END IF;
      END IF;
    END LOOP;

    l_next_position := g_sql_positions.columns_end_pos;
    FOR i IN REVERSE 1..io_table_rec.column_arr.COUNT LOOP
      IF io_table_rec.column_arr(i).hidden_column = 'NO' THEN
        io_table_rec.column_arr(i).sql_next_start_position := l_next_position;
        debug('Parsing: Column '||io_table_rec.column_arr(i).column_name||' next startpos = '||l_next_position);        
        l_next_position := io_table_rec.column_arr(i).sql_start_position;
      END IF;
    END LOOP;  
  END parse_columns;

  -- determines partitions position
  PROCEDURE parse_partitioning(
    io_table_rec      IN OUT NOCOPY cort_exec_pkg.gt_table_rec
  )
  AS
    l_search_pos                PLS_INTEGER;
    l_pos                       PLS_INTEGER;
    l_regexp                    VARCHAR2(1000);
    l_parse_only_sql            CLOB;
  BEGIN
    l_parse_only_sql := get_normalized_sql(
                           in_quoted_names => FALSE,
                           in_str_literals => FALSE,
                           in_comments     => FALSE
                        );
    l_search_pos := NVL(g_sql_positions.columns_end_pos+1,1);
    IF io_table_rec.partitioning_type IS NOT NULL THEN
      l_regexp := '\W(PARTITION\s+BY\s+'||io_table_rec.partitioning_type||')\W';
      l_search_pos := REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 1, NULL, 1);
      IF io_table_rec.partitioning_type <> 'SYSTEM' THEN
        l_search_pos := REGEXP_INSTR(l_parse_only_sql, '\(', l_search_pos, 1, 1);
        l_search_pos := REGEXP_INSTR(l_parse_only_sql, '\)', l_search_pos, 1, 1);
      END IF;
      IF io_table_rec.subpartitioning_type <> 'NONE' THEN
        l_regexp := '\W(SUBPARTITION\s+BY\s+'||io_table_rec.subpartitioning_type||')\W';
        l_search_pos := REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 1, NULL, 1);
        l_search_pos := REGEXP_INSTR(l_parse_only_sql, '\(', l_search_pos, 1, 1);
        l_search_pos := REGEXP_INSTR(l_parse_only_sql, '\)', l_search_pos, 1, 1);
        l_regexp := '\s*(SUBPARTITION\s+TEMPLATE)\W';
        IF REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 0) = l_search_pos THEN
          l_search_pos := REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 1, NULL, 1);
          l_regexp := '\s*\(';
          IF REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 0) = l_search_pos THEN
            l_search_pos := REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 1);
            l_search_pos := get_closed_bracket(l_parse_only_sql, l_search_pos) + 1;
          ELSIF io_table_rec.subpartitioning_type = 'HASH' THEN
            l_regexp := '\s*[0-9]+';
            IF REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 0) = l_search_pos THEN
              l_search_pos := REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 1);
            END IF;
          END IF;
        ELSIF io_table_rec.subpartitioning_type = 'HASH' THEN
          l_regexp := '\s*SUBPARTITIONS\s+[0-9]+';
          IF REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 0) = l_search_pos THEN
            l_search_pos := REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 1);
            l_regexp := '\s*STORE\s+IN\s*\(';
            IF REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 0) = l_search_pos THEN
              l_search_pos := REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 1);
              l_search_pos := get_closed_bracket(l_parse_only_sql, l_search_pos) + 1;
            END IF;
          END IF;
        END IF;
        l_regexp := '\s*\(';
        l_search_pos := REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 0);
        IF REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 0) = l_search_pos THEN
          l_search_pos := REGEXP_INSTR(l_parse_only_sql, l_regexp, l_search_pos, 1, 1);
          g_sql_positions.partitions_start_pos := l_search_pos;
          g_sql_positions.partitions_end_pos := get_closed_bracket(l_parse_only_sql, l_search_pos);
        END IF;
      END IF;
    END IF;
  END parse_partitioning;

  FUNCTION get_cort_hints RETURN gt_hint_arr
  RESULT_CACHE
  RELIES_ON (cort_hints)
  AS
    TYPE t_temp_arr IS TABLE OF cort_hints%ROWTYPE INDEX BY PLS_INTEGER;
    l_temp_arr   t_temp_arr;
    l_hint_arr   gt_hint_arr;
  BEGIN
    SELECT * 
      BULK COLLECT 
      INTO l_temp_arr 
      FROM cort_hints;
    FOR i IN 1..l_temp_arr.COUNT LOOP
      l_hint_arr(UPPER(l_temp_arr(i).hint)) := l_temp_arr(i);
    END LOOP;   
    RETURN l_hint_arr;
  END get_cort_hints;
  
  -- parses cort table params
  PROCEDURE parse_cort_hints(
    in_hint_string  IN VARCHAR2,
    io_params_rec   IN OUT NOCOPY cort_params_pkg.gt_params_rec
  )
  AS
    l_regexp_str    VARCHAR2(32767);
    l_search_pos    PLS_INTEGER;
    l_key_start_pos PLS_INTEGER;
    l_key_end_pos   PLS_INTEGER;
    l_key           VARCHAR2(32767);
    l_value         VARCHAR2(32767);
    l_hint_arr      gt_hint_arr;
  BEGIN
    l_hint_arr := get_cort_hints;
    l_key := l_hint_arr.FIRST;
    WHILE l_key IS NOT NULL LOOP 
      l_regexp_str := l_regexp_str||l_key||'|';
      l_key := l_hint_arr.NEXT(l_key);
    END LOOP;
    l_regexp_str := '\W('||TRIM('|' FROM l_regexp_str)||')\W';
    debug('parsing hint string = '||in_hint_string);
    l_search_pos := 1;
    LOOP
      l_key_start_pos := REGEXP_INSTR(in_hint_string, l_regexp_str, l_search_pos, 1, 0, 'im', 1);
      l_key_end_pos := REGEXP_INSTR(in_hint_string, l_regexp_str, l_search_pos, 1, 1, 'im', 1);
      EXIT WHEN l_key_start_pos = 0;
      l_search_pos := l_key_end_pos;
      l_key := UPPER(SUBSTR(in_hint_string, l_key_start_pos, l_key_end_pos-l_key_start_pos));
      IF l_hint_arr.EXISTS(l_key) THEN
        IF l_hint_arr(l_key).expression_flag = 'Y' THEN
          l_value := REGEXP_SUBSTR(in_hint_string, l_hint_arr(l_key).param_value, l_key_end_pos, 1, NULL, 1);
          debug(l_hint_arr(l_key).param_name||'='||l_value);
          cort_params_pkg.set_param_value(io_params_rec, l_hint_arr(l_key).param_name, l_value);
        ELSE
          debug(l_hint_arr(l_key).param_name||'='||l_hint_arr(l_key).param_value);
          cort_params_pkg.set_param_value(io_params_rec, l_hint_arr(l_key).param_name, l_hint_arr(l_key).param_value);
        END IF;
      ELSE  
        debug('Hint '||l_key||' not registered');
      END IF;
    END LOOP;
  END parse_cort_hints;

    -- Finds cort_ value params and assigns them to the nearest column
  PROCEDURE parse_cort_values(
    io_params_rec IN OUT NOCOPY cort_params_pkg.gt_params_rec
  )
  AS
    l_search_pos                PLS_INTEGER;
    l_regexp                    VARCHAR2(1000);
    l_key_start_pos             PLS_INTEGER;
    l_key_end_pos               PLS_INTEGER;
    l_key                       VARCHAR2(30);
    l_text                      VARCHAR2(32767);
    l_value                     VARCHAR2(32767);
    l_indx                      PLS_INTEGER;
  BEGIN
    FOR i IN 1..g_cort_text_arr.COUNT LOOP
      IF g_cort_text_arr(i).text_type IN ('LINE COMMENT', 'COMMENT') THEN
        CASE g_cort_text_arr(i).text_type 
        WHEN 'LINE COMMENT' THEN
          l_text := SUBSTR(g_cort_text_arr(i).text, 3);
        WHEN 'COMMENT' THEN
          l_text := SUBSTR(g_cort_text_arr(i).text, 3, LENGTH(g_cort_text_arr(i).text)-4);
        END CASE;
        debug('comment='||l_text); 
        debug('comment position='||g_cort_text_arr(i).start_position); 
        IF g_cort_text_arr(i).start_position BETWEEN g_sql_positions.cort_param_start_pos 
                                                 AND g_sql_positions.cort_param_end_pos 
        THEN                                            
          l_regexp := get_regexp_const(cort_exec_pkg.gc_cort_text_prefix);
          l_key_start_pos := REGEXP_INSTR(l_text, l_regexp, 1, 1, 0);
          l_key_end_pos := REGEXP_INSTR(l_text, l_regexp, 1, 1, 1);
          IF l_key_start_pos = 1 THEN
            l_value := ' '||SUBSTR(l_text, l_key_end_pos+1)||' ';
            parse_cort_hints(
              in_hint_string  => l_value,
              io_params_rec   => io_params_rec
            );
          END IF;            
        END IF;
      END IF;
    END LOOP;
  END parse_cort_values;
  
  PROCEDURE parse_column_cort_values(
    io_table_rec  IN OUT NOCOPY cort_exec_pkg.gt_table_rec,
    io_params_rec IN OUT NOCOPY cort_params_pkg.gt_params_rec
  )
  AS
    l_search_pos                PLS_INTEGER;
    l_regexp                    VARCHAR2(1000);
    l_key_start_pos             PLS_INTEGER;
    l_key_end_pos               PLS_INTEGER;
    l_key                       VARCHAR2(30);
    l_text                      VARCHAR2(32767);
    l_value                     VARCHAR2(32767);
    l_indx                      PLS_INTEGER;
    l_cort_index                PLS_INTEGER;
    l_last_column_index         PLS_INTEGER;
    l_column_index              PLS_INTEGER;
    
    FUNCTION get_column_at(
      in_position      IN  PLS_INTEGER, 
      out_column_index OUT PLS_INTEGER
    )
    RETURN BOOLEAN  
    AS
    BEGIN
      FOR i IN l_last_column_index..io_table_rec.column_arr.COUNT LOOP
        IF in_position BETWEEN io_table_rec.column_arr(i).sql_end_position 
                           AND io_table_rec.column_arr(i).sql_next_start_position
        THEN
          l_last_column_index := i;
          out_column_index := i; 
          RETURN TRUE;
        END IF;                    
      END LOOP;
      l_last_column_index := io_table_rec.column_arr.COUNT + 1;
      out_column_index := -1;
      RETURN FALSE;
    END get_column_at;
    
  BEGIN
    l_last_column_index := 1;
    FOR i IN 1..g_cort_text_arr.COUNT LOOP
      IF g_cort_text_arr(i).text_type IN ('LINE COMMENT', 'COMMENT') THEN
        CASE g_cort_text_arr(i).text_type 
        WHEN 'LINE COMMENT' THEN
          l_text := SUBSTR(g_cort_text_arr(i).text, 3);
        WHEN 'COMMENT' THEN
          l_text := SUBSTR(g_cort_text_arr(i).text, 3, LENGTH(g_cort_text_arr(i).text)-4);
        END CASE; 
        IF g_cort_text_arr(i).start_position BETWEEN g_sql_positions.columns_start_pos 
                                                 AND g_sql_positions.columns_end_pos 
        THEN
          l_regexp := get_regexp_const(cort_exec_pkg.gc_cort_text_prefix||cort_exec_pkg.gc_force_value)||'|'||
                      get_regexp_const(cort_exec_pkg.gc_cort_text_prefix||cort_exec_pkg.gc_value);
          l_key_start_pos := REGEXP_INSTR(l_text, l_regexp, 1, 1, 0);
          l_key_end_pos := REGEXP_INSTR(l_text, l_regexp, 1, 1, 1);
          IF l_key_start_pos = 1 THEN
            l_key := SUBSTR(l_text, l_key_start_pos, l_key_end_pos-l_key_start_pos);
            l_value := SUBSTR(l_text, l_key_end_pos);
            IF TRIM(l_value) IS NOT NULL THEN
              CASE l_key
              WHEN cort_exec_pkg.gc_cort_text_prefix||cort_exec_pkg.gc_force_value THEN
                IF get_column_at(g_cort_text_arr(i).start_position, l_column_index) THEN
                  debug('Parsing: Column '||io_table_rec.column_arr(l_column_index).column_name||' has cort force value = '||l_value);
                  l_cort_index := io_table_rec.column_arr(l_column_index).cort_values.COUNT + 1;
                  io_table_rec.column_arr(l_column_index).cort_values(l_cort_index).expression := l_value;
                  io_table_rec.column_arr(l_column_index).cort_values(l_cort_index).force_value := TRUE;
                ELSE
                  debug('Parsing: Column at position '||g_cort_text_arr(i).start_position||' not found');
                END IF;
              WHEN cort_exec_pkg.gc_cort_text_prefix||cort_exec_pkg.gc_value THEN
                IF get_column_at(g_cort_text_arr(i).start_position, l_column_index) THEN
                  debug('Parsing: Column '||io_table_rec.column_arr(l_column_index).column_name||' has cort value = '||l_value);
                  l_cort_index := io_table_rec.column_arr(l_column_index).cort_values.COUNT + 1;
                  io_table_rec.column_arr(l_column_index).cort_values(l_cort_index).expression := l_value;
                  io_table_rec.column_arr(l_column_index).cort_values(l_cort_index).force_value := FALSE;
                ELSE
                  debug('Parsing: Column at position '||g_cort_text_arr(i).start_position||' not found');
                END IF;
              ELSE NULL;
              END CASE;
            END IF;
          END IF;            
        END IF;
      END IF;
    END LOOP;
  END parse_column_cort_values;

  -- Public declaration
   
  -- parses SQL
  PROCEDURE initial_parse_sql(
    in_sql           IN CLOB,
    in_operation     IN VARCHAR2,-- CREATE/DROP
    in_object_type   IN VARCHAR2,
    in_object_name   IN VARCHAR2,
    in_object_owner  IN VARCHAR2,
    in_partition_pos IN NUMBER,
    io_params_rec    IN OUT NOCOPY cort_params_pkg.gt_params_rec
  )
  AS
  BEGIN
    g_params := io_params_rec;
    
    g_sql_positions.columns_start_pos := NULL;
    g_sql_positions.columns_end_pos := NULL;
    g_sql_positions.partitions_start_pos := in_partition_pos;
    g_sql_positions.partitions_end_pos := in_partition_pos;
    
    g_normalized_sql := NULL;
    g_cort_text_arr.DELETE;

    normalize_sql(
      in_sql => in_sql
    );
  
    parse_object_sql(
      in_operation       => in_operation,
      in_object_type     => in_object_type, 
      in_object_name     => in_object_name, 
      in_object_owner    => in_object_owner
    );

    parse_cort_values(
      io_params_rec => io_params_rec
    );
    
    g_params := io_params_rec;
  END initial_parse_sql;

  -- replaces table name and all names of existing depending objects (constraints, log groups, indexes, lob segments) 
  PROCEDURE replace_names(
    in_table_rec IN cort_exec_pkg.gt_table_rec,
    out_sql      OUT NOCOPY CLOB 
  )
  AS
    l_indx         PLS_INTEGER;
    l_replace_rec  gt_replace_rec;
  BEGIN
--    dbms_output.put_line('++++replace_names+++++');
    -- get all names
    find_all_substitutions(
      in_table_rec => in_table_rec
    );

    out_sql := get_normalized_sql(
                 in_quoted_names => TRUE,
                 in_str_literals => TRUE,
                 in_comments     => TRUE
               );
--    dbms_output.put_line(out_sql);

    -- loop all names start from the end
    l_indx := g_replace_arr.LAST;
    WHILE l_indx IS NOT NULL LOOP
      l_replace_rec := g_replace_arr(l_indx);
      out_sql := SUBSTR(out_sql, 1, l_replace_rec.start_pos - 1)||'"'||l_replace_rec.new_name||'"'||SUBSTR(out_sql, l_replace_rec.end_pos);
      l_indx := g_replace_arr.PRIOR(l_indx);
    END LOOP;
    out_sql := SUBSTR(out_sql, 1, g_sql_positions.cort_param_start_pos - 1)||' '||SUBSTR(out_sql, g_sql_positions.cort_param_end_pos);
    
--    dbms_output.put_line(out_sql);
  END replace_names;

  -- return original name for renamed object. If it wasn't rename return current name 
  FUNCTION get_original_name(
    in_object_type  IN VARCHAR2,
    in_object_name  IN VARCHAR2
  )
  RETURN VARCHAR2
  AS
    l_indx   VARCHAR2(50); 
  BEGIN
    l_indx := in_object_type||':"'||in_object_name||'"';
    IF g_temp_name_arr.EXISTS(l_indx) THEN
      RETURN g_temp_name_arr(l_indx);
    ELSE
      RETURN in_object_name;
    END IF;  
  END get_original_name;

  -- parses columns, partitions 
  PROCEDURE parse_create_table_sql(
    in_sql        IN CLOB,
    io_table_rec  IN OUT NOCOPY cort_exec_pkg.gt_table_rec,
    io_params_rec IN OUT NOCOPY cort_params_pkg.gt_params_rec
  )
  AS
  BEGIN
    g_params := io_params_rec;

    parse_columns(
      io_table_rec => io_table_rec
    );

    parse_partitioning(
      io_table_rec => io_table_rec
    );
    
    parse_column_cort_values(
      io_table_rec  => io_table_rec,
      io_params_rec => io_params_rec
    );
    
    g_params := io_params_rec;
  END parse_create_table_sql;
  
  -- replaces partitions definition in original_sql
  PROCEDURE replace_partitions_sql(
    io_sql           IN OUT NOCOPY CLOB,
    in_partition_sql IN CLOB
  )
  AS
  BEGIN
    io_sql := SUBSTR(io_sql, 1, g_sql_positions.partitions_start_pos-1)||
              in_partition_sql||
              SUBSTR(io_sql, g_sql_positions.partitions_end_pos);
  END replace_partitions_sql;
  
  -- parses drop command and returns purge clause
  PROCEDURE parse_purge_clause(
    out_purge OUT VARCHAR2
  )
  AS
  BEGIN
    --out_purge := REGEXP_SUBSTR(l_parse_only_sql, '\WPURGE\W');
    null; 
  END parse_purge_clause;

END cort_parse_pkg;
/
declare
  l_rec1 cort_exec_pkg.gt_table_rec;
begin
  rollback;
  cort_exec_pkg.test_read_table(
     in_table_name => 'USER$'
   , in_owner      => 'SYS'
   , out_table_rec => l_rec1
  );   
  cort_xml_pkg.g_table_rec := l_rec1;
  cort_xml_pkg.describe_record_test(
      in_getter_func_mame => 'cort_xml_pkg.get_table_rec'
    , in_package_name     => 'CORT_XML_PKG'
    , in_func_name        => 'GT_TABLE_REC_TO_XML'
    , in_argument_name    => 'IN_TABLE_REC'
    , in_argument_type    => 'cort_exec_pkg.gt_table_rec'
    );
end;
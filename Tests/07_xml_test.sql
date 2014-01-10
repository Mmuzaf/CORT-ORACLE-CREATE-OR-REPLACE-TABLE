begin
 dbms_xmlschema.deleteSchema(
   schemaURL => 'http://www.example.com/xwarehouses.xsd'
 );  
end;
/

begin
 dbms_xmlschema.registerSchema(
  schemaURL => 'http://www.example.com/xwarehouses.xsd',  
  schemaDoc => '<schema xmlns="http://www.w3.org/2001/XMLSchema" 
       targetNamespace="http://www.example.com/xwarehouses.xsd" 
       xmlns:who="http://www.example.com/xwarehouses.xsd"
       version="1.0">
  <simpleType name="RentalType">
   <restriction base="string">
    <enumeration value="Rented"/>
    <enumeration value="Owned"/>
   </restriction>
  </simpleType>
  <simpleType name="ParkingType">
   <restriction base="string">
    <enumeration value="Street"/>
    <enumeration value="Lot"/>
   </restriction>
  </simpleType>
  <element name = "Warehouse">
    <complexType>
     <sequence>
      <element name = "WarehouseId"   type = "positiveInteger"/>
      <element name = "WarehouseName" type = "string"/>
      <element name = "Building"      type = "who:RentalType"/>
      <element name = "Area"          type = "positiveInteger"/>
      <element name = "Docks"         type = "positiveInteger"/>
      <element name = "DockType"      type = "string"/>
      <element name = "WaterAccess"   type = "boolean"/>
      <element name = "RailAccess"    type = "boolean"/>
      <element name = "Parking"       type = "who:ParkingType"/>
      <element name = "VClearance"    type = "positiveInteger"/>
     </sequence>
    </complexType>
  </element>
</schema>',
   local => TRUE, 
   genTypes => FALSE, 
   genbean => FALSE, 
   genTables => FALSE,
   options => dbms_xmlschema.REGISTER_BINARYXML
  );
end;
/

begin
 dbms_xmlschema.deleteSchema(
   schemaURL => 'http://www.example.com/xwarehouses2.xsd'
 );  
end;
/

begin
 dbms_xmlschema.registerSchema(
  schemaURL => 'http://www.example.com/xwarehouses2.xsd',  
  schemaDoc => '<schema xmlns="http://www.w3.org/2001/XMLSchema" 
       targetNamespace="http://www.example.com/xwarehouses.xsd" 
       xmlns:who="http://www.example.com/xwarehouses.xsd"
       version="1.0">
  <simpleType name="RentalType">
   <restriction base="string">
    <enumeration value="Rented"/>
    <enumeration value="Owned"/>
   </restriction>
  </simpleType>
  <simpleType name="ParkingType">
   <restriction base="string">
    <enumeration value="Street"/>
    <enumeration value="Lot"/>
   </restriction>
  </simpleType>
  <element name = "Warehouse">
    <complexType>
     <sequence>
      <element name = "WarehouseId"   type = "positiveInteger"/>
      <element name = "WarehouseName" type = "string"/>
      <element name = "Building"      type = "who:RentalType"/>
      <element name = "Area"          type = "positiveInteger"/>
      <element name = "Docks"         type = "positiveInteger"/>
      <element name = "DockType"      type = "string"/>
      <element name = "WaterAccess"   type = "boolean"/>
      <element name = "RailAccess"    type = "boolean"/>
      <element name = "Parking"       type = "who:ParkingType"/>
      <element name = "VClearance"    type = "positiveInteger"/>
     </sequence>
    </complexType>
  </element>
</schema>',
   local => TRUE, 
   genTypes => TRUE, 
   genbean => FALSE, 
   genTables => FALSE,
   options => 0
  );
end;
/


CREATE /*#or replace echo */ TABLE XWAREHOUSES2
(
  WAREHOUSE_ID    NUMBER,
  WAREHOUSE_SPEC  XMLTYPE,
  WAREHOUSE_SPEC2  XMLTYPE
)
XMLTYPE WAREHOUSE_SPEC STORE AS BINARY XML
XMLSCHEMA "http://www.example.com/xwarehouses.xsd"
ELEMENT "Warehouse"
XMLTYPE WAREHOUSE_SPEC2 STORE AS OBJECT RELATIONAL
XMLSCHEMA "http://www.example.com/xwarehouses2.xsd"
ELEMENT "Warehouse"
;

insert into XWAREHOUSES2 values(1, null, null);

commit;

CREATE /*#or replace echo */ TABLE XWAREHOUSES2
(
  WAREHOUSE_ID    NUMBER,
  WAREHOUSE_SPEC  XMLTYPE,
  WAREHOUSE_SPEC2  XMLTYPE
)
XMLTYPE WAREHOUSE_SPEC STORE AS BINARY XML
XMLSCHEMA "http://www.example.com/xwarehouses.xsd"
ELEMENT "Warehouse"
--XMLTYPE WAREHOUSE_SPEC2 STORE AS OBJECT RELATIONAL
--XMLSCHEMA "http://www.example.com/xwarehouses2.xsd"
--ELEMENT "Warehouse"
;


select * from user_tab_cols
where table_name = 'XWAREHOUSES2'
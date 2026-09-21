///|
fn rosidl_writer_method(type_name : String) -> String {
  match type_name {
    "bool" => "write_bool"
    "byte" => "write_u8"
    "char" => "write_u8"
    "int8" => "write_i8"
    "uint8" => "write_u8"
    "int16" => "write_i16_int"
    "uint16" => "write_u16_uint"
    "int32" => "write_i32"
    "uint32" => "write_u32"
    "int64" => "write_i64"
    "uint64" => "write_u64"
    "float32" => "write_f32"
    "float64" => "write_f64"
    "string" => "write_string"
    "wstring" => "write_wstring"
    _ => ""
  }
}

///|
fn rosidl_reader_method(type_name : String) -> String {
  match type_name {
    "bool" => "read_bool"
    "byte" => "read_u8"
    "char" => "read_u8"
    "int8" => "read_i8"
    "uint8" => "read_u8"
    "int16" => "read_i16"
    "uint16" => "read_u16"
    "int32" => "read_i32"
    "uint32" => "read_u32"
    "int64" => "read_i64"
    "uint64" => "read_u64"
    "float32" => "read_f32"
    "float64" => "read_f64"
    "string" => "read_string"
    "wstring" => "read_wstring"
    _ => ""
  }
}

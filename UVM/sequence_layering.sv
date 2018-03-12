//=================================================================================================================== 
// File : sequence_Layering
// Description :
//   In this example two sequencers ( Upper Layer and Lower Layer) are connected , The lower Layer sequencer is connected 
//   with Lower Layer Driver , which is the actual driver to communicate to the DUT PHY
//   The upper Layer sequencer(data_array_sqr) would start the uppwe layer sequences(data_array_seq) which has array of data bytes.
//   Now the Lower Layer sequencer(byte_sqr) 's sequence(byte_seq) has data bytes , So the byte_seq body() would get the upper item(ie array)
//   and coverts to lower item (ie byte) 
//=================================================================================================================== 
//     |````````````````|
//   |````````````````|_|
//  |```````````````|_|     <-----------Upper Layer Array generating sequences
//  | byte data[]   |                   Drives every #100
//  |_______________|       
//          |
//          v 
// |```````````````````|
// |                   |
// |  Array_sequencer  |
// |___________________|
//          0                        |````````````````|
//          |                      |````````````````|_|
//        |``|                    |```````````````|_|
// |```````````````````|          | byte data     |  <-----------Upper Layer array to byte converting sequences
// |                   |<---------|_______________|    Drive if upper transaction is valid else drive IDLE transaction
// |  byte_sequencer   |
// |___________________|
//          0   
//          |  
// |```````````````````|        |```````````````````|
// |                   |------->|                   |
// |    byte Driver    |------->|    DUT byte intf  |
// |___________________|        |___________________|
//             
//=================================================================================================================== 

`include "uvm_macros.svh"

import uvm_pkg::*;

//------------------------------------------
// Upper Layer packet holds bunch of data
//------------------------------------------
class data_array extends uvm_sequence_item;

rand byte data[];

`uvm_object_utils_begin(data_array)
  `uvm_field_array_int(data,UVM_ALL_ON)
`uvm_object_utils_end

constraint array_c {
  data.size inside {[5:16]};
}

function new(string name ="data_array");
  super.new(name);
endfunction

endclass

//------------------------------------------
// Lower Later packet which the driver drives 
// to the dut phy in bytes
//------------------------------------------
class data_byte extends uvm_sequence_item;

rand byte data;

`uvm_object_utils_begin(data_byte)
  `uvm_field_int(data,UVM_ALL_ON)
`uvm_object_utils_end

function new(string name ="data_byte");
  super.new(name);
endfunction

endclass

//------------------------------------------
// upper sequencer
//------------------------------------------
class data_array_sqr extends uvm_sequencer #(data_array);
  `uvm_component_utils(data_array_sqr)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

//------------------------------------------
// lower sequencer : Connected to the phy driver
//------------------------------------------
class data_byte_sqr extends uvm_sequencer #(data_byte);
  `uvm_component_utils(data_byte_sqr)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

//------------------------------------------
// Make some data_array_seq items
//------------------------------------------
class data_array_seq extends uvm_sequence #(data_array);
  `uvm_object_utils(data_array_seq)
  
  function new(string name="data_array_seq");
  	super.new(name);
  endfunction
  
  data_array array_item;
  
  task body();
    uvm_report_info(get_full_name(),"Starting data_array_seq");
    forever 
    begin
      array_item = data_array::type_id::create("array_item");
      start_item(array_item); // blocks until driver is ready...
      assert(array_item.randomize());
      array_item.print();
      finish_item(array_item); // ready to hand over to driver...
      #100; 
    end
  endtask

endclass


//------------------------------------------
// Get array_item items and create byte_item
//------------------------------------------
class data_byte_seq extends uvm_sequence #(data_byte);
  `uvm_object_utils(data_byte_seq)
  
  function new(string name="data_byte_seq");
  	super.new(name);
  endfunction
  
  data_array_sqr array_sqr;
  
  task body();
    data_array array_item;
    data_byte  byte_item;

    uvm_report_info(get_full_name(),"Starting data_byte_seq..");

    forever 
    begin
      // Get the Upper Layer packet
      array_sqr.try_next_item(array_item);
      if(array_item != null)
      begin      
        // Make the Lower Layer packet and
        // Drive the lower layer seq to the phy driver
        foreach(array_item.data[i])
        begin
          byte_item = data_byte::type_id::create("byte_item");
          start_item(byte_item); // blocks until driver is ready...
          byte_item.data = array_item.data[i];
          finish_item(byte_item); // ready to hand over to driver...
        end
        array_sqr.item_done();
      end
      else
      begin
         // If there is no req from upper layer driver idle on the line
         drive_idle_seq();
         #10; 
      end

    end
  endtask

  
  task drive_idle_seq();
    data_byte idle_item;
    uvm_report_info(get_full_name(),"-----------------Starting IDLE Seq---------------");
    idle_item = data_byte::type_id::create("idle_item");
    start_item(idle_item);
    assert(idle_item.randomize()); 
    finish_item(idle_item);
  endtask

endclass


//------------------------------------------------
//------------------------------------------------
class byte_driver extends uvm_driver#(data_byte);

  `uvm_component_utils(byte_driver)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual task main_phase(uvm_phase phase);
    while(1)
    begin
        seq_item_port.get_next_item(req);
        req.print();
        seq_item_port.item_done();
    end
  endtask

endclass


//------------------------------------------
//------------------------------------------
class layering_env extends uvm_env;

  `uvm_component_utils(layering_env)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
  
  byte_driver driver;
  data_array_sqr array_sqr;
  data_byte_sqr  byte_sqr;



  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    driver = byte_driver::type_id::create("driver", this);
    array_sqr = data_array_sqr::type_id::create("array_sqr", this);
    byte_sqr  = data_byte_sqr::type_id::create("byte_sqr", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(byte_sqr.seq_item_export); 
  endfunction

endclass
 

//------------------------------------------
//------------------------------------------
class layering_test extends uvm_test;
 
 `uvm_component_utils(layering_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  layering_env  env;
  data_byte_seq byte_seq;
  data_array_seq array_seq;
 
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env       = layering_env::type_id::create("end", this);  
    byte_seq  = data_byte_seq::type_id::create("byte_seq");
    array_seq = data_array_seq::type_id::create("array_seq");
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    byte_seq.array_sqr = env.array_sqr;
  endfunction 

  virtual task main_phase(uvm_phase phase);
   phase.raise_objection(this);
 
    fork
    byte_seq.start(env.byte_sqr);
    join_none

    fork
       begin
         array_seq.start(env.array_sqr);
       end
       begin
           #10us;
       end
    join_any
    disable fork;
    
   phase.drop_objection(this);
  endtask

endclass

//------------------------------------------
//------------------------------------------
module top;

import uvm_pkg::*;

initial begin
  run_test("layering_test");
end
endmodule


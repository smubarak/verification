/*
In this code, I am trying to send different types of transaction to the driver from sequence,
and the driver process the transaction depends on the type of the packet.
*/
`include "uvm_macros.svh"

module tb;

import uvm_pkg::*;


class base extends uvm_sequence_item;
   rand int a;

   `uvm_object_utils_begin(base)
   `uvm_field_int(a,UVM_ALL_ON)
   `uvm_object_utils_end

   function new(string name="base");
      super.new(name);
   endfunction

endclass

class child1 extends base;
   
   rand int b;

   `uvm_object_utils_begin(child1)
   `uvm_field_int(b,UVM_ALL_ON)
   `uvm_object_utils_end

   function new(string name="child1");
      super.new(name);
   endfunction

endclass

class child2 extends base;
   
   rand int c;
   
   `uvm_object_utils_begin(child2)
   `uvm_field_int(c,UVM_ALL_ON)
   `uvm_object_utils_end

   function new(string name="child2");
      super.new(name);
   endfunction

endclass

class sequence1 extends uvm_sequence;
   `uvm_object_utils(sequence1)

   function new(string name="sequence1");
      super.new(name);
   endfunction

   child1 c1;
   child2 c2;
   base b;

   task body();

      c1 =new("c1");
      c2 =new("c2");
      b=c1;
      start_item(b);
      assert(b.randomize());
      finish_item(b);

      b=c2;
      start_item(b);
      assert(b.randomize());
      finish_item(b);

   endtask


endclass


class driver extends uvm_driver #(base);
   
   child1 c1;
   child2 c2;
   //----------------------------------------------------------------
   // FUNCTION : new
   //----------------------------------------------------------------
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction: new

   //----------------------------------------------------------------
   // Factory Registration
   //----------------------------------------------------------------
   `uvm_component_utils_begin(driver)
   `uvm_component_utils_end

   //----------------------------------------------------------------
   // TASK : get_and_drive
   //
   // Sequencer-Driver handshake
   //----------------------------------------------------------------
   task get_and_drive();
      forever
      begin
          // wait(vif.reset==0);  // block until reset released
          seq_item_port.get_next_item(req);

          if($cast(c1,req)) 
             c1.print;
          else if($cast(c2,req))
             c2.print;
          else
             `uvm_fatal(get_type_name(),"Cast Failed")

          //send_to_dut(item);
          seq_item_port.item_done();
      end
   endtask: get_and_drive

   //----------------------------------------------------------------
   // TASK : run_phase
   // 
   //----------------------------------------------------------------
   virtual task run_phase(uvm_phase phase);
      get_and_drive();
   endtask: run_phase

endclass: driver

class sequencer extends uvm_sequencer #(base);
   
   //----------------------------------------------------------------
   // Factory Registration
   //----------------------------------------------------------------
   `uvm_component_utils(sequencer)

   //----------------------------------------------------------------
   // FUNCTION : new
   //----------------------------------------------------------------
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction: new

endclass: sequencer

class env extends uvm_env;
   

   driver drv;
   sequencer sqr;

   //----------------------------------------------------------------
   // Factory Registration
   //----------------------------------------------------------------
   `uvm_component_utils(env)

   //----------------------------------------------------------------
   // FUNCTION : new
   //----------------------------------------------------------------
   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction: new

   //----------------------------------------------------------------
   // FUNCTION: build_phase
   // 
   // Create the Agent
   //----------------------------------------------------------------
   virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      drv = driver :: type_id::create("drv",this);
      sqr = sequencer :: type_id::create("sqr",this);

   endfunction: build_phase

   function void connect_phase (uvm_phase phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
   endfunction: connect_phase

endclass: env

class test extends uvm_test;
   

    //----------------------------------------------------------------
    // Env Declaration
    //----------------------------------------------------------------
    env m_env;
    sequence1 seq;

    //----------------------------------------------------------------
    // Factory Registration
    //----------------------------------------------------------------
    `uvm_component_utils(test)

    //----------------------------------------------------------------
    // FUNCTION : new
    //----------------------------------------------------------------
    function new(string name, uvm_component parent);
       super.new(name, parent);
    endfunction: new

    //----------------------------------------------------------------
    // FUNCTION : build_phase
    //----------------------------------------------------------------
    virtual function void build_phase(uvm_phase phase);
       super.build_phase(phase);
       m_env = env  :: type_id :: create("env", this);
    endfunction: build

    
   task main_phase(uvm_phase phase);
      phase.raise_objection(this);
      seq = new("seq");
      seq.start(m_env.sqr);

      phase.drop_objection(this);
   endtask



endclass: uvc_name_base_test


initial begin
  run_test();
end




endmodule


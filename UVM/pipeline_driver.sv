//====================================================================
// Description:
//====================================================================
// The driver take transactions from sequencer and drive them to the DUT 
// in a pipelined fasion. This methode can be used to implement 
// driver for ahb or axi like protocol
//====================================================================
`include "uvm_macros.svh"

module tb;

import uvm_pkg::*;

typedef enum {ERROR,OKAY} resp_type_t;
typedef enum {NOP,WRITE,READ}cmd_type_t;

//--------------------------------------------------------------------//
// Sequence Item/Transaction
//--------------------------------------------------------------------//
class my_seq_item extends uvm_sequence_item;

   rand int id;
   rand resp_type_t resp;
   rand cmd_type_t  cmd;
   rand byte data[];

  `uvm_object_utils_begin(my_seq_item)
    `uvm_field_int(id,UVM_ALL_ON)
    `uvm_field_enum(cmd_type_t,cmd,UVM_ALL_ON)
    `uvm_field_enum(resp_type_t,resp,UVM_ALL_ON)
    `uvm_field_array_int(data,UVM_ALL_ON)
  `uvm_object_utils_end

  constraint c_main {
                      cmd==WRITE -> data.size() inside {[1:8]};
                      cmd==READ  -> data.size() ==0;
                    }
 
  function new(string name = "my_seq_item");
    super.new(name);
  endfunction

endclass

//---------------------------------------------------------------------//
// Sequence
//---------------------------------------------------------------------//
class my_sequence extends uvm_sequence#(my_seq_item);

    `uvm_object_utils(my_sequence)
    
    my_seq_item req_buf[];
    
    function new(string name = "my_sequence");
        super.new(name);
    endfunction
    
    // From the pipelined sequence:
    //-----------------------------
    task body();
        my_seq_item req = my_seq_item::type_id::create("req");
        // Enable response handler call-back:
        use_response_handler(1);
    
        // Generate Stimulus:
        req_buf = new[10];
        for(int i=0; i<10; i++) 
        begin
            assert($cast(req_buf[i], req.clone()));
            start_item(req_buf[i]);
            assert(req_buf[i].randomize() with {
                                                 req_buf[i].id == i; 
                                                 req_buf[i].cmd != NOP; 
                                                 req_buf[i].resp == ERROR; // default error resp,driver will modify to OKAY
                                               });
            finish_item(req_buf[i]);
        end
    endtask: body
   
    // This function will handle the response once the response is received 
    //-------------------------------------------------------------------- 
    function void response_handler(uvm_sequence_item response);
        my_seq_item rsp;
        if(!$cast(rsp, response)) 
        begin
            uvm_report_error(get_type_name(), "Unknow Reponse received ... Casting Failed my_seq <- reponse");
            return;
        end
        else begin
            // Handle the response
            uvm_report_info(get_type_name(),$psprintf("Receiving Response[%0d]",rsp.id));
            req_buf[rsp.id].resp=rsp.resp;
        end
         
        req_buf[rsp.id].print();
           
    endfunction: response_handler

endclass:my_sequence

//----------------------------------------------------------------------//
// Sequencer
//----------------------------------------------------------------------//
class my_sequencer extends uvm_sequencer #(my_seq_item);

    `uvm_component_utils(my_sequencer)
    
    function new(string name = "my_sequencer" , uvm_component parent);
      super.new(name,parent);
    endfunction

endclass

//----------------------------------------------------------------------//
// From the pipelined driver:
//----------------------------------------------------------------------//
class my_driver extends uvm_driver #(my_seq_item);

    `uvm_component_utils(my_driver)
    
    function new(string name = "my_driver" , uvm_component parent);
      super.new(name,parent);
    endfunction
    
    semaphore pipeline_lock = new(1);
    
    // A simple two-stage pipeline driver that can execute address and
    // data phases concurrently might be implemented as follows
    //---------------------------------------------------------------
    task main_phase(uvm_phase phase);
      fork
        do_pipelined_transfer();
        do_pipelined_transfer();
      join
    endtask
    
    task automatic do_pipelined_transfer();
      my_seq_item req,rsp;
      forever 
      begin
    
        // Lock the semaphore
        pipeline_lock.get();
    
        //Get the req and driver the command
        seq_item_port.get(req);
        command_phase(req);
    
        // - unlock pipeline semaphore
        pipeline_lock.put();
    
        // complete the data phase and send back the response
        data_phase(req);

        // Copy req to resp and set the id
        $cast(rsp,req.clone());
        rsp.set_id_info(req);
     
        // Put the response back to the sequencer 
        seq_item_port.put(rsp);
      end
    endtask: do_pipelined_transfer
    
    task command_phase(my_seq_item req);
        // Do command phase
        // Do Bus arbitration to get the access .. etc
        //req.print();
        #11;
        uvm_report_info(get_type_name(),$psprintf("Issuing Commands[%0d]....",req.id));
        #13;
    endtask
    
    task data_phase(ref my_seq_item req);
        // req.print();
        // Complete the data phase
        // Return the response with OKAY
        #15;
        uvm_report_info(get_type_name(),$psprintf("Issuing Data[%0d]....",req.id));
        req.resp = OKAY; // this response will go back to the sequence
        #20;
    endtask

endclass

//----------------------------------------------------------------------//
//----------------------------------------------------------------------//
class my_env extends uvm_env;

  `uvm_component_utils(my_env)

  function new(string name = "my_env" , uvm_component parent);
    super.new(name,parent);
  endfunction

  my_sequencer sqr;
  my_driver    drv;
  my_sequence  seq;

  function void build_phase(uvm_phase phase);
     super.build_phase(phase);
     sqr = my_sequencer::type_id::create("sqr",this);
     drv = my_driver::type_id::create("drv",this);
     seq = my_sequence::type_id::create("seq");
  endfunction

  function void connect_phase(uvm_phase phase);
   super.connect_phase(phase);
   drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
  
  task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq.start(sqr);
    #10us;
    uvm_report_info(get_type_name(),"....End of Test...");
    phase.drop_objection(this);
  endtask


endclass

//----------------------------------------------------------------------//
// Create the Env and call run_test
//----------------------------------------------------------------------//
my_env env;

initial
begin
   env = new("env",null);
   run_test();
end

endmodule

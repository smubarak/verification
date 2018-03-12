
`include "uvm_macros.svh"

//------------------------------------------------------------------------------
// Title: Typical Callback Application
//
// This example demonstrates callback usage. The component developer defines a
// driver and driver-specific callback class. The callback class defines the
// hooks available for users to override. The component using the callbacks
// (i.e. calling the callback methods) also defines corresponding virtual
// methods for each callback hook. The developer implements each virtual methods
// to call the corresponding callback method in all registered callback objects
// using default algorithm. The end-user may then define either a callback or
// driver subtype to extend driver behavior.
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
// Group: Component Developer Use Model
//------------------------------------------------------------------------------
// Component developers defines transaction, driver, and callback classes.
//------------------------------------------------------------------------------

package bus_driver_pkg;

import uvm_pkg::*;

typedef class bus_driver;
typedef class bus_driver_cb;
typedef uvm_callbacks #(bus_driver,bus_driver_cb) bus_driver_cbs_t;
typedef enum {TLP,DLLP,PLP,INVALID,ERROR} pkt_type_t;


//------------------------------------------------------------------------------
//
// CLASS: bus_tr
//
// A basic bus transaction. 
//------------------------------------------------------------------------------
class bus_tr extends uvm_transaction;

  rand pkt_type_t pkt_type;
  rand bit [31:0] addr;
  rand byte data[];

  constraint main_c {
     pkt_type dist {
                     TLP     :=40,
                     DLLP    :=30,
                     PLP     :=10,
                     INVALID :=10,
                     ERROR   :=10
                    };

     pkt_type == PLP      -> data.size() inside {0};
     pkt_type == DLLP     -> data.size() inside {0};
     pkt_type == TLP      -> data.size() inside {[0:16]};
     pkt_type == INVALID  -> data.size() inside {0};
     pkt_type == ERROR    -> data.size() inside {0};
     addr inside {[1:500]};
  }

  function new(string name = "bus_tr");
    super.new(name);
  endfunction

  `uvm_object_utils_begin(bus_tr)
    `uvm_field_enum(pkt_type_t,pkt_type,UVM_ALL_ON)
    `uvm_field_int(addr,UVM_ALL_ON)
    `uvm_field_array_int(data,UVM_ALL_ON)
  `uvm_object_utils_end

endclass


//------------------------------------------------------------------------------
// CLASS: bus_driver_cb
//------------------------------------------------------------------------------
// The callback class defines an interface consisting of one or more function
// or task prototypes. The signatures of each method have no restrictions.
// The component developer knows best the intended semantic of multiple
// registered callbacks. Thus the algorithm for traversal the callback queue
// should reside in the callback class itself. We could provide convenience
// macros that implement the most common traversal methods, such as sequential
// in-order execution.
//------------------------------------------------------------------------------
virtual class bus_driver_cb extends uvm_callback; 

  virtual function bit trans_received(bus_driver driver, bus_tr tr);
    return 0;
  endfunction

  virtual task trans_executed(bus_driver driver, bus_tr tr);
  endtask

  function new(string name="bus_driver_cb_inst");
    super.new(name);
  endfunction

endclass


//------------------------------------------------------------------------------
// CLASS: bus_driver
//------------------------------------------------------------------------------
// With the following implementation of bus_driver, users can implement
// the callback "hooks" by either...
//
// - extending bus_driver and overriding one or more of the virtual
//   methods, trans_received or trans_executed. Then, configure the
//   factory to use the new type via a type or instance override.
//
// - extending bus_driver_cb and overriding one or more of the virtual
//   methods, trans_received or trans_executed. Then, register an
//   instance of the new callback type with an instance of bus_driver.
//   This requires access to the handle of the bus_driver.
//------------------------------------------------------------------------------
class bus_driver extends uvm_component;

  `uvm_component_utils(bus_driver)
  `uvm_register_cb(bus_driver, bus_driver_cb)
  uvm_blocking_put_imp #(bus_tr,bus_driver) port;

  function new (string name, uvm_component parent=null);
    super.new(name,parent);
    port = new("port",this);
  endfunction

  //------------------------------------------------------------------------------
  // The Last arg (VAL) is used to stop calling the callbacks in the queue
  //------------------------------------------------------------------------------
  // If the first callback "trans_received" returns VAL , 
  //  then it will not call the next callback "trans_received" even if it is 
  //  registered with more number of callback. 
  //------------------------------------------------------------------------------
  virtual function bit trans_received(bus_tr tr);
  bit VAL;
     VAL=0;
    `uvm_do_callbacks_exit_on(bus_driver,bus_driver_cb,trans_received(this,tr),VAL)
  endfunction

  virtual task trans_executed(bus_tr tr);
    `uvm_do_callbacks(bus_driver,bus_driver_cb,trans_executed(this,tr))
  endtask

  virtual task put(bus_tr t);
    //uvm_report_info("bus_tr received",$psprintf("pkt_type:%s",t.pkt_type.name));
    if (!trans_received(t)) begin
      uvm_report_info("bus_tr dropped", "user callback indicated DROPPED\n");
      return;
    end
    #100;
    trans_executed(t);
    //uvm_report_info("bus_tr executed",$psprintf("pkt_type:%s",t.pkt_type.name));
  endtask

endclass

endpackage // bus_driver_pkg


//------------------------------------------------------------------------------
// Group: End-User Use Model
//------------------------------------------------------------------------------
// The end-user simply needs to extend the callback base class, overriding any or
// all of the prototypes provided in the developer-supplied callback interface.
// Then, register an instance of the callback class with any object designed to
// use the base callback type.
//------------------------------------------------------------------------------

import uvm_pkg::*;
import bus_driver_pkg::*;

//------------------------------------------------------------------------------
// CLASS: my_bus_driver_cb
//------------------------------------------------------------------------------
// This class defines a subtype of the driver developer's base callback class.
// In this case, both available driver callback methods are defined. The 
// ~trans_received~ method randomly chooses whether to return 0 or 1. When 1,
// the driver will "drop" the received transaction.
//------------------------------------------------------------------------------
class my_bus_driver_cb extends bus_driver_cb;

  function new(string name="bus_driver_cb_inst");
    super.new(name);
  endfunction

  // Drop the packet if the type is PLP 
  virtual function bit trans_received(bus_driver driver, bus_tr tr);
    static bit drop = 0;
    driver.uvm_report_info(get_full_name(),$psprintf("bus_tr received, pkt_type:%s",tr.pkt_type.name));
    if(tr.pkt_type == bus_driver_pkg::INVALID)
    begin
      driver.uvm_report_info(get_full_name(),$psprintf("Droping Packet Type:%s",tr.pkt_type.name));
      return 0;
    end
    else 
     return 1;
  endfunction

  virtual task trans_executed(bus_driver driver, bus_tr tr);
      driver.uvm_report_info(get_full_name(),$psprintf("bus_tr executed, pkt_type:%s",tr.pkt_type.name));
      tr.print;
  endtask

endclass


//------------------------------------------------------------------------------
//
// CLASS: my_bus_driver_cb2
//
//------------------------------------------------------------------------------
// This class defines a subtype of the driver developer's base callback class.
// In this case, only one of the two available methods are defined.
//------------------------------------------------------------------------------
class my_bus_driver_cb2 extends bus_driver_cb;

  function new(string name="bus_driver_cb_inst");
    super.new(name);
  endfunction

  // Drop the packet if the type is DLLP 
  virtual function bit trans_received(bus_driver driver, bus_tr tr);
    static bit drop = 0;
    driver.uvm_report_info(get_full_name(),$psprintf("bus_tr received, pkt_type:%s",tr.pkt_type.name));
    if(tr.pkt_type == bus_driver_pkg::ERROR)
    begin
      driver.uvm_report_info(get_full_name(),$psprintf("Droping Packet Type:%s",tr.pkt_type.name));
      return 0;
    end
    else 
     return 1;
  endfunction

  virtual task trans_executed(bus_driver driver, bus_tr tr);
    driver.uvm_report_info(get_full_name(),$psprintf("bus_tr executed, pkt_type:%s",tr.pkt_type.name));
  endtask

endclass

//------------------------------------------------------------------------------
// Simple test to check the callback
//------------------------------------------------------------------------------
class my_test extends uvm_test;

`uvm_component_utils(my_test)

 function new(string name,uvm_component parent);
   super.new(name,parent);
 endfunction

 bus_tr            tr     ;
 bus_driver        driver ;
 my_bus_driver_cb  cb1    ;
 my_bus_driver_cb2 cb2 ;

//------------------------------------------------------------------------------
// Create the Driver and Callback and add the Callback to the driver
//------------------------------------------------------------------------------
 virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);

  tr = new("txn");
  driver = bus_driver::type_id::create("driver",this);
  cb1    = new("cb1");
  cb2    = new("cb2");
 
  bus_driver_cbs_t::add(driver,cb1);
  bus_driver_cbs_t::add(driver,cb2);
  bus_driver_cbs_t::display();
 endfunction

  
//------------------------------------------------------------------------------
// put packets to the Driver through driver.port
//------------------------------------------------------------------------------
 virtual task main_phase(uvm_phase phase);
  phase.raise_objection(this);
  for (int i=1; i<=10; i++) begin
    tr = new("tr");
    assert(tr.randomize());
    driver.port.put(tr); 
  end
  phase.drop_objection(this);
 endtask

endclass

//------------------------------------------------------------------------------
// MODULE: top
//------------------------------------------------------------------------------
module top;
  import uvm_pkg::*;
  import bus_driver_pkg::*;

  initial 
  begin
    run_test("my_test");
  end

endmodule



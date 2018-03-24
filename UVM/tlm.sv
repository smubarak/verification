/*

This example might help you to understand some aspects of TLM in UVM
Place system verilog is used here.
*/

//-------------------------------------------------------------------------
//-------------------------------------------------------------------------
virtual class component#(type TRANS = int);
endclass

class port_if #(type TRANS = int) extends component#(TRANS);

   virtual task put(TRANS T);
     $display("[%m]--------CONNECTION ERR---------");
   endtask

endclass


//-------------------------------------------------------------------------
//-------------------------------------------------------------------------
class put_port#(type TRANS=int) extends port_if#(TRANS);
  string name;
  component#(TRANS) parent;
  put_port#(TRANS) put_imp;
 
  function new(string name="",component#(TRANS) parent=null);
    this.parent = parent;
    this.name   = name;
  endfunction 

  virtual function void connect(put_port#(TRANS) exp);
    this.put_imp = exp; 
  endfunction

  virtual task put(TRANS T);
     put_imp.put(T);
  endtask

endclass

//-------------------------------------------------------------------------
//-------------------------------------------------------------------------
class put_imp #(type TRANS=int,type COMP=component#(TRANS)) extends put_port#(TRANS);
  string name;
  COMP parent;
  
  function new(string name="",COMP parent=null);
    this.parent = parent;
    this.name   = name;
  endfunction 

  virtual task put(TRANS T);
     parent.put(T);
  endtask
 
endclass

//-------------------------------------------------------------------------
//-------------------------------------------------------------------------
class packet;
  rand int addr;

  function void print;
    $display("----------------Addr:%0h-----------------",addr);
  endfunction

endclass

//-------------------------------------------------------------------------
//-------------------------------------------------------------------------
class producer extends component#(packet);
  put_port#(packet)  port ;
  packet pkt = new();

  function new(); 
    port = new("port",this);
  endfunction

  task run();
     $display("[%m]-----------------");
     assert(pkt.randomize());
     port.put(pkt);
  endtask  
  
endclass


//-------------------------------------------------------------------------
//-------------------------------------------------------------------------
class consumer extends component#(packet);
  put_imp#(packet,consumer) imp;

  function new(); 
    imp = new("imp",this);
  endfunction

  task put(packet p);
    p.print();
  endtask

endclass

class env;

   producer prod;
   consumer cons;

   function new();
      prod = new();
      cons = new();
      prod.port.connect(cons.imp);
   endfunction

  task run();
      prod.run();
  endtask
  
endclass

module tb;

env ag;

initial
begin
   ag = new();
   ag.run();
end
endmodule

Gerty plugin: gp-juniper
========================


  
GP_Juniper::Netconf::Mixin::JuniperJunOS
----------------------------------------

This action handler mix-in module provides NETCONF interface for Juniper
routers. It provides interface to all CLI commands through an undocumented
Netconf method: <command>. Also some additional actions are supported for
some specific reports.

Optional attributes:

* __+junos.command-actions__: a list of actions which would be executed through
<command> method. For each action __XXX__, there should be a corresponding
attribute __XXX.command__.

* __XXX.command__: for each action name XXX, this parameter defines a
CLI command string which would be executed. The resulting output is
generated in XML format.

* __junos.netconf.rawxml__: if set to true, the actions return raw XML text
as output. Otherwise, the output is in JSON format. This applies to all
but command actions.

Actions:

* __junos.get-vpls-mac-counts__: Retrieves the MAC counts from the VPLS
MAC learning tables on a router. For each routing instance, there's the total
number of MACs, and also counts per interface and per VLAN.




  
  

  
 
  



Author
------

Stanislav Sinyagin  
CCIE #5478  
ssinyagin@k-open.com  
+41 79 407 0224  




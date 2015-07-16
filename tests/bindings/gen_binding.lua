module(..., package.seeall)

function gen_bindings(n_bindings, ports_per_host)
   local bt = {}
   local i4 = 0x11223344
   local ipv6_prefix = "0102:0304:0406:0708:090a:0b0c:"
   local start_port = 1024
   local port_step = math.floor((0xffff - start_port) / ports_per_host)
   for i = 1, n_bindings/ports_per_host do
      local port1 = start_port
      for p = 1, ports_per_host do
         local ipv4 = string.format("%i.%i.%i.%i",
                                    bit.rshift(bit.band(i4, 0xff000000), 24),
                                    bit.rshift(bit.band(i4, 0xff0000), 16),
                                    bit.rshift(bit.band(i4, 0xff00), 8),
                                    bit.band(i4, 0xff))
         local ipv6 = ipv6_prefix .. ipv4
         local port2 = port1 + port_step - 1
         local binding_entry = {ipv6, ipv4, port1, port2}
         table.insert(bt, binding_entry)
         port1 = port1 + port_step
      end
      i4 = i4 + 1
   end
   return bt
end

function print_bindings(bt)
   printable = {}
   count = 0
   print("{")
   for _,entry in ipairs(bt) do
      local entry_parts = {string.format('"%s"', entry[1]),
                           string.format('"%s"', entry[2]),
                           entry[3],
                           entry[4]}
      table.insert(printable, '   {' ..  table.concat(entry_parts, ', ') .. '}')
      count = count + 1
      if count % 10000 == 0 then
         print(table.concat(printable, ",\n"), ',')
         printable = {}
      end
   end
   if printable then
         print(table.concat(printable, ",\n"))
   end
   print("}")
end

-- n_bindings = 1000000
-- ports_per_host = 50
-- print_bindings(gen_bindings(n_bindings, ports_per_host))

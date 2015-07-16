#!/usr/bin/env luajit

local ffi = require("ffi")
local C = ffi.C

local AF_INET = 2
ffi.cdef[[
int inet_pton(int af, const char *src, void *dst);
uint32_t ntohl(uint32_t);
]]

local gen_binding = require("gen_binding")

local in_addr = ffi.new("uint8_t[4]")

local function pton(ipv4_addr)
   local r = C.inet_pton(AF_INET, ipv4_addr, in_addr)
   if r ~= 1 then error("Bad ipv4 address " .. ipv4_addr) end
   return in_addr
end

local function ipv4_numify(binding_table)
   for _,v in ipairs(binding_table) do
      v[2] = C.ntohl(ffi.cast("uint32_t*", pton(v[2]))[0])
   end
   return binding_table
end

local function format_number(n)
   local f = string.reverse(tostring(n))
   return string.reverse(f:gsub('%d%d%d', '%1,'))
end

-- Really, looking up IPv6 is what's wanted, but this should
-- be similar in terms of memory access, and is marginally less fiddly
local function find_endport(binding_table_hashed, ipv4, port)
   local entry = binding_table_hashed[ipv4]
   for i=1,#entry do
      if entry[i][2] <= port and entry[i][3] >= port then
         return entry[i][3] -- 1 for ipv6
      end
   end
   return 0 -- not found
end

local function benchmark_lookups(binding_table_hashed, lookups, reps)
   print("Starting benchmark")
   local reps = reps or 20.0
   local start_time = os.clock()
   local cumulative = 0
   for i = 1,reps do
      for _, v in pairs(lookups) do
         cumulative = cumulative + find_endport(binding_table_hashed, v[1], v[2])
      end
      -- Cost of one % is trivial here; keep the number smallish
      cumulative = cumulative % 5000
   end
   local elapsed = os.clock() - start_time
   print(string.format("Elapsed time: %i, lookups/sec: %s",
                        elapsed,
                        format_number(math.floor(#lookups * reps/elapsed))))
   print("cumulative", cumulative)
end

-- Index {ipv6, ipv4, p1, p2} by ipv4:
-- ht[ipv4] = {{ipv6_1, p1, p2}, {ipv6_2, p1_, p2_}, ...}
local function hashify(raw_binding_table)
   local ht = {}
   for _,v in ipairs(raw_binding_table) do
      local key = v[2]
      local val = {v[1], v[3], v[4]}
      if ht[key] then
         table.insert(ht[key], val)
      else
         ht[key] = {val}
      end
   end
   print("Hashify done")
   return ht
end

local function get_ip_port_pairs(bt)
   local pairs = {}
   for _, v in ipairs(bt) do
      table.insert(pairs, {v[2], v[3] + 1})
   end
   return pairs
end

function main(num_entries, ports_per_host, reps)
   -- generate bindings, because > 65k literals make loadstring fail
   local bt = ipv4_numify(gen_binding.gen_bindings(num_entries, ports_per_host))
   local bth = hashify(bt)
   local ipv4_and_port = get_ip_port_pairs(bt)
   benchmark_lookups(bth, ipv4_and_port, reps)
end

if #arg ~= 2 and #arg ~=3 then
   print("Use: thisapp num_entries ports_per_host [reps]")
   os.exit(1)
end
main(arg[1], arg[2], arg[3])

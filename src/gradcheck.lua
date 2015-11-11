-- Autograd
local autograd = require 'autograd'
local __ = require 'moses'

-- Perturbation (finite diffs):
local perturbation = 1e-6

-- Threshold:
local threshold = 1e-5

-- Find grad:
local function findGrad(ref, x, dst)
   ref = __.flatten(ref)
   dst = __.flatten(dst)
   for i,v in ipairs(ref) do
      if v == x then
         return dst[i]
      end
   end
end

-- Compute grads with bprop:
local function jacobianFromAutograd(func, inputs, var)
   -- Autograd:
   local grads = autograd(func)(unpack(inputs))

   -- Find grad:
   local g = findGrad(inputs[1], var, grads)

   -- Return grads:
   return g:contiguous():view(-1):clone()
end

-- Compute grads from finite differences
local function jacobianFromFiniteDifferences(func, inputs, var)
   -- Flat view:
   local view = var:view(-1)

   -- Grads:
   local grads = view:clone():zero()

   -- Finite diffs:
   for i = 1,view:size(1) do
      -- Initial val:
      local val = view[i]

      -- Perturbate:
      view[i] = val - perturbation/2
      local pred1 = func(unpack(inputs))
      view[i] = val + perturbation/2
      local pred2 = func(unpack(inputs))
      view[i] = val

      -- Finite diff:
      grads[i] = (pred2-pred1) / perturbation
   end
   -- Return grads:
   return grads
end

local function gradcheckvar(func, inputs, var)
   -- Random input:
   var:uniform(-1,1)

   -- Estimate grads with fprop:
   local jacobian1 = jacobianFromFiniteDifferences(func, inputs, var)

   -- Coded grads:
   local jacobian2 = jacobianFromAutograd(func, inputs, var)

   -- Error:
   local err = (jacobian1 - jacobian2):abs():max()

   -- Threhold?
   local pass = err < threshold
   if not pass then
      print('error = ' .. err)
   end
   return pass
end

-- Test grads:
local function gradcheck(func, ...)
   local args = {...}
   -- get all vars:
   local vars = __.flatten(args[1])
   local ok = true
   for i,var in ipairs(vars) do
      ok = ok and gradcheckvar(func, args, var)
   end
   return ok
end

-- Return package
return gradcheck

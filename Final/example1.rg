-- Copyright 2016 Stanford University
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

import "regent"
local c = regentlib.c

--  This example illustrates some basic Regent syntax.
--    * The declaration of a local variable "sum".  Note variable declarations require a type and can
--      have an initializer.  Regent has type inference, so the type declarations on variables are not
--      strictly necessary, but declaring types is a good practice.  Standard Regent "style" is to declare
--	types for most variables, the primary exception being loop iteration variables.
--    * A simple "for" loop.  Note the iteration variable is implicitly declared ane the type is omitted.
--      The end of the body of the "for" loop is marked with the keyword "end".
--    * An "if" statement, with "elseif" and "else" branches.  This "if" is particularly silly, as only
--      the first branch is ever taken.  An "if" is also closed by an "end".

task main()
     var sum: int2d = {5 , 6}
     sum = sum % {4,4}
     for s in ispace(int1d, 2) do
       c.printf(sum[s])
       var check : bool = sum[s] < 5
       if check then
	 c.printf("True")
       else
         c.printf("Wat")
       end
     c.printf("Result {%d, %d}\n",sum)
     end
end

regentlib.start(main)

import "regent"
local c = regentlib.c

task main()
     var sum = array(1,2,3)
     c.printf(sum[0])
end

regentlib.start(main)

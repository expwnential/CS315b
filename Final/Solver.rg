import "regent"

-- Helper modules to handle PNG files and command line arguments
local png        = require("png_util")
local EdgeConfig = require("edge_config")
local coloring   = require("coloring_util")

-- Some C APIs
local c     = regentlib.c
local sqrt  = regentlib.sqrt(double)
local cmath = terralib.includec("math.h")
local PI = cmath.M_PI

-- 2D vector type
struct Vector2D
{
  x : double;
  y : double;
}

-- 3D vector type
struct Vector3D
{
  x : double;
  y : double;
  z : double;
}

terra Vector2D:norm()
  return sqrt(self.x * self.x + self.y * self.y)
end
terra Vector3D:norm()
  return sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end
terra Vector2D.metamethods.__div(v : Vector2D, c : double)
  return Vector2d { v.x / c, v.y / c }
end
terra Vector3D.metamethods.__div(v : Vector3D, c : double)
  return Vector3d { v.x / c, v.y / c, v.z / c }

-- Field space for Grid, combine with F and G
fspace Grid2D
{
  density       : double;   
  mx            : double;
  my            : double; 
  energy        : double;
   
}

fspace F(r_image : region(Grid)) {
  mx : ptr(Grid2D.mx, r_image); --Pseudocode: Syntax?
  mx   
}


fspace Link(r_pages : region(Page)) {
  source : ptr(Page, r_pages);
  dest : ptr(Page, r_pages);
}

task factorize2d(parallelism : int) : int2d
  var limit = [int](cmath.sqrt([double](parallelism)))
  var size_x = 1
  var size_y = parallelism
  for i = 1, limit + 1 do
    if parallelism % i == 0 then
      size_x, size_y = i, parallelism / i
      if size_x > size_y then
        size_x, size_y = size_y, size_x
      end
    end
  end
  return int2d { size_x, size_y }
end

task factorize3d(parallelism : int) : int3d
  var limit = [int](cmath.pow([double](parallelism),1./3.))
  var size_x = 1
  var size_y = parallelism
  var size_z = 1
  for i = 1, limit + 1 do
    if parallelism % (i * i) == 0 then
      size_x, size_y, size_z = i, parallelism / i / i, i
      if size_x > size_y then
        size_x, size_y = size_y, size_x
      end
    end
  end
  return int3d { size_x, size_y, size_z }
end

task create_interior_partition(r_image : region(ispace(int2d), Grid))
  var coloring = c.legion_domain_coloring_create()
  var bounds = r_image.ispace.bounds
  c.legion_domain_coloring_color_domain(coloring, 0,
    rect2d { bounds.lo + {2, 2}, bounds.hi - {2, 2} })
  var interior_image_partition = partition(disjoint, r_image, coloring)
  c.legion_domain_coloring_destroy(coloring)
  return interior_image_partition
end

--
-- The 'initialize' task reads the image data from the file and initializes
-- the fields for later tasks. The upper left and lower right corners of the image
-- correspond to point {0, 0} and {width - 1, height - 1}, respectively.
--
task initialize(r_image : region(ispace(int2d), Grid),
                filename : int8[256])
where
  reads writes(r_image)
do
  png.read_png_file(filename,
                    __physical(r_image.original),
                    __fields(r_image.original),
                    r_image.bounds)
  for e in r_image do
    -- this is where I initialize values
    r_image[e].density
  end
  return 1
end

task Stencil2D(r_image: region(ispace(int2d),Grid), dt : double)
where
  reads writes(r_image)
do
  var New : region(ispace(int2d),Grid) = r_image
  for e in New do
    New[e] = r_image[e] + dt* 

task toplevel()
  var config : EdgeConfig
  config:initialize_from_command()

  -- Create a logical region for Grid
  var size_image = png.get_image_size(config.filename_image)
  var r_image = region(ispace(int2d, size_image), Grid)

  -- Create an equal partition of the grid
  var p_private_colors = ispace(int2d, factorize2d(config.parallelism))
  var p_private = partition(equal, r_image, p_private_colors)

  -- Create a halo partition for ghost access
  var c_halo = coloring.create()
  for color in p_private_colors do
    var bounds = p_private[color].bounds
    var halo_bounds : rect2d = {bounds.lo - {2,2}, bounds.hi + {2,2}}-- TODO: Calculate the correct bounds of the halo
    coloring.color_domain(c_halo, color, halo_bounds)
  end
  --
  -- TODO: Create an aliased partition of region 'r_image' using coloring 'c_halo':
  var p_halo = partition(aliased, r_image, c_halo, p_private_colors)
  coloring.destroy(c_halo)

  var token = initialize(r_image, config.filename_image)
  wait_for(token)
  var ts_start = c.legion_get_current_time_in_micros()

  --
  -- TODO: Change the following task launches so they are launched for
  --       each of the private regions and its halo region.
  --
  for color in p_private.colors do
    smooth(p_halo[color], p_private[color])
  end
  for color in p_private.colors do
    sobelX(p_halo[color], p_private[color])
    sobelY(p_halo[color], p_private[color])
  end
  for color in p_private.colors do 
    suppressNonmax(p_halo[color], p_private[color])
  end
  --
  -- Launch task 'edgefromGradient' for each of the private regions.
  -- This will be optimized to a parallel task launch.
  --
  for color in p_private.colors do
    edgeFromGradient(p_private[color], config.threshold)
  end

  for color in p_private_colors do
    token += block_task(p_private[color])
  end
  wait_for(token)
  var ts_end = c.legion_get_current_time_in_micros()
  c.printf("Total time: %.6f sec.\n", (ts_end - ts_start) * 1e-6)

  saveEdge(r_image, config.filename_edge)
end

regentlib.start(toplevel)

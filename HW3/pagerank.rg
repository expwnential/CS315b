import "regent"

-- Helper module to handle command line arguments
local PageRankConfig = require("pagerank_config")

local c = regentlib.c

fspace Page {
  rank         : double;
  rank2        : double;
  links        : uint32;

  --
  -- TODO (Done): Add more fields as you need.
  --
}

--
-- TODO (Done): Define fieldspace 'Link' which has two pointer fields,
--       one that points to the source and another to the destination.
--
fspace Link(r_pages : region(Page)) {
  source : ptr(Page, r_pages);
  dest : ptr(Page, r_pages);}

terra skip_header(f : &c.FILE)
  var x : uint64, y : uint64
  c.fscanf(f, "%llu\n%llu\n", &x, &y)
end

terra read_ids(f : &c.FILE, page_ids : &uint32)
  return c.fscanf(f, "%d %d\n", &page_ids[0], &page_ids[1]) == 2
end

task initialize_graph(r_pages   : region(Page),
                      --
                      -- TODO (Done): Give the right region type here.
                      --
                      r_links   : region(Link(r_pages)),
                      damp      : double,
                      num_pages : uint64,
                      filename  : int8[512])
where
  reads writes(r_pages, r_links)
do
  var ts_start = c.legion_get_current_time_in_micros()
  for page in r_pages do
    page.rank = 1.0 / num_pages
    -- TODO (Done): Initialize your fields if you need
    page.links = 0   
    page.rank2 = (1-damp)/num_pages 
  end

  var f = c.fopen(filename, "rb")
  skip_header(f)
  var page_ids : uint32[2]
  for link in r_links do
    regentlib.assert(read_ids(f, page_ids), "Less data that it should be")
    var src_page = unsafe_cast(ptr(Page, r_pages), page_ids[0])
    var dst_page = unsafe_cast(ptr(Page, r_pages), page_ids[1])
    --
    -- TODO (Done): Initialize the link with 'src_page' and 'dst_page'
    --
    link.source = src_page
    link.dest   = dst_page
  
    src_page.links += 1
  end
  c.fclose(f)
  var ts_stop = c.legion_get_current_time_in_micros()
  c.printf("Graph initialization took %.4f sec\n", (ts_stop - ts_start) * 1e-6)
end

--
-- TODO (Done): Implement PageRank. You can use as many tasks as you want.
--

task PageRank(r_pages : region(Page), r_links : region(Link(r_pages)), damp : double)
where
  reads(r_pages.{rank, links}), reads(r_links.{source, dest}),
  reads writes(r_pages.rank2)
do
  for link in r_links do
    link.dest.rank2 += damp * link.source.rank/link.source.links
  end
end


task condition(r_pages : region(Page), damp : double, bound : double)
where 
  reads(r_pages.{rank, rank2})
do
  var err : double = 0.
    for page in r_pages do
      err += (page.rank - page.rank2) * (page.rank - page.rank2)
    end
    return err < (bound*bound)
end

task update(r_pages : region(Page), damp : double, pages : uint32)
where 
  reads writes(r_pages.{rank, rank2})
do
  for page in r_pages do
    page.rank = page.rank2
    page.rank2 = (1. - damp) / pages
  end
end

task dump_ranks(r_pages  : region(Page),
                filename : int8[512])
where
  reads(r_pages.rank)
do
  var f = c.fopen(filename, "w")
  for page in r_pages do c.fprintf(f, "%g\n", page.rank) end
  c.fclose(f)
end

task toplevel()
  var config : PageRankConfig
  config:initialize_from_command()
  c.printf("**********************************\n")
  c.printf("* PageRank                       *\n")
  c.printf("*                                *\n")
  c.printf("* Number of Pages  : %11lu *\n",  config.num_pages)
  c.printf("* Number of Links  : %11lu *\n",  config.num_links)
  c.printf("* Damping Factor   : %11.4f *\n", config.damp)
  c.printf("* Error Bound      : %11g *\n",   config.error_bound)
  c.printf("* Max # Iterations : %11u *\n",   config.max_iterations)
  c.printf("**********************************\n")

  -- Create a region of pages
  var r_pages = region(ispace(ptr, config.num_pages), Page)
  --
  -- TODO (Done?): Create a region of links.
  --       It is your choice how you allocate the elements in this region.
  --
  var r_links = region(ispace(ptr, config.num_links), Link(wild))

  -- Initialize the page graph from a file
  initialize_graph(r_pages, r_links, config.damp, config.num_pages, config.input)

  var num_iterations = 0
  var converged = false
  var ts_start = c.legion_get_current_time_in_micros()
  while not converged and num_iterations < config.max_iterations do
    num_iterations += 1
    --
    -- TODO (Done): Launch the tasks that you implemented above.
    --       (and of course remove the break statement here.)
    --
    PageRank(r_pages, r_links, config.damp)
    converged = condition(r_pages, config.damp, config.error_bound)
    update(r_pages, config.damp, config.num_pages)
  end
  var ts_stop = c.legion_get_current_time_in_micros()
  c.printf("PageRank converged after %d iterations in %.4f sec\n",
    num_iterations, (ts_stop - ts_start) * 1e-6)

  if config.dump_output then dump_ranks(r_pages, config.output) end
end

regentlib.start(toplevel)

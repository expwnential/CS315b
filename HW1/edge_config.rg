import "regent"

local c = regentlib.c

struct EdgeConfig
{
  filename_image  : int8[256],
  filename_edge   : int8[256],
  filename_smooth : int8[256],
  save_smooth     : bool,
  skip_smooth     : bool,
  skip_suppress   : bool,
  threshold       : double,
}

local cstring = terralib.includec("string.h")

terra print_usage_and_abort()
  c.printf("Usage: regent edge.rg [OPTIONS]\n")
  c.printf("OPTIONS\n")
  c.printf("  -h            : Print the usage and exit.\n")
  c.printf("  -i {file}     : Use {file} as input.\n")
  c.printf("  -o {file}     : Save the final edge to {file}. Will use 'edge.png' by default.\n")
  c.printf("  -s {file}     : Save the image after Gaussian smoothing to {file}.\n")
  c.printf("  -t {value}    : Set the threshold to {value}.\n")
  c.printf("  --no-smooth   : Skip Gaussian smoothing.\n")
  c.printf("  --no-suppress : Skip non-maximum suppression.\n")
  c.exit(0)
end

terra file_exists(filename : rawstring)
  var file = c.fopen(filename, "rb")
  if file == nil then return false end
  c.fclose(file)
  return true
end
terra EdgeConfig:initialize_from_command()
  var filename_given = false

  cstring.strcpy(self.filename_edge, "edge.png")
  self.save_smooth = false
  self.skip_smooth = false
  self.skip_suppress = false
  self.threshold = 80

  var args = c.legion_runtime_get_input_args()
  var i = 1
  while i < args.argc do
    if cstring.strcmp(args.argv[i], "-h") == 0 then
      print_usage_and_abort()
    elseif cstring.strcmp(args.argv[i], "-i") == 0 then
      i = i + 1
      if not file_exists(args.argv[i]) then
        c.printf("File '%s' doesn't exist!\n", args.argv[i])
        c.abort()
      end
      cstring.strcpy(self.filename_image, args.argv[i])
      filename_given = true
    elseif cstring.strcmp(args.argv[i], "-o") == 0 then
      i = i + 1
      cstring.strcpy(self.filename_edge, args.argv[i])
    elseif cstring.strcmp(args.argv[i], "-s") == 0 then
      i = i + 1
      cstring.strcpy(self.filename_smooth, args.argv[i])
      self.save_smooth = true
    elseif cstring.strcmp(args.argv[i], "-t") == 0 then
      i = i + 1
      self.threshold = c.atof(args.argv[i])
    elseif cstring.strcmp(args.argv[i], "--no-smooth") == 0 then
      self.skip_smooth = true
    elseif cstring.strcmp(args.argv[i], "--no-suppress") == 0 then
      self.skip_suppress = true
    end
    i = i + 1
  end
  if self.skip_smooth then self.save_smooth = false end
  if not filename_given then
    c.printf("Input image file must be given!\n\n")
    print_usage_and_abort()
  end
end

return EdgeConfig

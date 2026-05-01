local FileIO = {}
FileIO.__name = "FileIO"
FileIO.__class = FileIO
FileIO.__fields = {}
FileIO.__methods = {__static = {} }

function FileIO.__methods.__static.read_file(self, path)
  local file = io.open(path, "r")

  if not file then
    error("cannot open file for reading: " .. path)
  end

  local content = file:read("*a")
  file:close()

  return content
end

function FileIO.__methods.__static.write_file(self, path, content)
  local file = io.open(path, "w")

  if not file then
    error("cannot open file for writing: " .. path)
  end

  file:write(content)
  file:close()
end

function FileIO.__methods.__static.create_file(self, path)
    local file = io.open(path, "w")
    if not file then
        error("cannot create file: " .. path)
    end
    file:close()
end

function FileIO.__methods.__static.file_exists(self, path)
  local file = io.open(path, "r")

  if file then
    file:close()
    return true
  else
    return false
  end
end

return FileIO
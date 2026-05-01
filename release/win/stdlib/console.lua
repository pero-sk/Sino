local ConsoleIO = {}
ConsoleIO.__name = "ConsoleIO"
ConsoleIO.__class = ConsoleIO
ConsoleIO.__fields = {}
ConsoleIO.__methods = {__static= {} }

function ConsoleIO.__methods.__static.input(self, prompt)
  io.write(prompt)
  return io.read()
end

function ConsoleIO.__methods.__static.number(self, prompt)
  while true do
    local input = self:input(prompt)
    local number = tonumber(input)

    if number then
      return number
    else
      print("Invalid number. Please try again.")
    end
  end
end

function ConsoleIO.__methods.__static.clear(self)
  if package.config:sub(1, 1) == "\\" then
    os.execute("cls")
  else
    os.execute("clear")
  end
end

return ConsoleIO
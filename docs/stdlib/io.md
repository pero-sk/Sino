# sino.io

File utilities for reading, writing, and checking files.

Import:

```sin
import FileIO from "sino.io"
```

## FileIO:read_file(path)

Reads the full contents of a file as a string.

Throws an error if the file cannot be opened.

    FileIO:read_file("notes.txt")

## FileIO:write_file(path, content)

Writes content to a file.

If the file already exists, it is overwritten.

Throws an error if the file cannot be opened.

    FileIO:write_file("notes.txt", "hello world")

## FileIO:create_file(path)

Creates an empty file.

If the file already exists, it is cleared.

Throws an error if the file cannot be created.

    FileIO:create_file("empty.txt")

## FileIO:file_exists(path)

Returns true if the file exists, otherwise false.

    FileIO:file_exists("notes.txt")
    -- true

    FileIO:file_exists("missing.txt")
    -- false